# Spec: ip-check

Module 3 of 3 in the OutIP capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on `menubar-app`. Status: specified, not built.

## Objective

The check itself. OutIP asks the endpoint chain for the Mac's public IPv4 and its country over a connection opened for that one check, hands the result to the app as a `Status`, and decides when to ask again: after the interval, right after the network changes or the Mac wakes, and on `Refresh now`. No check runs while the display sleeps. `OutIP --probe` asks every endpoint once from the command line, so an unattended session can see the real path work without showing an address.

Every rule here that can be a pure function already is one in `core-rules` (`Lookup`, `Schedule`). This module is the I/O around them.

### Requirements

**Where the code lives**
- R1. All of it is in `Sources/OutIP/Checker.swift`, plus its wiring in the delegate and `main.swift`. `URLSession`, `import Network` and `NWPathMonitor` appear in no other file; the gate enforces it (menubar-app R27).

**One check**
- R2. A check builds a new `URLSession` from `URLSessionConfiguration.ephemeral` and calls `invalidateAndCancel()` on it when the check ends, whatever the outcome: a session that is never invalidated leaks. The configuration:

  | Property | Value |
  |---|---|
  | `timeoutIntervalForRequest`, `timeoutIntervalForResource` | `Schedule.attemptTimeout` |
  | `requestCachePolicy` | `.reloadIgnoringLocalCacheData` |
  | `urlCache`, `httpCookieStorage` | `nil` |
  | `connectionProxyDictionary` | untouched, so the system proxy settings apply |

- R3. The check walks `Lookup.chain` in order with a GET. An attempt succeeds when the status code is 200 and `Lookup.parse` returns a reading; the first success ends the check. No attempt starts later than `Schedule.lastAttemptStart` after the check began, and a cancelled check starts none.
- R4. A check ends in `show(.reading(reading, at: Date()))` or `show(.noAnswer(at: Date()))` (menubar-app R9). After a failed check the old reading is gone from the bar.
- R5. Nothing about a check is logged: not the address, not the country, not the error. A failed check is an ordinary state, and the bar shows it.

**When**
- R6. One check runs at a time. When a check ends, the next is set for `Schedule.delay(interval:failures:afterTrigger:)` later, on a one-shot `Timer` in `.common` run-loop modes with a tolerance of a tenth of the delay. `interval` is the stored one (menubar-app R4).
- R7. `failures` counts the failed checks in a row and returns to 0 with a reading.
- R8. A trigger starts a check now. It replaces the pending timer and a running check, whose answer is dropped, since it may describe the old route. The triggers:

  | Trigger | Debounced | `afterTrigger` |
  |---|---|---|
  | launch | no | no |
  | `Refresh now` (menubar-app R14) | no | no |
  | a path update from `NWPathMonitor`, the first one after it starts left out (it is the current path) | yes | yes |
  | `NSWorkspace.didWakeNotification` | yes | yes |
  | `NSWorkspace.screensDidWakeNotification` | yes | yes |

- R9. The debounced triggers share one wait: the check starts `Schedule.debounce` after the latest of them, so the burst of updates a VPN sends while it connects becomes one check. Until that check answers, the old reading stays on screen.
- R10. After `NSWorkspace.screensDidSleepNotification` the pending timer is cancelled, and nothing starts a check, no trigger either, until `screensDidWakeNotification`. A check that is running may finish. Nobody reads the bar with the display off, and each check costs data.
- R11. A click on an interval (menubar-app R15) replaces the pending timer with one of the new interval. A running check is left alone.

**Probe**
- R12. `OutIP --probe` builds no status item and needs no bundle. It asks every endpoint of the chain once, each through its own session of R2, without stopping at the first answer, and prints one line per endpoint to stdout:
  - `<host>: ok <seconds> s`, as `ipv4.icanhazip.com: ok 1.2 s`;
  - `<host>: failed (<reason>) <seconds> s`, where the reason is `timeout`, `http <status>`, `parse`, or the error's domain and code.
- R13. Its last line is `agree: yes` when every reading has the same address and those with a country have the same one, `agree: no` when they differ, and `agree: n/a` with fewer than two readings. It exits with 0 when at least one endpoint answered, and with 1 otherwise.
- R14. It never prints an address or a country.

## Interface

Consumed from `core-rules`: `Lookup.chain`, `Lookup.parse`, `Schedule`, `Status` and `Reading`. Consumed from `menubar-app`: `show(_:)`, the `Refresh now` item, the stored interval and the click that changes it, `main.swift`. Read the signatures from the code.

Provided: nothing. This is the last module.

## Project Structure

```
Sources/OutIP/Checker.swift            the session, the chain walk, the timer, the triggers, the probe
Sources/OutIP/AppDelegate.swift        + owning the checker, Refresh now, the interval change
Sources/OutIP/main.swift               + --probe
```

## Tech Stack

As in `menubar-app`, plus `URLSession` (Foundation) and `NWPathMonitor` (Network). No dependencies.

## Commands

```
build/OutIP.app/Contents/MacOS/OutIP --probe     # asks every endpoint once; prints no address
```

Checks (unattended): `scripts/check.sh`, then `scripts/build-app.sh && timeout 60 build/OutIP.app/Contents/MacOS/OutIP --probe`. The probe depends on the network, so it isn't part of the gate. A probe that fails because the session's network is down or filtered is reported with its output, not worked around.

## Code Style

As in `menubar-app`, with four notes that the installed SDK confirmed in a sketch:

- The request runs off the main actor in a `nonisolated` async function that returns a `Reading?`. Everything else in the checker is main-actor code.
- `NWPathMonitor` is read as an `AsyncSequence` from a main-actor `Task` (`for await _ in NWPathMonitor().dropFirst()`), so its updates arrive on the main actor with no queue to pick.
- A replaced check is told apart by a generation number: a check that finds a newer generation drops its answer.
- `session.data(from:)` with `try?` is enough: every failure means the next endpoint.

