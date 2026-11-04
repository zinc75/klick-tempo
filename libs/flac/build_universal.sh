#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Licence of the library it builds (FLAC (libFLAC only, not the GPL programs)).
# Builds FLAC (libFLAC only, not the GPL programs) as a static universal library (arm64 + x86_64) from upstream/.
# Needs libogg built first (libs/libogg/build_universal.sh) in the same output directory.
# Usage: build_universal.sh [output dir]    (default: libs/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common.sh"
ub_setup "$here/upstream" "${1:-$here/../build}"
for arch in $UB_ARCHS; do ub_autotools "$arch" --disable-programs --disable-examples --disable-cpplibs --disable-doxygen-docs; done
ub_merge
