# OutIP

OutIP is a macOS menu bar app that shows your public IPv4 address and the flag of the country it belongs to: `🇸🇪 203.0.113.7`. It checks again every 30 seconds, or at a pace you pick, and right after the network changes, so a glance tells you where a VPN or a proxy lets your traffic out.

Status: specified, not built yet. The specs are in [docs/specs](docs/specs/README.md).

## What it needs

- macOS 14 or later to run.
- Xcode with Swift 6.2 or later to build.

## Build and test

```
swift build
swift test
```

## What leaves the Mac

One small HTTPS request per check, to a public endpoint run by Cloudflare, ident.me or Amazon. Like any website you open, that endpoint sees your address; that is how it can tell you what it is. OutIP sends nothing else, keeps no history and writes the address to no file.
