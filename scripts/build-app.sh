#!/bin/bash
# Builds build/OutIP.app from the release product and signs it with $OUTIP_SIGN_IDENTITY, ad-hoc when unset (R7).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
bin="$(swift build -c release --show-bin-path)"

app=build/OutIP.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin/OutIP" "$app/Contents/MacOS/OutIP"
cp Support/Info.plist "$app/Contents/Info.plist"

codesign --force --sign "${OUTIP_SIGN_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
echo "built: $app"
