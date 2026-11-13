#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Licence of the library it builds (Rubber Band).
# Builds Rubber Band as a static universal library (arm64 + x86_64) from upstream/, with its single-file
# compilation unit (single/RubberBandSingle.cpp): its own resampler, and the vDSP FFT of the system on macOS.
# No external library is needed; a program that links librubberband.a also needs -framework Accelerate.
# Usage: build_universal.sh [output dir]    (default: libs/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common.sh"
ub_setup "$here/upstream" "${1:-$here/../build}"
for arch in $UB_ARCHS; do
  mkdir -p "$UB_WORK/$arch" "$UB_OUT/$arch/lib" "$UB_OUT/$arch/include"
  ub_env "$arch" clang++ -arch "$arch" -std=c++11 -O2 -DNDEBUG -c "$UB_SRC/single/RubberBandSingle.cpp" -o "$UB_WORK/$arch/RubberBandSingle.o"
  rm -f "$UB_OUT/$arch/lib/librubberband.a"
  ar rcs "$UB_OUT/$arch/lib/librubberband.a" "$UB_WORK/$arch/RubberBandSingle.o"
  rm -rf "$UB_OUT/$arch/include/rubberband"
  cp -R "$UB_SRC/rubberband" "$UB_OUT/$arch/include/rubberband"
done
ub_merge
