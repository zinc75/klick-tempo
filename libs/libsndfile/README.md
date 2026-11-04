# libsndfile

Library for reading and writing audio files (WAV, AIFF, FLAC, Ogg…).

## Upstream

| | |
|---|---|
| Project | libsndfile |
| Author | Erik de Castro Lopo and contributors |
| Source | https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz |
| Version | version 1.2.2 (archive downloaded 2026-10-31) |
| Archive | `libsndfile-1.2.2.tar.xz` (not committed) |
| SHA-256 | `3799ca9924d3125038880367bf1468e53a1b7e3686a934f098b7e1d286cdb80e` |
| Copy here | `upstream/` = the extracted archive, **unmodified** |

## Licence

LGPL-2.1-or-later (`COPYING`, header of `src/sndfile.c`).

Dependencies: optional codec libraries: FLAC, ogg, vorbis, opus, LAME/mpg123.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`).


## Layout

- `upstream/`: the original sources, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
