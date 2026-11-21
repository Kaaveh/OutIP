# Spec: menubar-app

Module 2 of 3 in the OutIP capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on `core-rules`. Status: built; manual QA open.

## Objective

OutIP runs in the menu bar with no Dock icon. The bar shows `🇸🇪 203.0.113.7`. A click shows the country's name, Copy, and when the address was last checked and by which host, then Refresh now, the interval choice, Launch at login and Quit. This module also makes the app buildable, checkable and installable from the command line, and takes the first memory number.

The shell is thin: it keeps one `Status`, hands it to `OutIPCore`, and draws what comes back. In this module the status is the sample of the self-check, or `checking` in normal mode. The check that fills it arrives with `ip-check`.

### Requirements

**App**
- R1. An executable target `OutIP` in the package, depending on `OutIPCore`. AppKit lifecycle in `main.swift`: `NSApplication.shared`, a delegate, `setActivationPolicy(.accessory)`, `run()`. No storyboard, no nib, no SwiftUI.
- R2. The target sets `.defaultIsolation(MainActor.self)`: the whole shell is main-thread code.
- R3. This module uses AppKit and ServiceManagement, and has no network code.
- R4. OutIP stores two values in `UserDefaults.standard`. The interval in whole seconds, under the key `interval`, is read through `Interval.resolve`, so a missing or foreign value means 30. Whether the bar shows the address is a `Bool` under `showAddress`; a missing or foreign value means true (compact-bar R2).
- R5. Normal mode needs the app bundle. When `Bundle.main.bundleIdentifier` is `nil` (as under `swift run`) and no mode flag is given (`--self-check` here, `--probe` with `ip-check`), the process prints one line to stderr and exits with status 64. Outside the bundle the login item and the stored interval would hang on the wrong identity.

**Bundle**
- R6. `Support/Info.plist`, with no usage description and no `NSAppTransportSecurity` key:

  | Key | Value |
  |---|---|
  | `CFBundleIdentifier` | `ir.kaavehdev.outip` |
  | `CFBundleName`, `CFBundleExecutable` | `OutIP` |
  | `CFBundlePackageType` | `APPL` |
  | `CFBundleShortVersionString`, `CFBundleVersion` | `1.0.0`, `1` |
  | `CFBundleInfoDictionaryVersion` | `6.0` |
  | `LSMinimumSystemVersion` | `14.0` |
  | `LSUIElement` | `true` |

- R7. `scripts/build-app.sh`:
  1. `swift build -c release`;
  2. the product folder is what `swift build -c release --show-bin-path` prints, and no path under `.build` is written into the script;
  3. a fresh `build/OutIP.app` with `Contents/MacOS/OutIP` (the product) and `Contents/Info.plist` (a copy of `Support/Info.plist`);
  4. `codesign --force --sign "${OUTIP_SIGN_IDENTITY:--}" build/OutIP.app`, where `-` signs ad-hoc, then `codesign --verify --strict build/OutIP.app`;
  5. it prints nothing about the identity.
- R8. No sandbox, no hardened runtime, no entitlements file: each exists for distribution and would add entitlements to maintain.

**Status**
- R9. The delegate keeps one `Status`, `checking` at launch, and one method `show(_:)` that stores a new status and draws the bar. Nothing else changes the bar.

**Bar**
- R10. One `NSStatusItem` of variable length. Its `menu` stays nil; the button's action fires on left and right mouse down and opens the menu under the item, or with ⌥ held switches the address mode (compact-bar R5, R6).
- R11. `Display.bar`, given the stored address mode, decides what it shows. A text becomes the button's title, with no image. A symbol becomes a template image from `NSImage(systemSymbolName:accessibilityDescription:)` with the given description, and the title is empty.

**Menu**
- R12. The menu is rebuilt in `menuNeedsUpdate` from the kept status. Opening it starts no check. Its `autoenablesItems` is `false`.
- R13. The first block comes from `Display.info`: the header as `NSMenuItem.sectionHeader(title:)`; then, when there is a `copyTitle`, an item with that title that makes `address` the only content of `NSPasteboard.general`; then, when there is a `detail`, a disabled item with that text.
- R14. Then a separator and `Refresh now` (key equivalent `r`). Its action is wired by `ip-check`; in this module a click does nothing.
- R15. `Check every`, with a submenu of one item per value in `Interval.options`, titled by `Interval.title`. The stored interval (R4) carries a checkmark. A click stores that value.
- R16. `Show address in bar`, checked when the address mode is true; a click switches it and redraws the bar (compact-bar R3, R4). Then `Launch at login` (R18–R19).
- R17. The menu ends with a separator and `Quit OutIP` (key equivalent `q`).

