#!/bin/bash
# For a person, never for automation: builds OutIP.app, replaces /Applications/OutIP.app and opens it (R28).
set -euo pipefail
cd "$(dirname "$0")/.."

# The identity is $OUTIP_SIGN_IDENTITY or ad-hoc; the keychain is never searched.
identity="${OUTIP_SIGN_IDENTITY:--}"
OUTIP_SIGN_IDENTITY="$identity" scripts/build-app.sh

pkill -x OutIP || true
while pgrep -x OutIP >/dev/null; do sleep 0.2; done  # else open may hit the dying instance
rm -rf /Applications/OutIP.app
ditto build/OutIP.app /Applications/OutIP.app
open /Applications/OutIP.app

if [ "$identity" = - ]; then
    echo "signed with: ad-hoc"
else
    echo "signed with: a keychain identity"
fi
