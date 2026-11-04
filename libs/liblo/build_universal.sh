#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Licence of the library it builds (liblo).
# Builds liblo as a static universal library (arm64 + x86_64) from upstream/.
# Usage: build_universal.sh [output dir]    (default: libs/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common.sh"
ub_setup "$here/upstream" "${1:-$here/../build}"
for arch in $UB_ARCHS; do
  ub_autotools "$arch" --disable-doc --disable-tests --disable-network-tests --disable-tools --disable-examples
done
ub_merge
