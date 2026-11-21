# OutIP

OutIP is a macOS menu bar app that shows the Mac's public IPv4 address and the flag of its country. It asks a public endpoint again every 30 seconds (the menu offers 10 s, 30 s, 1 min and 5 min) and right after the network changes. Limits: Swift and AppKit, no SwiftUI, no third-party packages, HTTPS only, network code in one file.

## Workflow

Spec first, then a fresh session implements it. `docs/specs/README.md` is the contract: read the module's spec, then `docs/specs/CAPABILITY-MAP.md`, then this file.

Subagents save the main context, so delegate research and build steps to them. Run large subagents one at a time, never as a parallel batch.

## Commands

```
swift build
swift test
scripts/check.sh                                      # the gate: rules, tests, ad-hoc bundle, self-check (no prompts, no requests)
scripts/build-app.sh                                  # build/OutIP.app, signed with $OUTIP_SIGN_IDENTITY or ad-hoc
build/OutIP.app/Contents/MacOS/OutIP --self-check     # sample data; needs the logged-in desktop session
build/OutIP.app/Contents/MacOS/OutIP --probe          # asks every endpoint once; prints no address (at most 3 runs a session)
```

`scripts/install.sh` is for a person only. Each module adds its own commands here when it is built.

## Layout

- `OutIPCore` (`Sources/OutIPCore/`): the pure rules (reading an endpoint's reply, the flag, the bar and menu text, the intervals, the delay to the next check). Foundation only.
- `OutIPCoreTests` (`Tests/OutIPCoreTests/`): Swift Testing table tests for those rules.
- `OutIP` (`Sources/OutIP/`): the AppKit shell that asks the endpoints and draws what `OutIPCore` returns. `Support/Info.plist` is its bundle's plist; `scripts/` builds, checks and installs `build/OutIP.app`.

## Conventions

- A rule worth a test is a pure function in `OutIPCore`, with its test in `OutIPCoreTests`.
- Bytes, dates, `calendar` and `locale` are passed in; the library never reads the clock, the calendar, the locale or a preference, and never makes a request.
- Check an API against the installed SDK (`xcrun --show-sdk-path`), or with `ctx7`, before using it from memory.

## Privacy

This repo may become public. Samples are invented: the address `203.0.113.7`, the country `SE`. No real IP address (public or private), no country or provider of a real connection, no home-folder paths, signing identity names, team ids or certificate hashes: not in specs, code, tests, logs, commits or pull requests. OutIP shows the address in the bar and the menu and writes it nowhere else.

## Never, in an automated session

- Start OutIP without `--self-check` or `--probe`: not with `open`, not by running the binary, not with `swift run`.
- Send a network request from a test, a script or `--self-check`. `--probe` is the only unattended request path: at most 3 runs per session.
- Print, log or commit an address or a country that a real request returned.
- Run `scripts/install.sh` or `security`, or sign with anything but `-` (ad-hoc).
- Call `SMAppService` `register()` anywhere but the `Launch at login` menu action.
- Change a system setting: network, proxy, VPN, login items.
- Import SwiftUI, add a package, or add an `NSAppTransportSecurity` key.
