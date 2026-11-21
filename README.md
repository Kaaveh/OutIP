# OutIP

OutIP is a macOS menu bar app that shows your public IPv4 address and the flag of the country it belongs to: `🇸🇪 203.0.113.7`. It checks again every 30 seconds, or at a pace you pick, and right after the network changes, so a glance tells you where a VPN or a proxy lets your traffic out.

Status: built; the manual checks on a real Mac are still open. The specs are in [docs/specs](docs/specs/README.md).

## What it needs

- macOS 14 or later to run.
- Xcode with Swift 6.2 or later to build.

## Build and test

```
swift build
swift test
scripts/check.sh        # tests, build/OutIP.app signed ad-hoc, and a self-check on sample data
build/OutIP.app/Contents/MacOS/OutIP --probe    # asks every endpoint once and says which answered; prints no address
```

## Install

```
scripts/install.sh
```

It builds `OutIP.app`, signs it ad-hoc, replaces `/Applications/OutIP.app` and opens it. To sign with a certificate from your keychain instead, set `OUTIP_SIGN_IDENTITY` to its name first. OutIP stores one setting, the check interval; `Launch at login` is in its menu.

## Memory

After OutIP has sat idle for 10 minutes:

```
footprint -p "$(pgrep -x OutIP)"
```

The header line gives `Footprint: <n> MB`. The target is under 30 MB.

## What leaves the Mac

One small HTTPS request per check, to a public endpoint run by Cloudflare, ident.me or Amazon. Like any website you open, that endpoint sees your address; that is how it can tell you what it is. OutIP sends nothing else, keeps no history and writes the address to no file.
