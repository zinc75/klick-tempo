#!/bin/bash
# SPDX-License-Identifier: BSL-1.0
# Licence of the library it works on (Boost).
# Lists the Boost headers that a C++ source tree really includes, with the preprocessor of clang (dependency
# scan), to build headers.list. Run it against the complete Boost tree (extracted from the release archive).
# Usage: scan_headers.sh <boost-1.92.0 directory> <source directory> [extra include directories...]
# Example (klick): scan_headers.sh ~/tmp/boost-1.92.0 klick/upstream/src libs/build/arm64/include ...
# The defines are those of klick's SConstruct; the standard is C++11.
set -euo pipefail
boost=$(cd "$1" && pwd); src=$(cd "$2" && pwd); shift 2
inc=()
for d in "$@"; do inc+=(-I "$d"); done
list=$(mktemp)
for f in "$src"/*.cc; do
  clang++ -arch arm64 -std=c++11 -E -M -MG -w \
    -DENABLE_OSC -DENABLE_TERMINAL -DENABLE_RUBBERBAND -DENABLE_GETOPT_LONG -DHAVE_SNDFILE_OGG \
    -DVERSION='"0"' -DDATA_DIR='"x"' -I "$boost" ${inc[@]+"${inc[@]}"} "$f" \
    | tr ' \\' '\n\n' | grep "^$boost/boost/" >> "$list" || true
done
{ sed "s|^$boost/||" "$list" | sort -u; echo LICENSE_1_0.txt; } | sort
rm -f "$list"
