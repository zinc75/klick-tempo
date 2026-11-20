# libogg

Library for the Ogg container format (used by Vorbis, Opus and FLAC in Ogg).

## Upstream

| | |
|---|---|
| Project | libogg |
| Author | Xiph.Org Foundation |
| Source | https://github.com/xiph/ogg |
| Version | version 1.3.6 (tag `v1.3.6`, commit `be05b13e98b048f0b5a0f5fa8ce514d56db5f822`) |
| Copy here | `upstream/` = a Git submodule of the repository above, at the commit above, **unmodified** (clone with `--recurse-submodules`) |

The release archive `libogg-1.3.6.tar.xz` (SHA-256 `5c8253428e181840cd20d41f3ca16557a9cc04bad4a3d04cce84808677fa1061`) has the same files as the tag, plus the ones that autotools generates (`configure`, `Makefile.in`, `ltmain.sh` ...). The build makes them in a temporary copy.

## Licence

BSD-3-Clause (`COPYING`).

No dependencies.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`). It needs autoconf, automake and libtool, to generate `configure` from the Git checkout. The object code is identical to the one built from the release archive.


## Layout

- `upstream/`: the upstream sources, as published by Xiph.Org, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
