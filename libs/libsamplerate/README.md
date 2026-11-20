# libsamplerate

Library for sample rate conversion of audio data (used by jack-play).

## Upstream

| | |
|---|---|
| Project | libsamplerate |
| Author | Erik de Castro Lopo and contributors |
| Source | https://github.com/libsndfile/libsamplerate |
| Version | version 0.2.2 (tag `0.2.2`, commit `c96f5e3de9c4488f4e6c97f59f5245f22fda22f7`), released 2021-09-05 |
| Copy here | `upstream/` = a Git submodule of the repository above, at the commit above, **unmodified** (clone with `--recurse-submodules`) |

The release archive `libsamplerate-0.2.2.tar.xz` (SHA-256 `3258da280511d24b49d6b08615bbe824d0cacc9842b0e4caf11c52cf2b043893`, identical to the value in the Homebrew formula) has the same files as the tag, plus the ones that autotools generates (`configure`, `Makefile.in`, `ltmain.sh` ...). The build makes them in a temporary copy.

## Licence

BSD-2-Clause (`COPYING`).

No dependencies (libsndfile, FFTW and ALSA are optional and only used by the tests and examples).

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`). It needs autoconf, automake and libtool, to generate `configure` from the Git checkout. The libraries are identical to the ones built from the release archive, once stripped.


## Layout

- `upstream/`: the upstream sources, as published by Erik de Castro Lopo, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
