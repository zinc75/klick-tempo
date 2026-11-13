# libsamplerate

Library for sample rate conversion of audio data (used by jack-play).

## Upstream

| | |
|---|---|
| Project | libsamplerate |
| Author | Erik de Castro Lopo and contributors |
| Source | https://github.com/libsndfile/libsamplerate/releases/download/0.2.2/libsamplerate-0.2.2.tar.xz |
| Version | version 0.2.2, released 2021-09-05 (archive downloaded 2026-11-04) |
| Archive | `libsamplerate-0.2.2.tar.xz` (not committed) |
| SHA-256 | `3258da280511d24b49d6b08615bbe824d0cacc9842b0e4caf11c52cf2b043893`, identical to the value in the Homebrew formula |
| Copy here | `upstream/` = the extracted archive, **unmodified** |

## Licence

BSD-2-Clause (`COPYING`).

No dependencies (libsndfile, FFTW and ALSA are optional and only used by the tests and examples).

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`).


## Layout

- `upstream/`: the upstream sources, as published by Erik de Castro Lopo, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
