# libsndfile

Library for reading and writing audio files (WAV, AIFF, FLAC, Ogg…).

## Upstream

| | |
|---|---|
| Project | libsndfile |
| Author | Erik de Castro Lopo and contributors |
| Source | https://github.com/libsndfile/libsndfile |
| Version | version 1.2.2 (tag `1.2.2`, commit `72f6af15e8f85157bd622ed45b979025828b7001`) |
| Copy here | `upstream/` = a Git submodule of the repository above, at the commit above, **unmodified** (clone with `--recurse-submodules`) |

The release archive `libsndfile-1.2.2.tar.xz` (SHA-256 `3799ca9924d3125038880367bf1468e53a1b7e3686a934f098b7e1d286cdb80e`) has the same files as the tag, plus the ones that are generated: `configure` and the other files of autotools, and the C sources of the test programs, which the maintainers generate with GNU AutoGen. The build makes the first in a temporary copy, and does not build the test programs.

## Licence

LGPL-2.1-or-later (`COPYING`, header of `src/sndfile.c`).

Dependencies: optional codec libraries: FLAC, ogg, vorbis, opus, LAME/mpg123.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`). It needs autoconf, automake and libtool, to generate `configure` from the Git checkout, and builds the library, its headers and its pkg-config file only. The library is identical to the one built from the release archive, once stripped.


## Layout

- `upstream/`: the original sources, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
