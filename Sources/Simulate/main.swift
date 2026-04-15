/// simulate — Generate a .savanna delta-compressed recording
/// Creates a fake spatial grid, simulates N ticks, writes XOR+zlib compressed frames.
///
/// Usage: simulate [--cells 1M] [--ticks 100] [--output recording.savanna]
///
/// Carlos Mateo Muñoz delta compression (MIT License)

import Foundation
import Compression

// ── Parse args ──────────────────────────────────────
let args = CommandLine.arguments
func arg(_ name: String, default val: String) -> String {
    if let i = args.firstIndex(of: "--\(name)"), i + 1 < args.count { return args[i + 1] }
    return val
}

func parseCells(_ s: String) -> Int {
    let u = s.uppercased()
    var n = u, mul = 1
    if n.hasSuffix("B") { n = String(n.dropLast()); mul = 1_000_000_000 }
    else if n.hasSuffix("M") { n = String(n.dropLast()); mul = 1_000_000 }
    else if n.hasSuffix("K") { n = String(n.dropLast()); mul = 1_000 }
    return Int(Double(n)! * Double(mul))
}

let totalCells = parseCells(arg("cells", default: "1M"))
let side = Int(sqrt(Double(totalCells)))

// Playback seconds → ticks (60 fps)
let seconds = Int(arg("seconds", default: "0"))!
let ticks: Int
if seconds > 0 {
    ticks = seconds * 60  // 60 fps playback
} else {
    ticks = Int(arg("ticks", default: "100"))!
}
let outputPath = arg("output", default: "recording.savanna")

let playbackSec = Double(ticks) / 60.0

print("carlos-delta: simulate")
print("  Cells:    \(side)×\(side) = \(totalCells.formatted())")
print("  Frames:   \(ticks) (\(String(format: "%.1f", playbackSec))s at 60fps)")
print("  Output:   \(outputPath)")

// ── Zlib helpers ────────────────────────────────────
func zlibCompress(_ input: [UInt8]) -> [UInt8] {
    var output = [UInt8](repeating: 0, count: input.count + 1024)
    let n = compression_encode_buffer(&output, output.count, input, input.count, nil, COMPRESSION_ZLIB)
    return Array(output[0..<n])
}

// ── .savanna format ─────────────────────────────────
// Header: "SDLT"(4) + width(u32) + height(u32) + n_frames(u32) + total_cells(u64) = 24 bytes
// Frame 0: size(u32) + zlib(keyframe)
// Frame 1+: size(u32) + zlib(XOR delta)

let n = side * side

// Create output file
FileManager.default.createFile(atPath: outputPath, contents: nil)
let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath))

// Write header
var header = Data()
header.append(contentsOf: [0x53, 0x44, 0x4C, 0x54])  // "SDLT"
var w = UInt32(side), h = UInt32(side), nf = UInt32(0), tc = UInt64(n)
header.append(Data(bytes: &w, count: 4))
header.append(Data(bytes: &h, count: 4))
header.append(Data(bytes: &nf, count: 4))
header.append(Data(bytes: &tc, count: 8))
handle.write(header)

// ── Simulate ────────────────────────────────────────
// Simple ecosystem: 80% grass(1), 15% empty(0), 3% zebra(2), 1% water(4), 0.3% lion(3)
// Each tick: ~2% of cells change randomly (realistic sparsity)

print("  Simulating...", terminator: "")
fflush(stdout)

// Deterministic RNG
var rngState: UInt64 = 42
func rng() -> UInt64 {
    rngState &+= 0x9E3779B97F4A7C15
    var z = rngState
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return z ^ (z >> 31)
}

// Init grid
var grid = [UInt8](repeating: 0, count: n)
for i in 0..<n {
    let r = rng() % 1000
    if r < 800 { grid[i] = 1 }       // grass
    else if r < 830 { grid[i] = 2 }   // zebra
    else if r < 840 { grid[i] = 4 }   // water
    else if r < 843 { grid[i] = 3 }   // lion
    // else empty (0)
}

var prevGrid = grid
var totalRaw = 0
var totalCompressed = 0
let simStart = CFAbsoluteTimeGetCurrent()

for tick in 0..<ticks {
    if tick > 0 {
        // Mutate ~2% of cells (realistic change rate)
        let changes = max(1, n / 50)
        for _ in 0..<changes {
            let idx = Int(rng() % UInt64(n))
            let r = rng() % 1000
            if r < 800 { grid[idx] = 1 }
            else if r < 830 { grid[idx] = 2 }
            else if r < 840 { grid[idx] = 4 }
            else if r < 843 { grid[idx] = 3 }
            else { grid[idx] = 0 }
        }
    }

    let toCompress: [UInt8]
    if tick == 0 {
        toCompress = grid
    } else {
        // XOR delta
        var delta = [UInt8](repeating: 0, count: n)
        for i in 0..<n { delta[i] = grid[i] ^ prevGrid[i] }
        toCompress = delta
    }

    let compressed = zlibCompress(toCompress)
    var sz = UInt32(compressed.count)
    handle.write(Data(bytes: &sz, count: 4))
    handle.write(Data(compressed))

    totalRaw += n
    totalCompressed += compressed.count
    prevGrid = grid

    if (tick + 1) % 10 == 0 || tick == 0 {
        print("\r  Frame \(tick + 1)/\(ticks): \(compressed.count / 1024) KB" +
              " (ratio: \(String(format: "%.1f", Double(n) / Double(compressed.count)))×)", terminator: "")
        fflush(stdout)
    }
}

// Update frame count in header
handle.seek(toFileOffset: 12)
var frameCount = UInt32(ticks)
handle.write(Data(bytes: &frameCount, count: 4))
handle.closeFile()

let elapsed = CFAbsoluteTimeGetCurrent() - simStart
let fileSize = try FileManager.default.attributesOfItem(atPath: outputPath)[.size] as! Int

let ratio = String(format: "%.1f", Double(totalRaw) / Double(max(1, totalCompressed)))
let timeStr = String(format: "%.1f", elapsed)
print("\n")
print("  ╔═══════════════════════════════════════════════╗")
print("  ║  CARLOS DELTA COMPRESSION RESULTS             ║")
print("  ╠═══════════════════════════════════════════════╣")
print("  ║  Cells:      \(side)×\(side)")
print("  ║  Frames:     \(ticks)")
print("  ║  Raw:        \(totalRaw / 1_000_000) MB")
print("  ║  Compressed: \(totalCompressed / 1_000_000) MB")
print("  ║  Ratio:      \(ratio)×")
print("  ║  File:       \(fileSize / 1_000_000) MB")
print("  ║  Time:       \(timeStr)s")
print("  ╚═══════════════════════════════════════════════╝")
print()
print("  Play: swift run playback \(outputPath)")