**Launch at login**
- R18. `Launch at login` carries a checkmark when `SMAppService.mainApp.status == .enabled`, read each time the menu opens.
- R19. A click calls `unregister()` when enabled and `register()` otherwise. If the status is `.requiresApproval` afterwards, it calls `SMAppService.openSystemSettingsLoginItems()`. An error is logged with `NSLog` and changes nothing else.

**Self-check**
- R20. `OutIP --self-check` runs the same status item and menu code as normal mode. Five things differ: the status is the sample of R21, the calendar is Gregorian in GMT, the locale is `en_US`, the interval is 30 and the address shows, both without `UserDefaults` being read.
- R21. The sample is a reading with the address `203.0.113.7`, the country `SE` and the source `ipv4.icanhazip.com`, arrived at 2026-11-21 12:05:13 GMT.
- R22. It calls no `URLSession`, no `Network`, no ServiceManagement, no `NSPasteboard` and no `UserDefaults`, so it can't raise a prompt, send a request or change anything on the Mac. This outranks R20: `Launch at login` is drawn unchecked.
- R23. It first checks that both symbols of core-rules R16 resolve. A missing one prints `self-check: missing symbol <name>` to stderr and exits with status 1.
- R24. It prints to stdout:
  - `bar: ` and the button's title, trimmed;
  - one `menu: ` line per menu item, top to bottom: `# <title>` for a section header, `---` for a separator, otherwise the title, with `✓ ` before it when the item is checked, followed by ` > ` and the submenu's titles (comma-separated, each with its own `✓ ` when checked) when the item has a submenu;
  - U+202F as a plain space, so the expected text can be typed.
- R25. Expected output:

  ```
  bar: 🇸🇪 203.0.113.7
  menu: # Sweden
  menu: Copy 203.0.113.7
  menu: 12:05:13 PM · ipv4.icanhazip.com
  menu: ---
  menu: Refresh now
  menu: Check every > 10 seconds, ✓ 30 seconds, 1 minute, 5 minutes
  menu: ✓ Show address in bar
  menu: Launch at login
  menu: ---
  menu: Quit OutIP
  ```

