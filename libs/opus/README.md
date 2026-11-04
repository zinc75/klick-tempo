# Opus

Reference implementation of the Opus audio codec (`libopus`).

## Upstream

| | |
|---|---|
| Project | Opus (libopus) |
| Author | Xiph.Org Foundation, Skype Limited, Octasic, Jean-Marc Valin, Timothy B. Terriberry, CSIRO, Gregory Maxwell, Mark Borgerding and others (see `AUTHORS`) |
| Source | https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz |
| Version | version 1.6.1 (archive downloaded 2026-10-31) |
| Archive | `opus-1.6.1.tar.gz` (not committed) |
| SHA-256 | `6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1`, identical to the value published in `SHA256SUMS.txt` next to the archive and on https://opus-codec.org/downloads/ |
| Copy here | `upstream/` = the extracted archive, **unmodified** |

## Licence

BSD-3-Clause (`COPYING`).

No dependencies (libopus alone). To write `.opus` files, libsndfile also needs libogg.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`).


## Layout

- `upstream/`: the upstream sources, as published by Xiph.Org, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
