# carlos-delta

> **Note:** This is an amateur engineering project. We are not HPC professionals and make no competitive claims. Errors likely.

Lossless delta compression for spatial simulation frames. GPU-native sparse scatter format — zero CPU in the decode path.

## The Pipeline

```
RECORD:  Metal GPU → XOR delta → sparse (index,value) pairs → NVMe
PLAY:    NVMe → GPU scatter kernel → de-Morton → LOD downsample → WebGL

CPU never touches cell data during playback.
```

Full architecture: [ARCHITECTURE.md](ARCHITECTURE.md)

## Quick Start

```bash
git clone https://github.com/norayr-m/carlos-delta.git
cd carlos-delta
swift build -c release

# 1. Record a simulation (sparse scatter format, GPU-native)
.build/release/savanna-cli --cells 1M --days 30 --record myrun.savanna

# 2. Play it in a browser
.build/release/savanna-play myrun.savanna
# → open http://localhost:8800/savanna_webgl.html
```

Two binaries. One `.savanna` file.

### Options

```bash
# Cell count (human-readable)
--cells 1M          # 1 million (default)
--cells 100M        # 100 million  
--cells 1B          # 1 billion

# Duration
--days 30           # 30 days (4 ticks/day = 120 frames)

# Recording
--record myrun.savanna   # direct filename
--record myrun/          # directory (writes myrun/recording.savanna)

# Format
(default)           # sparse scatter (GPU-native, fast decode)
--zlib              # zlib compressed (smaller files, CPU decode)

# GPU init
--gpu-init          # 3.8ms GPU state init (vs 30s CPU)

# Playback
--port 9090         # custom port (default: 8800)
```

## The Idea

Between simulation ticks, 98.7% of cells don't change. Don't compress the zeros. **Forget them.**

```
Frame N ⊕ Frame N-1 → 98.7% silence → store only the 1.3% that changed
```

P-frames: sparse `(morton_index, xor_value)` pairs. GPU scatter kernel applies them.
I-frames: full keyframe every 60 frames. Bounds the replay chain.

### Why Not zlib?

zlib compresses the XOR delta — all N bytes including zeros. CPU decompresses every frame. At 100M cells: ~1 second per frame.

Sparse scatter stores only non-zero entries. GPU scatter kernel: microseconds. The non-zero bytes are predator-prey chaos — zlib can't find patterns in lions eating zebras anyway. It burns CPU compressing incompressible entropy surrounded by zeros we don't need to store.

## Measured Results

| Scale | Cells | Change Rate | Sparse P-frame | Decode (GPU) |
|-------|-------|-------------|----------------|-------------|
| 1M | 1,000,000 | 1.3% | ~65 KB | ~0.1ms |
| 10M | 10,000,000 | 1.3% | ~650 KB | ~0.5ms |
| 100M | 100,000,000 | 1.3% | ~6.5 MB | ~1ms |
| 1B | 1,000,000,000 | 1.3% | ~65 MB | ~5ms |

## .savanna Format (v3)

```
Header (32 bytes): magic + dimensions + keyframe_interval + format_flag

I-frame: zlib(full_frame)           — every 60 frames
P-frame: count + indices[] + values[] — sparse scatter, GPU-native
```

Three format versions (auto-detected, backward compatible):
- v1: zlib, row-major (24-byte header)
- v2: zlib, Morton Z-curve (28-byte header)
- v3: sparse scatter, Morton, I/P frames (32-byte header)

## Morton Z-Curve

All data stored in Morton Z-curve order. Spatial neighbors are close in memory. The Morton index IS the geometry — no coordinate transform needed. GPU buffers, disk, decoder all use the same ordering. De-Morton only at the browser boundary (GPU kernel, microseconds).

## Links

- Savanna Engine: [github.com/norayr-m/savanna-engine](https://github.com/norayr-m/savanna-engine)
- Carlos's library: [delta-compression-demo](https://github.com/carlosmateo10/delta-compression-demo) (MIT License)

## AI Co-Authorship

Built collaboratively with [Claude](https://claude.ai) (Anthropic) and [Gemini Deep Think](https://deepmind.google/models/gemini/deep-think/) (Google). Bugs found by [Qwen3 Coder Next](https://huggingface.co/Qwen/Qwen3-Coder-Next) (Alibaba, local via LM Studio). The math is human. The code was built together. All are credited.
