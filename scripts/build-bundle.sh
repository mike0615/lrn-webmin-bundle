#!/usr/bin/env bash
# build-bundle.sh — Full build pipeline: tarball → RPM
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="lrn-webmin-bundle"
VERSION="1.0"
RELEASE="1"

cd "$ROOT"

echo "[*] Checking SOURCES/repo/ ..."
RPM_COUNT=$(ls SOURCES/repo/*.rpm 2>/dev/null | wc -l || echo 0)
if [[ "$RPM_COUNT" -eq 0 ]]; then
    echo "[!] SOURCES/repo/ is empty — run ./scripts/fetch-deps.sh first"
    echo "    Build will continue, but the resulting RPM will have no bundled packages."
    read -rp "Continue anyway? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || exit 0
fi

echo "[*] Building tarball and RPM ..."
make NAME="$NAME" VERSION="$VERSION" RELEASE="$RELEASE" rpm

echo ""
echo "[+] Build complete:"
find "$ROOT/RPMS" -name '*.rpm' -exec ls -lh {} \;
