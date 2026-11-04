# liblo

Implementation of the Open Sound Control (OSC) protocol. Used by jack_capture for its OSC remote control.

## Upstream

| | |
|---|---|
| Project | liblo |
| Author | Steve Harris and contributors (see `AUTHORS`) |
| Source | https://github.com/radarsat1/liblo/releases/download/0.36/liblo-0.36.tar.gz |
| Version | version 0.36 (`NEWS`: released 2026-04-30; published on GitHub 2026-06-19; archive downloaded 2026-10-31) |
| Archive | `liblo-0.36.tar.gz` (not committed) |
| SHA-256 | `c08d14832e8dcf8f06840405824a4f9611a0cb3daed0198946326c740941c8b6`, identical to the digest GitHub publishes for this release asset. The release also carries a prebuilt `liblo.7.dylib`, which is not used |
| Copy here | `upstream/` = the extracted archive, **unmodified** |

## Licence

LGPL-2.1-or-later (`COPYING` is the LGPL v2.1; header of `src/server.c`: "any later version").

Dependencies: none (POSIX threads for the server thread).

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`).


## Layout

- `upstream/`: the upstream sources, as published by the liblo project, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
