/// playback — Serve a .savanna file via HTTP for WebGL viewing
/// Decodes Carlos Delta (XOR + zlib), serves frames to browser.
///
/// Usage: playback recording.savanna [--port 8800]
///
/// Then open: http://localhost:8800

import Foundation
import Compression
#if canImport(Darwin)
import Darwin
#endif

// ── Parse args ──────────────────────────────────────
let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: playback <recording.savanna> [--port 8800]")
    exit(1)
}
let filePath = args[1]
let port: UInt16 = {
    if let i = args.firstIndex(of: "--port"), i + 1 < args.count { return UInt16(args[i + 1]) ?? 8800 }
    return 8800
}()

// ── Decode .savanna ─────────────────────────────────
func zlibDecompress(_ input: [UInt8], size: Int) -> [UInt8] {
    var output = [UInt8](repeating: 0, count: size)
    let n = compression_decode_buffer(&output, size, input, input.count, nil, COMPRESSION_ZLIB)
    return Array(output[0..<n])
}

print("Loading \(filePath)...")
let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
var offset = 0

// Header
let magic = [UInt8](data[0..<4])
guard magic == [0x53, 0x44, 0x4C, 0x54] else { print("Not a .savanna file"); exit(1) }
offset = 4
func readU32() -> UInt32 { let v = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self) }; offset += 4; return v }
func readU64() -> UInt64 { let v = data[offset..<offset+8].withUnsafeBytes { $0.load(as: UInt64.self) }; offset += 8; return v }

let width = Int(readU32()), height = Int(readU32())
let frameCount = Int(readU32())
let totalCells = readU64()
let cellCount = width * height
print("  Grid: \(width)×\(height), Frames: \(frameCount), Cells: \(totalCells)")

// Decode all frames
var frames = [[UInt8]]()
for i in 0..<frameCount {
    let sz = Int(readU32())
    let compressed = [UInt8](data[offset..<offset+sz])
    offset += sz
    let raw = zlibDecompress(compressed, size: cellCount)
    if i == 0 {
        frames.append(raw)
    } else {
        var frame = [UInt8](repeating: 0, count: cellCount)
        for j in 0..<cellCount { frame[j] = frames[i-1][j] ^ raw[j] }
        frames.append(frame)
    }
}
print("  Decoded \(frames.count) frames")

