# libvorbis

Reference library of the Vorbis audio codec (encoder and decoder, used for Ogg Vorbis files).

## Upstream

| | |
|---|---|
| Project | libvorbis |
| Author | Xiph.Org Foundation |
| Source | https://github.com/xiph/vorbis |
| Version | version 1.3.7 (tag `v1.3.7`, commit `0657aee69dec8508a0011f47f3b69d7538e9d262`) |
| Copy here | `upstream/` = a Git submodule of the repository above, at the commit above, **unmodified** (clone with `--recurse-submodules`) |

The release archive `libvorbis-1.3.7.tar.xz` (SHA-256 `b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b`) has the same files as the tag, plus the ones that autotools generates (`configure`, `Makefile.in`, `ltmain.sh` ...). The build makes them in a temporary copy.

## Licence

BSD-3-Clause (`COPYING`).

Dependencies: libogg (`libs/libogg/`).

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`). It needs autoconf, automake and libtool, to generate `configure` from the Git checkout. The libraries are identical to the ones built from the release archive, once stripped.
- `patches/0001-macos-no-force-cpusubtype-all.patch`: the `configure.ac` of libvorbis 1.3.7 adds the PowerPC-era linker option `-force_cpusubtype_ALL` on Darwin, which the current linker rejects; the patch removes it from `configure.ac`, from which the build generates `configure`.


## Layout

- `upstream/`: the upstream sources, as published by Xiph.Org, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
