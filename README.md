# carlos-delta

> **Note:** This is an amateur engineering project. We are not HPC professionals and make no competitive claims. Errors likely.

Lossless delta compression for spatial simulation frames. 50× measured on 1 billion cell ecosystem data.

## Quick Start

```bash
git clone https://github.com/norayr-m/carlos-delta.git
cd carlos-delta
swift build -c release

# 1. Simulate 1 million cells, 30 seconds of playback
.build/release/simulate --cells 1M --seconds 30

# 2. Play it in a browser
.build/release/playback recording.savanna
# → open http://localhost:8800
```

That's it. Two binaries. One file. WebGL viewer with zoom and neon cell counter.

### Options

```bash
# Cell count (human-readable)
--cells 1M          # 1 million (default)
--cells 100M        # 100 million
--cells 1B          # 1 billion

# Duration
--seconds 30        # 30 seconds of playback at 60fps (= 1800 frames)
--ticks 100         # or specify frames directly

# Output
--output my.savanna # custom filename (default: recording.savanna)

# Playback port
--port 9090         # custom port (default: 8800)
```

Inspired by [Carlos Mateo Muñoz](https://github.com/carlosmateo10/delta-compression-demo)'s RFC 9842 Dictionary TTL extension (MIT License).

## The Idea

Between simulation ticks, 98.7% of cells don't change. XOR the frames. Compress the zeros.

```
Frame N ⊕ Frame N-1 → 98.7% zeros → zlib → 50× smaller
```

One billion cells. Twenty frames. 20 GB raw → **408 MB compressed**. Lossless.

## Measured Results

| Frame | Sparsity | Raw | Compressed | Ratio |
|-------|----------|-----|------------|-------|
| 1 | 97.6% | 1,074 MB | 32.9 MB | 33× |
| 10 | 98.7% | 1,074 MB | 21.5 MB | 50× |
| 19 | 99.1% | 1,074 MB | 16.8 MB | 64× |
| **AVG** | **98.7%** | **1,074 MB** | **21.5 MB** | **50×** |

## Why It Matters

Carlos's web standard (RFC 9842 Dictionary TTL) enables using the previous HTTP response as a compression dictionary. We applied this to spatial simulation tensors:

- **Web payload**: HTML page N-1 is dictionary for page N (468× on duplicate pages)
- **Spatial tensor**: Frame N-1 is dictionary for Frame N (50× on ecosystem data)
- **Same math. Different domain.**

This is not web compression applied to simulations. This is a **lossless video codec for scientific spatial compute**.

## Links

- Data source: [Savanna Engine](https://github.com/norayr-m/savanna-engine) (100B cells, Apple M5 Max)
- Carlos's library: [delta-compression-demo](https://github.com/carlosmateo10/delta-compression-demo) (MIT License)
- [YouTube: 100B cell playback](https://youtu.be/6QiU7kUD3Os)
- [1B cells in browser (5.4 MB)](https://norayr-m.github.io/savanna-engine/playback.html)
- [Full report (PDF)](https://github.com/norayr-m/savanna-engine/blob/main/Carlos_Delta_Compression_Report.pdf)

## AI Co-Authorship

Built collaboratively with [Claude](https://claude.ai) (Anthropic) and [Gemini Deep Think](https://deepmind.google/models/gemini/deep-think/) (Google). Bugs found by [Qwen3 Coder Next](https://huggingface.co/Qwen/Qwen3-Coder-Next) (Alibaba, local via LM Studio). The math is human. The code was built together. All are credited.

