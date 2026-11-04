#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-only
# Licence of the library it builds (mpg123 (libmpg123 only)).
# Builds mpg123 (libmpg123 only) as a static universal library (arm64 + x86_64) from upstream/.
# Usage: build_universal.sh [output dir]    (default: libs/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common.sh"
ub_setup "$here/upstream" "${1:-$here/../build}"
for arch in $UB_ARCHS; do ub_autotools "$arch" --disable-components --enable-libmpg123; done
ub_merge
