#!/bin/bash
# SPDX-License-Identifier: LGPL-2.0-or-later
# Licence of the library it builds (LAME (libmp3lame only)).
# Builds LAME (libmp3lame only) as a static universal library (arm64 + x86_64) from upstream/.
# Usage: build_universal.sh [output dir]    (default: libs/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common.sh"
ub_setup "$here/upstream" "${1:-$here/../build}"
for arch in $UB_ARCHS; do ub_autotools "$arch" --disable-frontend --disable-decoder; done
ub_merge
