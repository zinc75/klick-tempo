# Boost (headers used by klick)

Collection of C++ libraries. klick uses four header-only parts of it: `noncopyable`, `tokenizer`, `variant` and `lexical_cast`.

## Upstream

| | |
|---|---|
| Project | Boost |
| Author | the Boost community |
| Source | https://github.com/boostorg/boost/releases/download/boost-1.92.0/boost-1.92.0-b2-nodocs.tar.xz |
| Version | version 1.92.0, released 2026-08-12 (archive downloaded 2026-11-04) |
| Archive | `boost-1.92.0-b2-nodocs.tar.xz` (not committed) |
| SHA-256 | `ea7b982002cc9dfbe59b0b217b206f470dc75f3de0bb2973d844118934d82411`, identical to the value in the Homebrew formula and to the digest shown by GitHub |
| Copy here | `upstream/` = a Git submodule of [zinc75/boost-subset](https://github.com/zinc75/boost-subset), at tag `boost-1.92.0` (commit `7dbf06630ef7483f1762163263ee42651b5b5240`): **only the 492 headers that klick needs**, with `LICENSE_1_0.txt`, extracted **unmodified** from the archive above (the complete tree has 16 413 headers, 184 MB) (clone with `--recurse-submodules`) |

That repository holds a subset of a release of Boost, one commit per release; it is not a mirror or a fork. Boost is made of many libraries, each in its own Git repository, and the archive is where their headers are in one tree. The [Jack Apps Collection for macOS](https://github.com/zinc75/jack-apps-collection-macos) uses the same repository.

## Licence

BSL-1.0 (`upstream/LICENSE_1_0.txt`).

No dependencies. Everything is header-only: there is nothing to build.

## State on macOS

- `headers.list` is the list of the files kept. `extract_headers.sh` extracts those files from the archive into a folder (it checks the SHA-256 first): that is how a new release is put in `zinc75/boost-subset`. `scan_headers.sh` made the list: it runs the preprocessor of clang on the sources of klick and keeps the Boost headers they include (C++11, macOS, arm64 and x86_64 give the same list).
- Another program that needs more of Boost has to add its headers to the list.


## Layout

- `upstream/`: the Boost headers listed in `headers.list`, as published, never edited.
- `patches/`: none.
