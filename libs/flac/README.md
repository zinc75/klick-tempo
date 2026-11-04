# FLAC

Reference library of the Free Lossless Audio Codec (`libFLAC`), and the `flac` and `metaflac` programs.

## Upstream

| | |
|---|---|
| Project | FLAC |
| Author | Josh Coalson and the Xiph.Org Foundation |
| Source | https://downloads.xiph.org/releases/flac/flac-1.5.0.tar.xz |
| Version | version 1.5.0 (archive downloaded 2026-10-31) |
| Archive | `flac-1.5.0.tar.xz` (not committed) |
| SHA-256 | `f2c1c76592a82ffff8413ba3c4a1299b6c7ab06c734dee03fd88630485c2b920`, identical to the value published in `SHA256SUMS.txt` next to the archive and on the GitHub release page |
| Copy here | `upstream/` = the extracted archive, **unmodified** |

## Licence

The libraries (`libFLAC`, `libFLAC++`) are BSD-3-Clause (`COPYING.Xiph`, header of `src/libFLAC/*.c`). The `flac` and `metaflac` programs are GPL-2.0-or-later (`COPYING.GPL`) and are not built here: only the library is linked into the tools.

Dependencies: libogg (`libs/libogg/`, for FLAC in Ogg).

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`).


## Layout

- `upstream/`: the upstream sources, as published by Xiph.Org, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
