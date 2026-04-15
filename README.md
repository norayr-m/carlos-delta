# carlos-delta

> **Note:** This is an amateur engineering project. We are not HPC professionals and make no competitive claims. Errors likely.

Lossless delta compression for spatial simulation frames. 50× measured on 1 billion cell ecosystem data.

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

