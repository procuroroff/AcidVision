#!/usr/bin/env bash
# Installs an iOS 15.x (or 16.x) SDK into Theos.
#
# Usage: bash .github/scripts/install-sdk.sh "$THEOS/sdks"
#
# theos/sdks is a large repository; a sparse checkout keeps CI fast. If an SDK
# is already present the script is a no-op.

set -euo pipefail

SDKS_DIR="${1:-${THEOS:-/opt/theos}/sdks}"
mkdir -p "$SDKS_DIR"

if ls "$SDKS_DIR"/*.sdk >/dev/null 2>&1; then
    echo "==> SDK already installed:"
    ls "$SDKS_DIR"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> sparse clone theos/sdks (15.x / 16.x only)"
git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/theos/sdks.git "$WORK/sdks" >/dev/null
cd "$WORK/sdks"
git sparse-checkout set --no-cone 'iPhoneOS15.*' 'iPhoneOS16.*' >/dev/null 2>&1 || true

pick="$(ls -d iPhoneOS15.*.sdk 2>/dev/null | sort -V | tail -n 1 || true)"
if [ -z "$pick" ]; then
    pick="$(ls -d iPhoneOS16.*.sdk 2>/dev/null | sort -V | tail -n 1 || true)"
fi
if [ -z "$pick" ]; then
    echo "::error::no iPhoneOS15.x or iPhoneOS16.x SDK found in theos/sdks" >&2
    ls
    exit 1
fi

cp -R "$pick" "$SDKS_DIR/"
echo "==> installed: $pick"
