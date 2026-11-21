# Capability Map: OutIP v1

OutIP is a macOS menu bar app for one person on their own Mac. The bar shows the Mac's public IPv4 address and the flag of its country, `🇸🇪 203.0.113.7`, checked again every 30 seconds and right after the network changes. It exists so that a glance tells which country a VPN or a proxy lets the traffic out from. This file is the index of what exists: each module's spec is named by its id and sits beside it.

| Module id | Spec | Responsibility | Depends on |
|---|---|---|---|
| `core-rules` | [SPEC-core-rules.md](SPEC-core-rules.md) | The Swift package and `OutIPCore`, the pure rules: reading an endpoint's reply, the endpoint chain, the flag, the bar's content, the menu's text, the intervals, the delay to the next check | — |
| `menubar-app` | [SPEC-menubar-app.md](SPEC-menubar-app.md) | The AppKit agent app: the bar, the menu, Copy, the interval choice and where it is stored, Launch at login, Quit. Also the bundle, check and install scripts, the self-check and the first memory number | `core-rules` |
| `ip-check` | [SPEC-ip-check.md](SPEC-ip-check.md) | The check itself: asking the chain over a fresh connection, the status it hands to the app, the timer, the triggers (network change, wake, display sleep, Refresh now), and `--probe` | `menubar-app` |

Build order: core-rules → menubar-app → ip-check.

## Success

- A glance at the bar gives the exit country and the public IPv4, at most one interval old.
- After a VPN is switched on or off, the bar is right within 10 s.
- A failed check never leaves an old address on screen.
- Idle memory stays under 30 MB of physical footprint (menubar-app R29).
- At the 30 s default, with the display on all day, OutIP uses under 25 MB of data a day (ip-check manual QA measures it).

## Out of scope

- IPv6: showing an IPv6 address, or noticing traffic that leaves over IPv6 beside a VPN.
- City, provider, AS number, a map.
- A history or a log of readings; a notification when the address or the country changes.
- Split tunnels and rule-based proxies: OutIP reports the route its own request takes, which is the route of ordinary traffic to a foreign website.
- DNS-leak and WebRTC-leak tests.
- Controlling a VPN or a proxy.
- A settings window; choosing or editing endpoints in the app.
- An API key, a bundled IP-to-country database, a server of our own.
- Public release: notarization, the hardened runtime, the sandbox, an updater, CI, an app icon.
- Localization (the UI is English).
- SwiftUI, storyboards, third-party packages.

## Verified on the target Mac (2026-11-21)

Every network check ran through a tunnel VPN, the only state tested. No system proxy was set.

- macOS 27.2.1 on Apple silicon, Xcode 27.2, Swift and SwiftPM 6.4.2. `swiftc` accepts `-default-isolation MainActor`.
- All five URLs of the chain (core-rules R8) answered `curl` with status 200 and one identical IPv4; those that give a country agreed on it. A request took 1.0 to 1.8 s, about 0.9 s of it TLS.
- 36 public endpoints returned that same IPv4, and all 26 that give a country agreed.
- `ipv4.icanhazip.com`, `4.ident.me` and `checkip.amazonaws.com` have A records and no AAAA record.
- The trace reply is 16 `key=value` lines of about 200 bytes with `ip=` and `loc=`. `4.ident.me/json` is one JSON object with `ip` and `cc`. `checkip.amazonaws.com` is the address and a newline.
- `4.ident.me` reset one TLS connection in three tries.
- Error pages arrive as 403 and 429 with an HTML body, and one endpoint outside the chain serves plain text as `text/html`. The value is validated, never the content type.
- `URLSession` loaded `https://ipv4.icanhazip.com/cdn-cgi/trace`, `https://1.1.1.1/cdn-cgi/trace` and `https://1.0.0.1/cdn-cgi/trace` with default trust: the certificate's IP subject alternative name is accepted.
- In a binary with an `Info.plist` embedded, HTTPS to both literals still loaded and cleartext HTTP failed with `-1022`. No `NSAppTransportSecurity` key is needed.
- One shared `URLSession` reused its connection for the second and third request. A new ephemeral session per request never reused one. A fresh request took 1.1 to 1.6 s (2.2 s once), a reused one 0.2 s.
- A session whose proxy dictionary points at a closed loopback port fails in about 10 ms and doesn't fall back to a direct connection: `kCFErrorDomainCFNetwork` 310 for an HTTPS proxy, `NSURLErrorDomain` `-1004` for a SOCKS proxy.
- `NWPathMonitor` delivers the current path as soon as it starts.
- DNS "whoami" queries through the system resolver returned the resolver's address, not the exit address.
- The SF Symbols `network` and `network.slash` exist.
- `Locale(identifier: "en_US").localizedString(forRegionCode:)` gives `Sweden` for `SE`, `Unknown Region` for `ZZ` and `nil` for `QQ`.
- In `en_US` the time with seconds is `12:05:13 PM` with U+202F before `PM`; in `en_GB` it is `12:05:13`.
- A sketch of ip-check's fetcher, timer and triggers compiled in Swift 6 mode with MainActor default isolation, with no warning.
- Seen with a sibling menu bar app on this Mac (2026-11-20): SwiftPM puts products in `.build/out/Products/<Configuration>/`, and `swift build -c release --show-bin-path` prints the folder; a process started from a shell can build an `NSStatusItem` and its `NSMenu`, print them and exit, with no prompt; such an agent idles at 17 to 18 MB; `/Applications` is writable without `sudo`; `/usr/bin/timeout` exists.

## Not verified

