# FLAC

Reference library of the Free Lossless Audio Codec (`libFLAC`), and the `flac` and `metaflac` programs.

## Upstream

| | |
|---|---|
| Project | FLAC |
| Author | Josh Coalson and the Xiph.Org Foundation |
| Source | https://github.com/xiph/flac |
| Version | version 1.5.0 (tag `1.5.0`, commit `1507800de4b70e21be71f38caa0d9079d0bc6e45`) |
| Copy here | `upstream/` = a Git submodule of the repository above, at the commit above, **unmodified** (clone with `--recurse-submodules`) |

The release archive `flac-1.5.0.tar.xz` (SHA-256 `f2c1c76592a82ffff8413ba3c4a1299b6c7ab06c734dee03fd88630485c2b920`, identical to the value published in `SHA256SUMS.txt` next to the archive and on the GitHub release page) has the same files as the tag, plus the ones that autotools generates (`configure`, `Makefile.in`, `ltmain.sh` ...) and the generated documentation. The build makes `configure` in a temporary copy.

## Licence

The libraries (`libFLAC`, `libFLAC++`) are BSD-3-Clause (`COPYING.Xiph`, header of `src/libFLAC/*.c`). The `flac` and `metaflac` programs are GPL-2.0-or-later (`COPYING.GPL`) and are not built here: only the library is linked into the tools.

Dependencies: libogg (`libs/libogg/`, for FLAC in Ogg).

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`). It needs autoconf, automake and libtool, to generate `configure` from the Git checkout. The library is identical to the one built from the release archive, once stripped.


## Layout

- `upstream/`: the upstream sources, as published by Xiph.Org, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
