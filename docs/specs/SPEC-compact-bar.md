# Spec: compact-bar

Module 4 in the OutIP capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on `core-rules`, `menubar-app` and `ip-check`. Status: specified, not built.

## Objective

A crowded menu bar has room for a flag but not for `🇸🇪 203.0.113.7`. In flag-only mode the bar shows just `🇸🇪`, about a fifth of the width, and the menu still gives the country and the address. A menu item and ⌥-click switch between the two modes, and the choice survives a relaunch.

### Requirements

**Rule**
- R1. `Display.bar(for:showAddress:)` replaces `Display.bar(for:)` (core-rules R16). With `showAddress` true it returns what R16 returns. With it false, a reading shows the flag alone. The two symbols don't change, because they carry no address.

  | Status | `showAddress` | Bar |
  |---|---|---|
  | `reading`, `SE` | true | `.text("🇸🇪 203.0.113.7")` |
  | `reading`, `SE` | false | `.text("🇸🇪")` |
  | `reading`, no country | false | `.text("🌐")` |
  | `checking` | false | `.symbol("network", "OutIP: checking")` |
  | `noAnswer` | false | `.symbol("network.slash", "OutIP: no answer")` |

**Stored value**
- R2. The mode is a second stored value: a `Bool` under the key `showAddress` in `UserDefaults.standard`. A missing value, or a value that isn't a `Bool`, means true: `object(forKey:) as? Bool ?? true`, not `bool(forKey:)`, which gives false when the value is missing.
- R3. `show(_:)` (menubar-app R9) passes the stored mode to `Display.bar`. Changing the mode redraws the bar with the kept status at once, and starts no check.

**Menu**
- R4. A `Show address in bar` item sits between `Check every` and `Launch at login`. It carries a checkmark when the mode is true. A click stores the opposite value and redraws (R3).

**⌥-click**
- R5. A click on the bar while ⌥ is held switches the mode the way R4 does, and no menu opens. Any other left or right click opens the menu, as it does today.
- R6. How: `statusItem.menu` stays nil. The button's action fires on `[.leftMouseDown, .rightMouseDown]` (`sendAction(on:)`), so the menu still opens on mouse down. The action reads `NSApp.currentEvent?.modifierFlags`. With `.option` held it switches the mode. Otherwise it sets `statusItem.menu = menu`, calls `button.performClick(nil)`, and sets `statusItem.menu = nil` again. If that doesn't open the menu under the button, use `menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)` instead, and write the change into this spec.

**Self-check**
- R7. The self-check uses true without reading `UserDefaults` (menubar-app R22), so the bar line stays `bar: 🇸🇪 203.0.113.7`. `SelfCheck.run` gets the menu as an argument, because `statusItem.menu` is now nil. Its expected output (menubar-app R25) gains one line after `Check every`:

  ```
  menu: Check every > 10 seconds, ✓ 30 seconds, 1 minute, 5 minutes
  menu: ✓ Show address in bar
  menu: Launch at login
  ```

**Out of scope**
- R8. A tooltip with the address in flag-only mode (the user's choice: hover shows nothing), a keyboard shortcut for the mode, and switching to flag-only by itself when the bar is crowded. AppKit gives no signal for a crowded or notch-hidden bar.

## Interface

Changes `core-rules`' public `Display.bar(for:)` to `Display.bar(for:showAddress:)`. No other module reads the mode.

## Project Structure

```
Sources/OutIPCore/Display.swift          bar(for:showAddress:)
Tests/OutIPCoreTests/DisplayTests.swift  the R1 table
Sources/OutIP/AppDelegate.swift          the stored mode, the menu item, the click handling
Sources/OutIP/SelfCheck.swift            takes the menu as an argument
scripts/check.sh                         the expected self-check text
```

## Tech Stack

As in `menubar-app`. No new framework.

## Commands

As in `CLAUDE.md`. Checks (the gate, unattended): `scripts/check.sh`

## Code Style

As in `core-rules` and `menubar-app`.

## Testing Strategy

- R1 is a table test in `DisplayTests.swift`, row for row.
- The self-check covers the menu item and its checkmark (R7).
- Flag-only in the real bar, ⌥-click, the menu opening on a plain click, and the mode surviving a relaunch are manual QA. Each needs the installed app and a mouse.

## Boundaries

- Always: run `scripts/check.sh` before each commit.
- Ask first (in an unattended run, stop and report it): a third stored value; a keyboard shortcut or a global hotkey; any change to the bar's symbols.
- Never: everything under `menubar-app` Boundaries → Never; write `showAddress` from the self-check or a script.

## Success Criteria

Done when: `scripts/check.sh` passes with the R1 tests and the R7 output.

Manual QA (the user, on the installed app after `scripts/install.sh`):

- [ ] Unticking `Show address in bar` leaves only the flag in the bar, and the status item gets narrower.
- [ ] ⌥-click on the bar switches the mode both ways and opens no menu.
- [ ] A plain left click and a right click open the menu under the item, as before.
- [ ] In flag-only mode the menu still shows the country and `Copy <address>`.
- [ ] Flag-only mode is still on after Quit and a relaunch.
- [ ] Without a country the bar shows `🌐`; while checking and after no answer it shows the symbols.

## Open Questions

None.

## Tasks (build order)

- T1. `Display.bar(for:showAddress:)` and the R1 table in `DisplayTests.swift`; update the one caller in `AppDelegate.show` to pass `true`.
  Verify: `swift build && swift test`
- T2. The stored mode (R2, R3), the `Show address in bar` item (R4), ⌥-click (R5, R6), `SelfCheck.run` taking the menu, and the R7 line in `scripts/check.sh`.
  Verify: `scripts/check.sh`
- T3. Docs: core-rules R16 and its Interface take the `showAddress` parameter; menubar-app R4 says two stored values, R10–R17 gain the item and the click handling, and R25 gains the R7 line; the map's shared decision "OutIP stores one value" names both values; `README.md` mentions flag-only mode and ⌥-click in one sentence. Then the spec workflow's step 4: this spec's status line and index row, delete Tasks and the automated Success Criteria.
  Verify: `scripts/check.sh`
