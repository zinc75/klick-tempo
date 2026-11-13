#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Licence of the program it builds (klick).
# Builds the test programs of the CoreAudio backend for one architecture, against klick/build/libklick.a.
# klick/build_universal.sh must have been run first (it also builds the libraries' dependencies, see its header).
# The headers come from a copy of upstream/ with the patches of patches/ applied, as for the library.
# Usage: build_tests.sh [arch] [libs build dir] [output dir]
#        (defaults: native architecture, libs/build, klick/build/engine_tests)
# The programs play clicks on the default output device, at low volume, for a few seconds:
#   engine_test <sounds dir> [seconds]           120 then 240 BPM, clicks measured in the signal given to CoreAudio
#   engine_events_test <sounds dir> <map file>   beat events compared with the clicks, simple metronome and tempo map
#   engine_steady_test <sounds dir> [seconds]    4/4 at 120 BPM, dropouts and lateness reported by the backend
# The sounds are in klick/build/samples.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../libs/common.sh"
arch=${1:-$(uname -m)}
ub_setup "$here/../upstream" "${2:-$here/../../libs/build}"
out=${3:-$here/../build/engine_tests}
mkdir -p "$out"; out=$(cd "$out" && pwd)
jack_prefix=${JACK_PREFIX:-/usr/local}   # the klick headers include the JACK type headers; libjack is not linked
boost=$(cd "$here/../../libs/boost/upstream" && pwd)
lib=$here/../build/libklick.a
[ -f "$lib" ] || { echo "error: $lib is missing, run klick/build_universal.sh first" >&2; exit 1; }

src=$UB_WORK/klick
cp -R "$UB_SRC" "$src"
ub_patch "$src"
prefix=$UB_OUT/$arch
libs=$(ub_env "$arch" pkg-config --static --libs sndfile samplerate)

for t in engine_test engine_events_test engine_steady_test; do
  ub_env "$arch" clang++ -arch "$arch" -std=c++11 -O2 -Wall -Wextra -DNDEBUG -DENABLE_RUBBERBAND \
    -I"$here" -I"$src/src" -I"$jack_prefix/include" -I"$boost" -I"$prefix/include" \
    "$here/audio_interface_coreaudio.cc" "$here/$t.cc" "$lib" \
    -L"$prefix/lib" $libs -lrubberband \
    -framework AudioToolbox -framework CoreAudio -framework Accelerate -o "$out/${t}_$arch"
  echo "built $out/${t}_$arch"
done
