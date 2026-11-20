#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Licence of the library it builds (libsndfile).
# Builds libsndfile as a static universal library (arm64 + x86_64) from upstream/, with all
# the external codecs: FLAC, Ogg Vorbis, Opus, MP3 (LAME to write, mpg123 to read).
# Needs libogg, libvorbis, FLAC, Opus, LAME and mpg123 built first (their build_universal.sh)
# in the same output directory.
# Usage: build_universal.sh [output dir]    (default: libs/build)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common.sh"
ub_setup "$here/upstream" "${1:-$here/../build}"
# The codecs are static libraries: pkg-config must also report their own dependencies.
export PKG_CONFIG="pkg-config --static"
# Only the library, its headers and its pkg-config file: a git checkout needs GNU AutoGen to generate the test programs
# (a release archive carries them already), and they are not wanted here.
UB_MAKE_TARGETS="src/libsndfile.la"
UB_INSTALL_TARGETS="install-libLTLIBRARIES install-includeHEADERS install-pkgconfigDATA"
for arch in $UB_ARCHS; do
  ub_autotools "$arch" --disable-sqlite --disable-alsa --disable-full-suite
done
ub_merge
