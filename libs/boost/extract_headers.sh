#!/bin/bash
# SPDX-License-Identifier: BSL-1.0
# Licence of the library it extracts (Boost).
# Extracts into a new folder the Boost headers listed in headers.list (plus the licence) from the Boost release
# archive, after checking the SHA-256 of the archive. The files are not modified.
# Usage: extract_headers.sh [archive [output folder]]    (defaults: boost-1.92.0-b2-nodocs.tar.xz in this folder, upstream/ next to it)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
archive="${1:-$here/boost-1.92.0-b2-nodocs.tar.xz}"
out="${2:-$here/upstream}"
expected=ea7b982002cc9dfbe59b0b217b206f470dc75f3de0bb2973d844118934d82411
actual=$(shasum -a 256 "$archive" | cut -d' ' -f1)
[ "$actual" = "$expected" ] || { echo "error: SHA-256 of $archive is $actual, expected $expected" >&2; exit 1; }
[ ! -e "$out" ] || { echo "error: $out already exists: remove it first" >&2; exit 1; }
mkdir -p "$out"
list=$(mktemp)
sed 's|^|boost-1.92.0/|' "$here/headers.list" > "$list"
tar -xJf "$archive" -C "$out" --strip-components=1 -T "$list"
rm -f "$list"
echo "extracted $(find "$out" -type f | wc -l | tr -d ' ') files into $out"
