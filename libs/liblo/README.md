# liblo

Implementation of the Open Sound Control (OSC) protocol. Used by jack_capture for its OSC remote control.

## Upstream

| | |
|---|---|
| Project | liblo |
| Author | Steve Harris and contributors (see `AUTHORS`) |
| Source | https://github.com/radarsat1/liblo |
| Version | version 0.36 (tag `0.36`, commit `025f277275e6b81032a72dfb0b131adab80363e6`; `NEWS`: released 2026-04-30, published on GitHub 2026-06-19) |
| Copy here | `upstream/` = a Git submodule of the repository above, at the commit above, **unmodified** (clone with `--recurse-submodules`) |

The release archive `liblo-0.36.tar.gz` (SHA-256 `c08d14832e8dcf8f06840405824a4f9611a0cb3daed0198946326c740941c8b6`, identical to the digest GitHub publishes for this release asset) has the same files as the tag, plus the ones that autotools generates (`configure`, `Makefile.in`, `ltmain.sh` ...). The release also carries a prebuilt `liblo.7.dylib`, which is not used. The build makes `configure` in a temporary copy.

## Licence

LGPL-2.1-or-later (`COPYING` is the LGPL v2.1; header of `src/server.c`: "any later version").

Dependencies: none (POSIX threads for the server thread).

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`). It needs autoconf, automake and libtool, to generate `configure` from the Git checkout. The library is identical to the one built from the release archive, once stripped.


## Layout

- `upstream/`: the upstream sources, as published by the liblo project, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
