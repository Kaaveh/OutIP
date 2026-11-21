#!/bin/bash
# The gate: source rules, tests, the ad-hoc bundle and the self-check on sample data. Sends no request (R27).
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "check: FAILED: $*" >&2; exit 1; }

# 1. OutIPCore imports Foundation only.
bad=$(grep -rhE '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]' Sources/OutIPCore \
    | grep -vE '^[[:space:]]*import Foundation[[:space:]]*$' || true)
[ -z "$bad" ] || fail "Sources/OutIPCore imports more than Foundation: $bad"

# 2. No SwiftUI, network code only in Checker.swift, no cleartext URL.
if grep -rqE 'import[[:space:]]+SwiftUI' Sources; then fail "Sources imports SwiftUI"; fi
bad=$(grep -rlE 'URLSession|import Network|NWPathMonitor' Sources | grep -vx 'Sources/OutIP/Checker.swift' || true)
[ -z "$bad" ] || fail "network code outside Sources/OutIP/Checker.swift: $bad"
if grep -rq 'http://' Sources; then fail "Sources contains http://"; fi

# 3. The rules.
swift test

# 4. The bundle, always ad-hoc so no keychain is touched.
OUTIP_SIGN_IDENTITY=- scripts/build-app.sh

# 5. The bundle's signature and Info.plist.
app=build/OutIP.app
plist="$app/Contents/Info.plist"
plutil -lint "$plist"
codesign --verify --strict "$app"
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$plist")" = true ] || fail "LSUIElement is not true"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = ir.kaavehdev.outip ] || fail "wrong CFBundleIdentifier"
if /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity' "$plist" >/dev/null 2>&1; then
    fail "Info.plist has an NSAppTransportSecurity key"
fi

# 6. The self-check prints the expected bar and menu, then its footprint.
out=$(timeout 30 "$app/Contents/MacOS/OutIP" --self-check) || fail "self-check exited with $?"
expected='bar: 🇸🇪 203.0.113.7
menu: # Sweden
menu: Copy 203.0.113.7
menu: 12:05:13 PM · ipv4.icanhazip.com
menu: ---
menu: Refresh now
menu: Check every > 10 seconds, ✓ 30 seconds, 1 minute, 5 minutes
menu: Launch at login
menu: ---
menu: Quit OutIP'
body="${out%$'\n'*}"
last="${out##*$'\n'}"
if [ "$body" != "$expected" ]; then
    diff <(echo "$expected") <(echo "$body") >&2 || true
    fail "self-check output differs from the expected text"
fi
footprint_line='^footprint: [0-9]+\.[0-9] MB$'
[[ "$last" =~ $footprint_line ]] || fail "unexpected last line: $last"

# 7.
echo "$last"
echo "check: OK"
