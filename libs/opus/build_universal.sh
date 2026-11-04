#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Licence of the library it builds (Opus).
# Builds Opus as a static universal library (arm64 + x86_64) from upstream/.
# Usage: build_universal.sh [output dir]    (default: libs/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common.sh"
ub_setup "$here/upstream" "${1:-$here/../build}"
for arch in $UB_ARCHS; do ub_autotools "$arch" --disable-doc --disable-extra-programs; done
ub_merge