// ── Embedded WebGL viewer ───────────────────────────
let viewerHTML = """
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Carlos Delta Playback</title>
<script src="https://cdn.jsdelivr.net/npm/pako@2.1.0/dist/pako.min.js"></script>
<style>*{margin:0;padding:0;box-sizing:border-box}body{background:#1a1408;overflow:hidden}
canvas{display:block}#hud{position:fixed;top:0;left:0;right:0;color:#a09070;
font:14px/1 'SF Mono',monospace;background:rgba(26,20,8,0.85);padding:8px 16px;
display:flex;gap:16px;z-index:10}#hud .v{color:#c4a35a;font-weight:bold}
#cc{position:fixed;bottom:60px;left:50%;transform:translateX(-50%);z-index:30;
pointer-events:none;text-align:center;font:bold 48px/1 'SF Mono',monospace;
letter-spacing:2px;text-shadow:0 0 20px rgba(0,0,0,0.8)}
#cc .l{font-size:14px;letter-spacing:3px;opacity:0.7;display:block;margin-bottom:4px}
#bb{position:fixed;bottom:0;left:0;right:0;color:#5a4a2a;font:12px/1 'SF Mono',monospace;
background:rgba(26,20,8,0.7);padding:6px 16px;z-index:10}</style></head><body>
<div id="hud"><span class="v">CARLOS DELTA</span>
<span>Frame <span class="v" id="hf">0</span>/<span class="v" id="ht">0</span></span>
<span class="v" id="hfps">0</span>fps
<span style="color:#c4a35a;font-size:11px">WebGL · Lossless · XOR+zlib</span></div>
<div id="cc"><span class="l">CELLS IN VIEW</span><span id="cn">0</span></div>
<div id="bb"><span style="color:#c4a35a">scroll</span> zoom
<span style="color:#c4a35a">click</span> in
<span style="color:#c4a35a">space</span> fit
<span style="color:#c4a35a">←→</span> frames
<span style="margin-left:auto;color:#c4a35a">Carlos Mateo Muñoz (MIT License)</span></div>
<canvas id="c"></canvas>
<script>
const C=document.getElementById('c'),gl=C.getContext('webgl2')||C.getContext('webgl');
let W,H;function resize(){W=C.width=innerWidth;H=C.height=innerHeight;gl.viewport(0,0,W,H)}
resize();addEventListener('resize',resize);
const vs=`attribute vec2 a;varying vec2 v;uniform vec2 o;uniform float z;uniform vec2 s,g;
void main(){vec2 w=a*g;vec2 p=(w*z+o)/s*2.0-1.0;p.y=-p.y;gl_Position=vec4(p,0,1);v=a;}`;
const fs=`precision mediump float;varying vec2 v;uniform sampler2D t;
void main(){float e=floor(texture2D(t,v).r*255.0+0.5);vec3 c;
if(e<0.5)c=vec3(.102,.078,.031);else if(e<1.5)c=vec3(.227,.29,.094);
else if(e<2.5)c=vec3(.91,.894,.863);else if(e<3.5)c=vec3(.706,.157,.118);
else c=vec3(.157,.353,.627);gl_FragColor=vec4(c,1.);}`;
function mk(s,t){const sh=gl.createShader(t);gl.shaderSource(sh,s);gl.compileShader(sh);return sh}
const pr=gl.createProgram();gl.attachShader(pr,mk(vs,gl.VERTEX_SHADER));
gl.attachShader(pr,mk(fs,gl.FRAGMENT_SHADER));gl.linkProgram(pr);gl.useProgram(pr);
const aP=gl.getAttribLocation(pr,'a'),uO=gl.getUniformLocation(pr,'o'),
uZ=gl.getUniformLocation(pr,'z'),uS=gl.getUniformLocation(pr,'s'),uG=gl.getUniformLocation(pr,'g');
const vb=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,vb);
gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([0,0,1,0,0,1,1,0,1,1,0,1]),gl.STATIC_DRAW);
gl.enableVertexAttribArray(aP);gl.vertexAttribPointer(aP,2,gl.FLOAT,false,0,0);
const tx=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,tx);
gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST);
gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.NEAREST);
gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);
gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
let GW=1,GH=1,zoom=1,px=0,py=0,cf=0,TC=0,drag=false,dm=false,dsx,dsy,psx,psy;
async function load(){
const r=await fetch('/data');const b=await r.arrayBuffer();const v=new DataView(b);
let o=0;o+=4;GW=v.getUint32(o,true);o+=4;GH=v.getUint32(o,true);o+=4;
const nf=v.getUint32(o,true);o+=4;TC=Number(v.getBigUint64(o,true));o+=8;
document.getElementById('ht').textContent=nf;
const frames=[];const cc=GW*GH;
for(let i=0;i<nf;i++){const sz=v.getUint32(o,true);o+=4;
const comp=new Uint8Array(b,o,sz);o+=sz;const raw=pako.inflateRaw(comp);
if(i===0){frames.push(new Uint8Array(raw))}
else{const p=frames[i-1];const f=new Uint8Array(cc);
for(let j=0;j<cc;j++)f[j]=p[j]^raw[j];frames.push(f)}}
window._frames=frames;show(0);
zoom=Math.min(W/GW,H/GH)*0.9;px=(W-GW*zoom)/2;py=(H-GH*zoom)/2;
setInterval(()=>{cf=(cf+1)%frames.length;show(cf)},500)}
function show(i){const d=window._frames[i];gl.pixelStorei(gl.UNPACK_ALIGNMENT,1);
gl.bindTexture(gl.TEXTURE_2D,tx);gl.texImage2D(gl.TEXTURE_2D,0,gl.LUMINANCE,GW,GH,0,gl.LUMINANCE,gl.UNSIGNED_BYTE,d);
document.getElementById('hf').textContent=i}
function render(){gl.clearColor(.102,.078,.031,1);gl.clear(gl.COLOR_BUFFER_BIT);
gl.useProgram(pr);gl.uniform2f(uO,px,py);gl.uniform1f(uZ,zoom);
gl.uniform2f(uS,W,H);gl.uniform2f(uG,GW,GH);gl.bindTexture(gl.TEXTURE_2D,tx);
gl.drawArrays(gl.TRIANGLES,0,6);
const vw=Math.min(W/zoom,GW),vh=Math.min(H/zoom,GH),vp=Math.round(vw*vh);
const cpp=TC/(GW*GH),vc=Math.round(vp*cpp),el=document.getElementById('cn');
el.textContent=vc.toLocaleString();
const m=Math.log10(Math.max(1,vc));let co;
if(m<4)co='#c0c0c0';else if(m<6)co='#c4a35a';else if(m<8)co='#e03030';
else if(m<10)co='#e020a0';else if(m<12)co='#ff00ff';else co='#aa00ff';
document.getElementById('cc').style.color=co;
document.getElementById('cc').style.textShadow=m>=9?'0 0 20px '+co+',0 0 60px '+co+'80':'0 0 20px rgba(0,0,0,0.8)';
requestAnimationFrame(render)}
C.addEventListener('wheel',e=>{e.preventDefault();
if(Math.abs(e.deltaX)>Math.abs(e.deltaY)){px-=e.deltaX}
else{const z=1-e.deltaY*0.003;px=e.clientX-(e.clientX-px)*z;py=e.clientY-(e.clientY-py)*z;zoom*=z}
zoom=Math.max(0.0001,Math.min(50,zoom))},{passive:false});
C.addEventListener('mousedown',e=>{drag=true;dm=false;dsx=e.clientX;dsy=e.clientY;psx=px;psy=py;C.style.cursor='grabbing'});
C.addEventListener('mousemove',e=>{if(!drag)return;if(Math.abs(e.clientX-dsx)>3)dm=true;px=psx+(e.clientX-dsx);py=psy+(e.clientY-dsy)});
C.addEventListener('mouseup',()=>{drag=false;C.style.cursor='grab'});C.style.cursor='grab';
document.addEventListener('keydown',e=>{
if(e.code==='Space'){e.preventDefault();zoom=Math.min(W/GW,H/GH)*0.9;px=(W-GW*zoom)/2;py=(H-GH*zoom)/2}
if(e.code==='ArrowRight'&&window._frames){cf=(cf+1)%window._frames.length;show(cf)}
if(e.code==='ArrowLeft'&&window._frames){cf=(cf-1+window._frames.length)%window._frames.length;show(cf)}});
requestAnimationFrame(render);load();
</script></body></html>
"""

