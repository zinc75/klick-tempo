#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Licence of the library it builds (Opus).
# Builds Opus as a static universal library (arm64 + x86_64) from upstream/.
# Usage: build_universal.sh [output dir]    (default: libs/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common.sh"
ub_setup "$here/upstream" "${1:-$here/../build}"
# A release archive has a package_version file with the version; a git checkout takes it from "git describe", which finds no
# repository in the copy and says "unknown" (it ends up in the library as "libopus unknown").
opus_version() { echo 'PACKAGE_VERSION="1.6.1"' > package_version; }
UB_COPY_HOOK=opus_version
for arch in $UB_ARCHS; do ub_autotools "$arch" --disable-doc --disable-extra-programs; done
ub_merge
