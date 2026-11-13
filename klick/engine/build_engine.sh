#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Licence of the program it builds (klick).
# Builds libklickengine.a, the engine of klick with its CoreAudio backend and the C interface of
# klick_engine.h, as one universal static library (arm64 + x86_64) that contains everything it needs:
# the engine (klick/build/libklick.a), libsndfile and its codecs, libsamplerate and Rubber Band.
# An application links it with -lc++ and the AudioToolbox, CoreAudio and Accelerate frameworks.
# klick/build_universal.sh must have been run first. The headers come from a copy of upstream/ with the patches
# of patches/ applied. Also builds the C test of the interface (no audio device needed) for each architecture.
# Usage: build_engine.sh [libs build dir] [output dir]     (defaults: libs/build, klick/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../libs/common.sh"
ub_setup "$here/../upstream" "${1:-$here/../../libs/build}"
out=${2:-$here/../build}
mkdir -p "$out/engine_tests"; out=$(cd "$out" && pwd)
jack_prefix=${JACK_PREFIX:-/usr/local}   # the klick headers include the JACK type headers; libjack is not linked
boost=$(cd "$here/../../libs/boost/upstream" && pwd)
api=$(cd "$here/../swiftui/Sources/CKlickEngine/include" && pwd)
lib=$out/libklick.a
[ -f "$lib" ] || { echo "error: $lib is missing, run klick/build_universal.sh first" >&2; exit 1; }
# A library built before the last patch would not match the headers used here (different class layouts).
for p in "$here"/../patches/*.patch; do
  [ "$p" -nt "$lib" ] && { echo "error: $(basename "$p") is newer than $lib, run klick/build_universal.sh again" >&2; exit 1; }
done

src=$UB_WORK/klick
cp -R "$UB_SRC" "$src"
ub_patch "$src"

for arch in $UB_ARCHS; do
  prefix=$UB_OUT/$arch
  work=$UB_WORK/$arch; mkdir -p "$work"
  for f in audio_interface_coreaudio klick_engine; do
    cc=$here/$f.cc; [ -f "$cc" ] || cc=$here/$f.cpp
    ub_env "$arch" clang++ -arch "$arch" -std=c++11 -O2 -Wall -Wextra -DNDEBUG -DENABLE_RUBBERBAND \
      -I"$here" -I"$api" -I"$src/src" -I"$jack_prefix/include" -I"$boost" -I"$prefix/include" \
      -c "$cc" -o "$work/$f.o"
  done
  # Thin copies of the libraries: the static libraries of sndfile and its codecs, as pkg-config lists them.
  thin=()
  lipo -thin "$arch" "$lib" -output "$work/libklick.a"; thin+=("$work/libklick.a")
  for l in $(ub_env "$arch" pkg-config --static --libs-only-l sndfile samplerate) -lrubberband; do
    name=${l#-l}
    [ -f "$prefix/lib/lib$name.a" ] && thin+=("$prefix/lib/lib$name.a")
  done
  libtool -static -o "$work/libklickengine.a" "$work/audio_interface_coreaudio.o" "$work/klick_engine.o" "${thin[@]}" 2>&1 | grep -v "has no symbols" || true
  # The C test links the library like an application would.
  ub_env "$arch" clang -arch "$arch" -O2 -Wall -Wextra -I"$api" "$here/engine_c_test.c" "$work/libklickengine.a" \
    -lc++ -framework AudioToolbox -framework CoreAudio -framework Accelerate -o "$out/engine_tests/engine_c_test_$arch"
  # Plays on the default output device: run it by hand and change the output of the Mac meanwhile.
  ub_env "$arch" clang -arch "$arch" -O2 -Wall -Wextra -I"$api" "$here/engine_device_test.c" "$work/libklickengine.a" \
    -lc++ -framework AudioToolbox -framework CoreAudio -framework CoreFoundation -framework Accelerate -o "$out/engine_tests/engine_device_test_$arch"
done

lipo -create "$UB_WORK"/arm64/libklickengine.a "$UB_WORK"/x86_64/libklickengine.a -output "$out/libklickengine.a"
lipo -info "$out/libklickengine.a"
echo "C tests: $out/engine_tests/engine_c_test_<arch> <sounds dir>   (sounds: $out/samples)"
