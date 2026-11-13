#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Licence of the program it builds (klick).
# Builds klick as a universal binary (arm64 + x86_64) from upstream/ and patches/, linked statically with
# libsndfile and its codecs, libsamplerate, liblo and Rubber Band (single-file build, vDSP FFT). Boost is used as
# headers only, from libs/boost. Only libjack stays dynamic, linked by its full path.
# The libraries must be built first, with libs/<name>/build_universal.sh, in <libs build dir>.
# Also writes libklick.a (everything but main.cc), for a program that embeds the engine.
# Usage: build_universal.sh [libs build dir] [output dir]
#        (defaults: libs/build, klick/build)
# Environment: JACK_PREFIX = where the JACK headers and libjack are installed (default /usr/local).
# The sounds are copied to <output dir>/samples. klick looks for them in the directory compiled in as DATA_DIR
# (/usr/local/share/klick), or in $KLICK_DATA_DIR (patch 0001).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../libs/common.sh"
ub_setup "$here/upstream" "${1:-$here/../libs/build}"
out=${2:-$here/build}
mkdir -p "$out"; out=$(cd "$out" && pwd)
jack_prefix=${JACK_PREFIX:-/usr/local}
boost=$(cd "$here/../libs/boost/upstream" && pwd)
version=$(sed -n "s/^version = '\(.*\)'$/\1/p" "$UB_SRC/SConstruct")
[ -n "$version" ] || { echo "error: cannot read the version from SConstruct" >&2; exit 1; }

# Same file list as SConstruct, with OSC, terminal control, Rubber Band and getopt_long enabled.
sources="main klick options audio_interface audio_interface_jack audio_interface_sndfile audio_chunk tempomap
         metronome metronome_simple metronome_map metronome_jack position osc_interface osc_handler terminal_handler"

# Expose only JACK to the compiler: other libraries installed next to it must not be picked up.
jack=$UB_WORK/jack
mkdir -p "$jack/include" "$jack/lib"
ln -s "$jack_prefix/include/jack" "$jack/include/jack"
ln -s "$jack_prefix/lib/libjack.dylib" "$jack/lib/libjack.dylib"

for arch in $UB_ARCHS; do
  prefix=$UB_OUT/$arch
  dir=$UB_WORK/klick_$arch
  rm -rf "$dir"; cp -R "$UB_SRC" "$dir"
  ub_patch "$dir"
  mkdir -p "$dir/obj"
  objs=""; engine=""
  for f in $sources; do
    ub_env "$arch" clang++ -arch "$arch" -std=c++11 -O2 -Wall -Wextra -DNDEBUG \
      -DVERSION="\"$version\"" -DDATA_DIR='"/usr/local/share/klick"' \
      -DENABLE_OSC -DENABLE_TERMINAL -DENABLE_RUBBERBAND -DENABLE_GETOPT_LONG -DHAVE_SNDFILE_OGG \
      -I"$prefix/include" -I"$jack/include" -I"$boost" \
      -c "$dir/src/$f.cc" -o "$dir/obj/$f.o"
    objs="$objs $dir/obj/$f.o"
    [ "$f" = main ] || engine="$engine $dir/obj/$f.o"
  done
  # Static libraries by pkg-config; Rubber Band has no .pc file and needs Accelerate.
  libs=$(ub_env "$arch" pkg-config --static --libs sndfile samplerate liblo)
  ub_env "$arch" clang++ -arch "$arch" $objs -o "$dir/klick" \
    -L"$prefix/lib" -L"$jack/lib" $libs -lrubberband -framework Accelerate -ljack -lpthread
  mkdir -p "$UB_WORK/bin_$arch"
  cp "$dir/klick" "$UB_WORK/bin_$arch/klick"
  rm -f "$UB_WORK/bin_$arch/libklick.a"
  ar rcs "$UB_WORK/bin_$arch/libklick.a" $engine
done

lipo -create "$UB_WORK"/bin_arm64/klick "$UB_WORK"/bin_x86_64/klick -output "$out/klick"
lipo -create "$UB_WORK"/bin_arm64/libklick.a "$UB_WORK"/bin_x86_64/libklick.a -output "$out/libklick.a"
strip -x "$out/klick"
mkdir -p "$out/samples"; cp "$UB_SRC"/samples/*.wav "$out/samples/"
lipo -info "$out/klick"
# Anything dynamic besides the system libraries and libjack would be missing on another machine.
if otool -L "$out/klick" | grep '^[[:space:]]' | awk '{print $1}' | grep -v -e '^/usr/lib/' -e '^/System/' -e 'libjack'; then
  echo "error: unexpected dynamic dependency" >&2; exit 1
fi
