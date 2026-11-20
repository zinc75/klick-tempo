# Opus

Reference implementation of the Opus audio codec (`libopus`).

## Upstream

| | |
|---|---|
| Project | Opus (libopus) |
| Author | Xiph.Org Foundation, Skype Limited, Octasic, Jean-Marc Valin, Timothy B. Terriberry, CSIRO, Gregory Maxwell, Mark Borgerding and others (see `AUTHORS`) |
| Source | https://github.com/xiph/opus |
| Version | version 1.6.1 (tag `v1.6.1`, commit `22244de5a79bd1d6d623c32e72bf1954b56235be`) |
| Copy here | `upstream/` = a Git submodule of the repository above, at the commit above, **unmodified** (clone with `--recurse-submodules`) |

The release archive `opus-1.6.1.tar.gz` (SHA-256 `6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1`, identical to the value published in `SHA256SUMS.txt` next to the archive and on https://opus-codec.org/downloads/) has the same files as the tag, plus the ones that autotools generates (`configure`, `Makefile.in`, `ltmain.sh` ...) and a `package_version` file that holds the version. The build makes `configure` in a temporary copy, and writes `package_version` there, because Opus would otherwise read the version from Git and find "unknown".

## Licence

BSD-3-Clause (`COPYING`).

No dependencies (libopus alone). To write `.opus` files, libsndfile also needs libogg.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`). It needs autoconf, automake and libtool, to generate `configure` from the Git checkout. The library is identical to the one built from the release archive, once stripped.


## Layout

- `upstream/`: the upstream sources, as published by Xiph.Org, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
