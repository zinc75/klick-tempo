# Rubber Band

Library for audio time-stretching and pitch-shifting (used by klick to change the pitch of its sounds).

## Upstream

| | |
|---|---|
| Project | Rubber Band Library |
| Author | Particular Programs Ltd (Chris Cannam) |
| Source | https://breakfastquay.com/files/releases/rubberband-4.0.0.tar.bz2 |
| Version | version 4.0.0 (archive downloaded 2026-11-04) |
| Archive | `rubberband-4.0.0.tar.bz2` (not committed) |
| SHA-256 | `af050313ee63bc18b35b2e064e5dce05b276aaf6d1aa2b8a82ced1fe2f8028e9`, identical to the value in the Homebrew formula |
| Copy here | `upstream/` = the extracted archive, **unmodified**, except that the two CI workflow files of `.github/workflows` are not kept |

## Licence

GPL-2.0-or-later (`COPYING`, header of the source files). The authors also sell a commercial licence; this repository uses the GPL one.

No external dependencies. The build here uses the single-file compilation unit (`single/RubberBandSingle.cpp`): the library's own resampler and, on macOS, the vDSP FFT of the system, so a program that links it needs `-framework Accelerate`. The FFT and resampler code under `src/ext/` (KissFFT, Speex) is not part of this build.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`). The headers are in `include/rubberband/`.


## Layout

- `upstream/`: the upstream sources, as published by Particular Programs, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
