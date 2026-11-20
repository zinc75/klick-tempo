# Rubber Band

Library for audio time-stretching and pitch-shifting (used by klick to change the pitch of its sounds).

## Upstream

| | |
|---|---|
| Project | Rubber Band Library |
| Author | Particular Programs Ltd (Chris Cannam) |
| Source | https://github.com/breakfastquay/rubberband |
| Version | version 4.0.0 (tag `v4.0.0`, commit `1d95888bec3ae0a17c0c4af791810d5a63f6bc35`) |
| Copy here | `upstream/` = a Git submodule of the repository above, at the commit above, **unmodified** (clone with `--recurse-submodules`) |

The release archive `rubberband-4.0.0.tar.bz2` (SHA-256 `af050313ee63bc18b35b2e064e5dce05b276aaf6d1aa2b8a82ced1fe2f8028e9`, identical to the value in the Homebrew formula) has the same files as the tag, except for a `.hg_archival.txt` that it carries and three deployment scripts of `otherbuilds/deploy/` that it does not. Nothing is generated at build time: the library is compiled from its single-file compilation unit.

## Licence

GPL-2.0-or-later (`COPYING`, header of the source files). The authors also sell a commercial licence; this repository uses the GPL one.

No external dependencies. The build here uses the single-file compilation unit (`single/RubberBandSingle.cpp`): the library's own resampler and, on macOS, the vDSP FFT of the system, so a program that links it needs `-framework Accelerate`. The FFT and resampler code under `src/ext/` (KissFFT, Speex) is not part of this build.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`). The headers are in `include/rubberband/`. The library is identical to the one built from the release archive, once stripped.


## Layout

- `upstream/`: the upstream sources, as published by Particular Programs, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
