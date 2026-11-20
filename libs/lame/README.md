# LAME

MP3 encoder (`libmp3lame`) and the `lame` program.

## Upstream

| | |
|---|---|
| Project | LAME |
| Author | The LAME Project (see `AUTHORS`) |
| Source | https://downloads.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz |
| Version | version 4.0 (released 2026-07-11; archive downloaded 2026-10-31) |
| Archive | `lame-4.0.tar.gz` (not committed) |
| MD5 | `4b82945ffc410cb5d3947b9d6f890ae8`, identical to the value published by SourceForge for this file. The project publishes no SHA-256 and no signature |
| SHA-256 | `3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb` (computed on the downloaded archive) |
| Copy here | `upstream/` = a Git submodule of [zinc75/lame-releases](https://github.com/zinc75/lame-releases), at tag `4.0` (commit `e3f49139c70de00923a37538fc46ac1883d21164`): the files of the archive above, **unmodified** (clone with `--recurse-submodules`) |

That repository holds release snapshots, one commit per release; it is not a mirror of LAME, which is developed in Subversion on SourceForge and has no official Git repository. The release also has the archive as a file. The archive carries `configure`, so nothing is generated at build time.

## Licence

LGPL-2.0-or-later (`COPYING` is the LGPL v2; header of `libmp3lame/lame.c`: "GNU Library General Public License … version 2 … or (at your option) any later version"). `LICENSE` explains what the LGPL requires of a program that links the library.

Dependencies: none.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`).
- LAME 4.0 includes the fixes of 3.101 (encoder buffer overflow, SSE bug) and fixes the build with current Clang.


## Layout

- `upstream/`: the upstream sources, as published by the LAME project, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