```swift
nonisolated static func ask() async -> Reading? {
    let config = URLSessionConfiguration.ephemeral       // a new session: a new connection, this moment's route and proxy
    config.timeoutIntervalForRequest = Schedule.attemptTimeout
    config.timeoutIntervalForResource = Schedule.attemptTimeout
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.urlCache = nil
    config.httpCookieStorage = nil
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    let clock = ContinuousClock(), lastStart = clock.now + .seconds(Schedule.lastAttemptStart)
    for endpoint in Lookup.chain where clock.now < lastStart && !Task.isCancelled {
        if let (body, response) = try? await session.data(from: endpoint.url),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let reading = Lookup.parse(body, from: endpoint) { return reading }
    }
    return nil
}
```

## Testing Strategy

- The rules are tested in `OutIPCoreTests`. The checker adds none.
- The gate stays offline: the tests and the self-check send nothing, and the self-check never creates the checker.
- `--probe` is the checker's automated check: the real sessions, the real chain and the real parsers on live replies, with no address in its output.
- Whatever needs a VPN or a proxy switched, another network, the display asleep or a pair of eyes is the manual QA list below.

## Boundaries

- Always: keep rules in `OutIPCore`; keep network code in `Sources/OutIP/Checker.swift`; run `scripts/check.sh` before each commit; check an API against the installed SDK, or with `ctx7`, before using it from memory.
- Ask first (in an unattended run, stop and report it): a change to the chain or to the constants of core-rules R23; another trigger, such as the `SCDynamicStore` proxies key; `ProcessInfo.beginActivity`; an `Info.plist` key; logging of any kind; anything that stores data.
- Never:
  - start OutIP without `--self-check` or `--probe` in an automated session;
  - send a request from a test, a script or the self-check, or run `--probe` more than 3 times in a session;
  - print, log or commit an address or a country that a real request returned;
  - keep a session from one check to the next;
  - add an `NSAppTransportSecurity` key or an `http://` URL;
  - change a system setting, or switch a VPN or a proxy on or off.

## Success Criteria

Done when: `scripts/check.sh` passes, `--probe` has run once with its output in the pull request's text, and the manual QA list stays open.

Automated (the Checks cover them):

- [ ] `scripts/check.sh` exits with 0 and prints `check: OK`, with the self-check's output unchanged.
- [ ] `OutIP --probe` prints one line per endpoint and an `agree:` line, and no address or country.
- [ ] `URLSession`, `import Network` and `NWPathMonitor` appear only in `Sources/OutIP/Checker.swift`.

Manual QA (the user, on the installed app; stays open after the build):

- [ ] First launch: the flag and the address show within 5 s, and macOS asks for nothing.
- [ ] VPN on, then off, then on: each time the bar is right within 10 s.
- [ ] The VPN's server or location switched: the bar is right within one interval.
- [ ] A proxy tool in system-proxy mode, if one is used: switching it on and off changes the bar. Note whether that takes until the next tick.
- [ ] Network off (Wi-Fi off or the cable out): the `network.slash` symbol within 15 s. Network back: the reading returns within 10 s.
- [ ] With the VPN off, `build/OutIP.app/Contents/MacOS/OutIP --probe`: note which hosts answer.
- [ ] Each interval: the time in the menu moves at that pace.
- [ ] The display asleep for 5 minutes, then awake: the time in the menu is from after the wake.
- [ ] Data: `nettop -P -x -L 1 -p "$(pgrep -x OutIP)"` before and after ten checks. Note bytes in plus bytes out per check; the estimate is 5 to 8 KB.
- [ ] Memory: `footprint -p "$(pgrep -x OutIP)"` after 10 minutes and after 60. Note both; they should be within 2 MB of each other.
- [ ] Left running for a working day, OutIP never shows an address that a browser's IP-check page contradicts.

## Open Questions

| Owner | Item |
|---|---|
| User | With the VPN off, which hosts answer? If `ipv4.icanhazip.com` doesn't, the chain is reordered in core-rules R8 |
| User | If switching the system proxy isn't noticed until the next tick: add the `SCDynamicStore` proxies key as a trigger, or accept the wait |
| User | If one check costs more than 8 KB: accept it, or raise the default interval |
| Later | Keeping the reading on screen, dimmed, through one failed check, if the no-answer symbol flickers on a slow connection |
| Later | `NSLocalNetworkUsageDescription`, if a system proxy on a LAN address makes macOS ask for Local Network access |

## Tasks (build order)

- [ ] T1. One check: `Checker` with the session of R2 and the chain walk of R3, run once at launch and ending in `show` (R1–R5). The self-check doesn't create it. Verify: `scripts/check.sh`.
- [ ] T2. `--probe` (R12–R14); the bundle guard lets it through (menubar-app R5). Verify: `scripts/check.sh && timeout 60 build/OutIP.app/Contents/MacOS/OutIP --probe`.
- [ ] T3. The timer: the delay after each check, `failures`, `Refresh now`, the interval change (R6, R7, R11, and the first two rows of R8). Verify: `scripts/check.sh`.
- [ ] T4. Triggers: the path monitor, wake, the shared debounce, display sleep (the other rows of R8, R9, R10). Verify: `scripts/check.sh`.
- [ ] T5. Docs and spec workflow: add `--probe` to the commands in `CLAUDE.md` and set the status line in `README.md` to built; delete this section and the automated Success Criteria; set the status line and the row in `docs/specs/README.md` to built with manual QA open; put the probe's output in the pull request. Verify: `scripts/check.sh`.
