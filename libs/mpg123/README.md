# mpg123

MP3 decoder library (`libmpg123`) and player. Needed by libsndfile for its MP3 support (libsndfile reads MP3 with mpg123 and writes it with LAME).

## Upstream

| | |
|---|---|
| Project | mpg123 |
| Author | Michael Hipp and others; maintainer since 2006: Thomas Orgis |
| Source | https://www.mpg123.de/download/mpg123-1.33.7.tar.bz2 |
| Version | version 1.33.7 (released 2026-08-02; archive downloaded 2026-10-31) |
| Archive | `mpg123-1.33.7.tar.bz2` (not committed) |
| Signature | `mpg123-1.33.7.tar.bz2.sig` (not committed), verified with `gpg` in a throw-away keyring: good signature by Thomas Orgis, key fingerprint `D021 FF8E CF4B E097 19D6 1A27 231C 4CBC 60D5 CAFE`, the fingerprint published on https://www.mpg123.de/download.shtml |
| SHA-256 | `31d0e35a4ca567ec9b5ebda6c3062bb4435d6d3eacd6ef0d95cadd7854dc03ee` (computed on the downloaded archive; the project publishes no checksum, only the signature) |
| Copy here | `upstream/` = the extracted archive, **unmodified** |

## Licence

LGPL-2.1 (`COPYING`).

Dependencies: none for the library.

## State on macOS

- Universal static build (arm64 + x86_64) with `build_universal.sh`; the result goes to `libs/build/`, which is not committed (see `libs/common.sh`).


## Layout

- `upstream/`: the upstream sources, as published by the mpg123 project, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
