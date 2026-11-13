#!/bin/bash
# SPDX-License-Identifier: BSD-2-Clause
# Licence of the library it builds (libsamplerate).
# Builds libsamplerate as a static universal library (arm64 + x86_64) from upstream/.
# libsndfile, FFTW and ALSA are turned off: only the tests and examples use them, and the build must not
# pick up whatever the machine happens to have.
# Usage: build_universal.sh [output dir]    (default: libs/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common.sh"
ub_setup "$here/upstream" "${1:-$here/../build}"
for arch in $UB_ARCHS; do ub_autotools "$arch" --disable-sndfile --disable-alsa --disable-fftw; done
ub_merge