| Item | Answered by |
|---|---|
| The chain on a direct connection, with no VPN: which hosts answer. `1.1.1.1` is reported blocked on some networks | ip-check manual QA (`--probe`) |
| `https://4.ident.me/json` and `https://checkip.amazonaws.com/` through `URLSession` (only `curl` was tried) | ip-check Checks (`--probe`) |
| A new connection per check across a real VPN or proxy switch | ip-check manual QA |
| How soon `NWPathMonitor` reports a VPN switching on or off, and whether it reports a change of the system proxy settings | ip-check manual QA |
| The bytes one check costs. The estimate is 5 to 8 KB, which is 15 to 23 MB a day at 30 s | ip-check manual QA |
| App Nap delaying the timer of an agent app | ip-check manual QA |
| A system proxy on a LAN address: macOS should ask for Local Network access (loopback is exempt) | ip-check manual QA, if such a proxy is in use |
| `SMAppService.mainApp` for an ad-hoc signed bundle in `/Applications`, and whether it survives a reinstall | menubar-app manual QA |
| Idle memory with a session created and dropped at every check | ip-check manual QA |
| The flag drawn in colour in the menu bar | menubar-app manual QA |

## Shared decisions (bind every module)

- Swift 6 with the AppKit lifecycle (`NSApplication`, `NSStatusItem`, `NSMenu`): an agent app with no Dock icon. No SwiftUI, no storyboard.
- One SwiftPM package: `OutIPCore` (the rules), `OutIP` (the shell) and `OutIPCoreTests`, with scripts that assemble and sign `OutIP.app`. An agent can build all of it from the command line.
- Every rule worth a test is a pure function in `OutIPCore`. The shell asks, draws and schedules.
- The address and the country come from one reply of one endpoint, so they can't disagree. Values from two endpoints are never mixed in one reading.
- The endpoints are a chain of five HTTPS URLs on three networks (core-rules R8); the first valid answer wins. No API key, no database, no server of our own.
- IPv4 only: every host in the chain is an IPv4 literal or has A records only, so no reply can carry an IPv6 address.
- Every check opens a new connection (a new ephemeral `URLSession`), so the answer reflects the route and the proxy of that moment. A kept connection can outlive a VPN switch and report the old address.
- A reading is on screen only while the last check produced it. A failed check shows the no-answer state.
- Requests follow the system proxy settings (`URLSession`'s default), so OutIP reports what a browser on this Mac would.
- HTTPS only, default certificate trust, no `NSAppTransportSecurity` key. Network code sits in one file, `Sources/OutIP/Checker.swift`.
- OutIP stores one value, the check interval, in its `UserDefaults`.
- The address is personal data: it is shown in the bar and the menu, copied when the user asks, and written nowhere else. No log line, file or script output carries an address or a country from a real request.
- The bundle id is `ir.kaavehdev.outip`. It never changes after the first install, because the login item and the stored interval hang on it.
- Signing is ad-hoc, for the checks and for the install: OutIP holds no permission that a changing signature would lose. `OUTIP_SIGN_IDENTITY` lets a person sign with a keychain identity; no identity name, team id or hash is ever committed.
- No sandbox, no hardened runtime, no notarization: the app is built and installed locally for personal use.
- The gate (`scripts/check.sh`) never prompts and never sends a request: the tests and `OutIP --self-check` run on sample data. `OutIP --probe` is the one unattended network check and stays outside the gate.
- Memory: under 30 MB of physical footprint at idle. A higher measured number is recorded as an open item; the code isn't contorted to reach the target.
- The minimum is macOS 14. Only macOS 27 is tested.
- UI text is English. The clock format follows the system.
- Privacy: samples are invented (`203.0.113.7`, `SE`). No real address, exit country, provider, home-folder path, identity name, team id or hash anywhere in the repo.

## Assumptions (chosen for the user; overrule any before the build)

1. The bundle id is `ir.kaavehdev.outip`. Confirm it before the first install.
2. The app is installed at `/Applications/OutIP.app`, signed ad-hoc (menubar-app R28).
3. The default interval is 30 s, the user's choice for its data cost; the menu offers 10 s, 30 s, 1 min and 5 min (core-rules R19).
4. The time between two checks runs from the end of one to the start of the next, so "30 s" is 30 s plus the 1 to 2 s a check takes (ip-check R6).
5. No check runs while the display sleeps; one runs when it wakes (ip-check R10).
6. A failed check replaces the address with the no-answer symbol at once. Up to 3 retries follow 5 s apart, then the interval applies again (core-rules R22, ip-check R4).
7. After a network change the old reading stays on screen until the new check answers, a few seconds later (ip-check R9).
8. An answer without a country shows 🌐 before the address (core-rules R14).
9. The menu's first block is the country's English name, `Copy <address>`, and the time of the last check with the host that answered (core-rules R17).
10. The chain's order: Cloudflare's trace by name, ident.me, the trace by IPv4 literal, Amazon last and without a country (core-rules R8).
11. A check gives up on an endpoint after 3 s and ends within 9.5 s (core-rules R23).

## Open Questions

| Owner | Item |
|---|---|
| User | With the VPN off, which chain hosts answer (`OutIP --probe`)? If the first one doesn't, the chain's order changes |
| User | `4.ident.me` is run by one person and reset one connection in three. Keep it second, or move the literals up? |
| User | Is 🌐 the right sign for "no country"? |
| User | If one check measures above 8 KB: keep 30 s as the default, or raise it? |
| User | If Launch at login doesn't survive a reinstall of the ad-hoc build: sign with a keychain identity, or accept ticking it again? |
