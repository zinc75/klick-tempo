# libogg

Library for the Ogg container format (used by Vorbis, Opus and FLAC in Ogg).

## Upstream

| | |
|---|---|
| Project | libogg |
| Author | Xiph.Org Foundation |
| Source | https://downloads.xiph.org/releases/ogg/libogg-1.3.6.tar.xz |
| Version | version 1.3.6 (archive downloaded 2026-10-31) |
| Archive | `libogg-1.3.6.tar.xz` (not committed) |
| SHA-256 | `5c8253428e181840cd20d41f3ca16557a9cc04bad4a3d04cce84808677fa1061`, identical to the value published in `SHA256SUMS` next to the archive |
| Copy here | `upstream/` = the extracted archive, **unmodified** |

## Licence

BSD-3-Clause (`COPYING`).

No dependencies.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`).


## Layout

- `upstream/`: the upstream sources, as published by Xiph.Org, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