// ── HTTP Server ─────────────────────────────────────
var currentFrame = 0

func handleRequest(_ fd: Int32) {
    var buf = [UInt8](repeating: 0, count: 4096)
    let n = read(fd, &buf, buf.count)
    guard n > 0 else { close(fd); return }
    let req = String(bytes: buf[0..<n], encoding: .utf8) ?? ""
    let path = req.split(separator: " ").dropFirst().first.map(String.init) ?? "/"

    var body = Data()
    var ct = "text/plain"
    var status = "HTTP/1.1 200 OK\r\n"

    if path == "/" || path == "/index.html" {
        ct = "text/html"
        body = viewerHTML.data(using: .utf8)!
    } else if path == "/data" {
        // Serve the raw .savanna file for browser-side decoding
        ct = "application/octet-stream"
        body = data
    } else if path.hasPrefix("/savanna_state.bin") {
        ct = "application/octet-stream"
        let frame = frames[currentFrame]
        currentFrame = (currentFrame + 1) % frameCount
        var hdr = Data()
        var w32 = UInt32(width), h32 = UInt32(height), t32 = UInt32(currentFrame), d32: UInt32 = 1
        hdr.append(Data(bytes: &w32, count: 4))
        hdr.append(Data(bytes: &h32, count: 4))
        hdr.append(Data(bytes: &t32, count: 4))
        hdr.append(Data(bytes: &d32, count: 4))
        hdr.append(Data(frame))
        body = hdr
    } else if path == "/info" {
        ct = "application/json"
        body = "{\"width\":\(width),\"height\":\(height),\"frame_count\":\(frameCount),\"total_cells\":\(totalCells)}".data(using: .utf8)!
    } else {
        status = "HTTP/1.1 404 Not Found\r\n"
        body = "404".data(using: .utf8)!
    }

    let headers = "\(status)Content-Type: \(ct)\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
    let headerData = headers.data(using: .utf8)!
    headerData.withUnsafeBytes { _ = write(fd, $0.baseAddress!, headerData.count) }
    body.withUnsafeBytes { _ = write(fd, $0.baseAddress!, body.count) }
    close(fd)
}

let serverFd = socket(AF_INET, SOCK_STREAM, 0)
var opt: Int32 = 1
setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
var addr = sockaddr_in()
addr.sin_family = sa_family_t(AF_INET)
addr.sin_port = UInt16(port).bigEndian
addr.sin_addr.s_addr = in_addr_t(0)  // INADDR_ANY
_ = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(serverFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
listen(serverFd, 10)

print()
print("  ╔═══════════════════════════════════════════════╗")
print("  ║  CARLOS DELTA PLAYBACK                        ║")
print("  ║  http://localhost:\(port)                        ║")
print("  ╚═══════════════════════════════════════════════╝")
print()

while true {
    let clientFd = accept(serverFd, nil, nil)
    if clientFd >= 0 {
        DispatchQueue.global(qos: .userInteractive).async { handleRequest(clientFd) }
    }
}