- R26. Then it keeps the status item on screen for 5 s, prints `footprint: <n> MB` (its own physical footprint in MB with one decimal, from `proc_pid_rusage`'s `ri_phys_footprint`), and exits with status 0.

**Scripts**
- R27. `scripts/check.sh` is the gate, written for the system's bash 3.2. It sends no request. In order:
  1. fail if `Sources/OutIPCore` imports anything but Foundation;
  2. fail if `Sources` contains `import SwiftUI`; fail if `URLSession`, `import Network` or `NWPathMonitor` appears in `Sources` outside `Sources/OutIP/Checker.swift`; fail if `Sources` contains `http://`;
  3. `swift test`;
  4. `OUTIP_SIGN_IDENTITY=- scripts/build-app.sh`: always ad-hoc, whatever the environment holds, so no keychain is touched;
  5. on `build/OutIP.app`: `plutil -lint` on its `Info.plist`; `codesign --verify --strict`; `LSUIElement` is `true`; `CFBundleIdentifier` is `ir.kaavehdev.outip`; there is no `NSAppTransportSecurity` key;
  6. `timeout 30 build/OutIP.app/Contents/MacOS/OutIP --self-check` exits with 0, its output without the last line equals R25, and the last line matches `^footprint: [0-9]+\.[0-9] MB$`;
  7. print the footprint line and `check: OK`.
- R28. `scripts/install.sh` is for a person, never for automation:
  1. the identity is `$OUTIP_SIGN_IDENTITY` when set, and `-` otherwise; the keychain is never searched;
  2. `scripts/build-app.sh` with that identity;
  3. quit a running OutIP (`pkill -x OutIP`, where no match is fine), replace `/Applications/OutIP.app` with the new bundle (`ditto`), and `open` it;
  4. print `signed with: ad-hoc` or `signed with: a keychain identity`, never a name or a hash.

**Memory**
- R29. Target: a physical footprint under 30 MB at idle. It is measured on the installed app, after 10 idle minutes, with `footprint -p "$(pgrep -x OutIP)"`; the header line of its output holds `Footprint: <n> MB`.
- R30. The self-check's number (R26) is the floor with no check running. It goes into the pull request's text. A number of 30 MB or more, from either measurement, is recorded as an open item in the pull request and in this spec's Open Questions. The code isn't restructured to chase the target.

## Interface

Consumed from `core-rules`: `Status`, `Reading`, `Display.bar`, `Display.info`, `BarContent`, `MenuInfo` and `Interval`. Read the signatures from the code.

Provided to `ip-check`:

- `show(_:)` (R9), the only way to change the bar;
- the `Refresh now` item (R14), whose action that module wires;
- the stored interval (R4) and the click that changes it (R15), where that module reschedules;
- `main.swift`, where that module adds `--probe` beside `--self-check`;
- `--self-check`, which must stay free of requests and of every system service;
- `scripts/check.sh`, whose rule 2 names `Sources/OutIP/Checker.swift`.

## Project Structure

```
Package.swift                          + the executable target OutIP
Sources/OutIP/main.swift               the bundle guard, NSApplication, the delegate
Sources/OutIP/AppDelegate.swift        status item, menu, Copy, the interval, the address mode, Launch at login
Sources/OutIP/SelfCheck.swift          the sample, the printed lines, the footprint
Support/Info.plist
scripts/build-app.sh                   release build → build/OutIP.app, signed
scripts/check.sh                       the gate
scripts/install.sh                     for a person: /Applications, open
build/                                 output, ignored by git
```

## Tech Stack

Swift 6, AppKit, ServiceManagement, on top of `OutIPCore`. Shell scripts for bash 3.2, with `codesign`, `plutil`, `PlistBuddy`, `ditto` and `timeout` from macOS. No dependencies.

## Commands

```
scripts/check.sh                                      # the gate: rules, bundle, self-check (ad-hoc, no prompts, no requests)
scripts/build-app.sh                                  # build/OutIP.app, signed with $OUTIP_SIGN_IDENTITY or ad-hoc
build/OutIP.app/Contents/MacOS/OutIP --self-check     # sample data; needs the logged-in desktop session
scripts/install.sh                                    # a person only: /Applications/OutIP.app, open
footprint -p "$(pgrep -x OutIP)"                      # idle memory of the installed app
```

Checks (the gate, unattended): `scripts/check.sh`

## Code Style

As in `core-rules`. The shell is main-actor code. A callback that AppKit or Foundation delivers on the main thread (a timer, an observer with `queue: .main`) enters the main actor explicitly:

```swift
center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
    MainActor.assumeIsolated { self?.refresh() }
}
```

The two modes differ only in where the status, the calendar, the locale and the interval come from. Everything after that is the same code.

Every script is executable, starts with `#!/bin/bash` and `set -euo pipefail`, and changes to the repo root first, so it runs from any folder.

## Testing Strategy

- The rules are tested in `OutIPCoreTests`. The shell adds none, so it has no unit tests.
- The self-check is the shell's automated test: a real `NSStatusItem` and `NSMenu`, the sample, exact expected text. It needs the logged-in desktop session, because it builds a real status item.
- Whatever needs the login item, the clipboard, a signing key or a pair of eyes is the manual QA list below.

## Boundaries

- Always: keep rules in `OutIPCore` (a new rule is a new pure function with a test, or it is out of scope); run `scripts/check.sh` before each commit; check an API against the installed SDK, or with `ctx7`, before using it from memory.
- Ask first (in an unattended run, stop and report it): a dependency; an entitlement, the sandbox or the hardened runtime; a change to the bundle id; a new public name in `OutIPCore`; a second stored value; an `Info.plist` key outside R6; a self-check that can't reach the window server.
- Never:
  - start OutIP without `--self-check` in an automated session: not with `open`, not by running the binary, not with `swift run`;
  - run `scripts/install.sh` or `security`, or sign with anything but `-`;
  - call `register()` anywhere but the menu action;
  - import SwiftUI, or add network code in this module;
  - write to the clipboard or to `UserDefaults` from the self-check or a script;
  - log an address, or commit identity names, team ids or hashes.

## Success Criteria

Done when: `scripts/check.sh` passes and the self-check's footprint is in the pull request's text; the bar, the menu, the stored interval, Launch at login and the install script are built; the manual QA list stays open.

Manual QA (the user, on the installed app; stays open after the build). Run `scripts/install.sh` yourself, once `ip-check` is built too: before that the bar shows only the `network` symbol.

- [ ] `scripts/install.sh` puts OutIP in `/Applications` and starts it, and macOS asks for nothing.
- [ ] The flag is drawn in colour in the bar, with the address beside it.
- [ ] `Copy <address>` puts the address on the clipboard.
- [ ] `Check every`: the checkmark moves to the chosen item, and is still there after Quit and a relaunch.
- [ ] `Launch at login`: ticking it adds OutIP to System Settings → General → Login Items, and OutIP is running after the next login. Unticking removes it. Note whether it survives a second `scripts/install.sh`.
- [ ] `footprint -p "$(pgrep -x OutIP)"` after 10 idle minutes: note the number. The target is under 30 MB.

## Open Questions

| Owner | Item |
|---|---|
| User | If `Launch at login` fails, or doesn't survive a reinstall of the ad-hoc build: sign with a keychain identity (`OUTIP_SIGN_IDENTITY`), or accept ticking it again |
