# libvorbis

Reference library of the Vorbis audio codec (encoder and decoder, used for Ogg Vorbis files).

## Upstream

| | |
|---|---|
| Project | libvorbis |
| Author | Xiph.Org Foundation |
| Source | https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz |
| Version | version 1.3.7 (archive downloaded 2026-10-31) |
| Archive | `libvorbis-1.3.7.tar.xz` (not committed) |
| SHA-256 | `b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b`, identical to the value published in `SHA256SUMS` next to the archive |
| Copy here | `upstream/` = the extracted archive, **unmodified** |

## Licence

BSD-3-Clause (`COPYING`).

Dependencies: libogg (`libs/libogg/`).

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`).
- `patches/0001-macos-no-force-cpusubtype-all.patch`: the `configure` of libvorbis 1.3.7 adds the PowerPC-era linker option `-force_cpusubtype_ALL` on Darwin, which the current linker rejects; the patch removes it from `configure.ac` and `configure`.


## Layout

- `upstream/`: the upstream sources, as published by Xiph.Org, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
