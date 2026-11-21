# Spec: core-rules

Module 1 of 3 in the OutIP capability map ([CAPABILITY-MAP.md](CAPABILITY-MAP.md)). It depends on nothing. Status: built.

## Objective

Every rule OutIP shows or acts on is a pure function in one small library, tested with no network and no screen: turning an endpoint's reply into a reading, the chain of endpoints, the flag, the bar's content, the menu's text, the intervals on offer, and the delay to the next check. This module also creates the Swift package; the repo's `CLAUDE.md`, `README.md` and `.gitignore` exist already. The app (`menubar-app`, `ip-check`) asks the endpoints and draws what these functions return, and adds no rule of its own.

### Requirements

**Package**
- R1. A SwiftPM package named `OutIP`: `swift-tools-version: 6.2`, Swift 6 language mode, `platforms: [.macOS(.v14)]`, no dependencies.
- R2. Two targets: the library `OutIPCore` and its tests `OutIPCoreTests`. The executable target arrives with `menubar-app`.
- R3. `OutIPCore` imports Foundation only.
- R4. The library never reads the clock, the calendar, the locale or a preference itself, and never makes a request. Callers pass bytes, dates, `calendar` and `locale`, so every rule runs on fixed values in a test.

**Reading**
- R5. `Reading` is a value with `address` (an IPv4 address as text), `countryCode` (two capital letters, or `nil`) and `source` (the host that answered).
- R6. An address is valid when it is exactly four numbers joined by dots, each written in 1 to 3 ASCII digits with no leading zero (a lone `0` is fine) and no greater than 255. Nothing else may be in the text: no sign, no space, no port.

  | Text | Valid |
  |---|---|
  | `203.0.113.7`, `0.0.0.0`, `255.255.255.255` | yes |
  | `256.0.113.7`, `203.0.113`, `203.0.113.7.1`, `203.0.113.`, `.203.0.113.7` | no |
  | `203.0.113.07`, `203.0.113.+7`, `203.0.113.7` with a space after it, `203.0.113.7:443` | no |
  | `٢٠٣.0.113.7` (digits that aren't ASCII), `2001:db8::7`, the empty string | no |

- R7. A country code is kept when it is exactly two ASCII letters, in either case, and isn't `XX`, which Cloudflare sends for "unknown". It is stored in capitals. Anything else gives `nil`: `T1` (Cloudflare's code for Tor), a longer text, a missing value. A reading without a country is still a reading.

  | Value | `countryCode` |
  |---|---|
  | `SE`, `se` | `SE` |
  | `XX`, `xx`, `T1`, `SWE`, `S`, `5E`, the empty string, missing | `nil` |

**Endpoints**
- R8. An `Endpoint` is a `url` and a `format`. `Lookup.chain` holds these five, in this order:

  | # | URL | Format | Network |
  |---|---|---|---|
  | 1 | `https://ipv4.icanhazip.com/cdn-cgi/trace` | `trace` | Cloudflare |
  | 2 | `https://4.ident.me/json` | `identJSON` | Hetzner |
  | 3 | `https://1.1.1.1/cdn-cgi/trace` | `trace` | Cloudflare |
  | 4 | `https://1.0.0.1/cdn-cgi/trace` | `trace` | Cloudflare |
  | 5 | `https://checkip.amazonaws.com/` | `plainAddress` | Amazon |

  The name comes before the literals because a rule-based proxy routes by name. The literals need no DNS. The last one gives no country and is there so that an address still shows.
- R9. `Lookup.parse(_:from:)` turns a reply's body into a `Reading`, or `nil`. For every format: a body over 4096 bytes is `nil` (the largest real reply is about 300 bytes, and an error page is larger); a body that isn't UTF-8 is `nil`; the address must pass R6; the country goes through R7; `source` is the host of the endpoint's URL.
- R10. `trace`: the body is lines of `key=value`, split at `\n`, with a `\r` at a line's end dropped. The first line that starts with `ip=` gives the address and is required. The first line that starts with `loc=` gives the country and may be missing. Fixture (invented values; the keys and their order as served):

  ```
  fl=29f123
  h=ipv4.icanhazip.com
  ip=203.0.113.7
  ts=1795219200.123
  visit_scheme=https
  uag=ExampleApp/1.0
  colo=ARN
  sliver=none
  http=http/2
  loc=SE
  tls=TLSv1.3
  sni=plaintext
  warp=off
  gateway=off
  rbi=off
  kex=X25519
  ```

- R11. `identJSON`: the body is one JSON object. Its `ip`, a string, is the address and is required. Its `cc`, a string, is the country and may be missing. Fixture:

  ```json
  {"ip":"203.0.113.7","aso":"Example Hosting AB","asn":64500,"type":"hosting","continent":"EU","cc":"SE","country":"Sweden","city":"Stockholm","postal":"111 20","latitude":59.33,"longitude":18.07,"tz":"Europe/Stockholm","weather":"SEXX0001"}
  ```

- R12. `plainAddress`: the body, with whitespace and newlines trimmed from its ends, is the address. There is no country. Fixture: `203.0.113.7` and a newline.
- R13. Cases. A reading is written as its address and its country:

  | Format | Body | Result |
  |---|---|---|
  | `trace` | the fixture of R10 | `203.0.113.7`, `SE` |
  | `trace` | the fixture with `\r\n` line ends | `203.0.113.7`, `SE` |
  | `trace` | the fixture with `loc=XX`; with `loc=T1`; without its `loc=` line | `203.0.113.7`, `nil` |
  | `trace` | the fixture with `ip=2001:db8::7`; without its `ip=` line | `nil` |
  | `trace` | `<html><body>Access denied</body></html>` | `nil` |
  | `identJSON` | the fixture of R11 | `203.0.113.7`, `SE` |
  | `identJSON` | `{"ip":"203.0.113.7","cc":"se"}` | `203.0.113.7`, `SE` |
  | `identJSON` | `{"ip":"203.0.113.7"}` | `203.0.113.7`, `nil` |
  | `identJSON` | `{"ip":3405803783,"cc":"SE"}`; `["203.0.113.7"]`; `<html>` | `nil` |
  | `plainAddress` | `203.0.113.7` and a newline | `203.0.113.7`, `nil` |
  | `plainAddress` | `203.0.113.7 extra`; `<html>`; the empty body | `nil` |
  | each of the three | its fixture padded with spaces at the end to 4097 bytes | `nil` |
  | each of the three | the two bytes `0xFF 0xFE` | `nil` |

**Flag**
- R14. `Display.flag(for:)` builds the flag from the code's two letters as Unicode regional indicators: each letter becomes the scalar U+1F1E6 plus its distance from `A`. No table and no image. Without a code it returns `🌐` (U+1F310).

  | Code | Flag |
  |---|---|
  | `SE` | `🇸🇪` (U+1F1F8 U+1F1EA) |
  | `JP` | `🇯🇵` (U+1F1EF U+1F1F5) |
  | `nil` | `🌐` |

**Status and bar**
- R15. `Status` is what the app knows right now: `checking` (no check has finished since launch), `reading` with a `Reading` and the time it arrived, or `noAnswer` with the time the check ended.
- R16. `Display.bar(for:showAddress:)`, with `showAddress` true:

  | Status | Bar |
  |---|---|
  | `reading` with a country | the text `<flag> <address>`, one space between: `🇸🇪 203.0.113.7` |
  | `reading` without a country | the text `🌐 203.0.113.7` |
  | `checking` | the SF Symbol `network`, described as `OutIP: checking` |
  | `noAnswer` | the SF Symbol `network.slash`, described as `OutIP: no answer` |

  With `showAddress` false, a reading shows the flag alone, `🇸🇪` or `🌐`, and the symbols don't change (compact-bar R1).

**Menu text**
- R17. `Display.info(for:calendar:locale:)` returns the text of the menu's first block:

  | Status | `header` | `copyTitle` | `detail` |
  |---|---|---|---|
  | `reading`, `SE`, from `ipv4.icanhazip.com` | `Sweden` | `Copy 203.0.113.7` | `12:05:13 PM · ipv4.icanhazip.com` |
  | `reading`, no country, from `checkip.amazonaws.com` | `Unknown country` | `Copy 203.0.113.7` | `12:05:13 PM · checkip.amazonaws.com` |
  | `reading`, `QQ`, from `4.ident.me` | `Unknown country` | `Copy 203.0.113.7` | `12:05:13 PM · 4.ident.me` |
  | `noAnswer` | `No answer` | `nil` | `Tried 12:05:13 PM` |
  | `checking` | `Checking…` | `nil` | `nil` |

  The country's name is `locale.localizedString(forRegionCode:)`; when that returns `nil`, as it does for `QQ`, the header is `Unknown country`. `address` is the reading's address, for Copy, and `nil` in the other two states. The separator is a space, U+00B7 and a space.
- R18. The time is the locale's time with seconds, in the calendar's time zone: `12:05:13 PM` in `en_US`, `12:05:13` in `en_GB`.

**Interval**
- R19. `Interval.options` is 10, 30, 60 and 300 seconds, in that order. `Interval.fallback` is 30.
- R20. `Interval.title(for:)`: `10 seconds`, `30 seconds`, `1 minute`, `5 minutes`.
- R21. `Interval.resolve(_:)` returns the stored value when it is one of the options, and 30 otherwise: a missing value, `0`, `45` and `-5` all give 30.

**Schedule**
- R22. `Schedule.delay(interval:failures:afterTrigger:)` is the time in seconds from the end of one check to the start of the next. `failures` counts the failed checks in a row, the one that just ended included. `afterTrigger` says that the check that just ended was started by a network change or a wake.
  - With `failures` from 1 to 3: `min(interval, 5)`. A blip is retried soon, whatever the interval.
  - Otherwise, with `afterTrigger`: `min(interval, 5)`. The signal can arrive before the new route carries traffic, so one more check confirms the answer.
  - Otherwise: `interval`.

  | `interval` | `failures` | `afterTrigger` | Delay |
  |---|---|---|---|
  | 30 | 0 | no | 30 |
  | 30 | 1 | no | 5 |
  | 30 | 3 | no | 5 |
  | 30 | 4 | no | 30 |
  | 30 | 0 | yes | 5 |
  | 30 | 4 | yes | 5 |
  | 300 | 0 | no | 300 |
  | 300 | 2 | yes | 5 |
  | 10 | 0 | yes | 5 |
  | 10 | 1 | no | 5 |

- R23. Three constants, in seconds, named so that they can be tuned after manual QA on a slow connection:
  - `Schedule.attemptTimeout` is 3: the wait for one endpoint;
  - `Schedule.lastAttemptStart` is 6.5: no attempt starts later than this after its check began, so a check ends within 9.5 s;
  - `Schedule.debounce` is 1.5: the wait after a network change.

## Interface (provided)

What `menubar-app` and `ip-check` read. Each struct also has a public memberwise initializer. The address and country rules (R6, R7) stay internal and are tested through `@testable import`.

```swift
public struct Reading: Equatable, Sendable {
    public var address: String                          // "203.0.113.7"
    public var countryCode: String?                     // "SE"; nil when the endpoint gave none
    public var source: String                           // the host that answered: "ipv4.icanhazip.com"
}

public struct Endpoint: Equatable, Sendable {
    public enum Format: Sendable { case trace, identJSON, plainAddress }
    public var url: URL
    public var format: Format
}

public enum Lookup {
    public static let chain: [Endpoint]
    public static func parse(_ body: Data, from endpoint: Endpoint) -> Reading?
}

public enum Status: Equatable, Sendable {
    case checking                                       // no check has finished since launch
    case reading(Reading, at: Date)
    case noAnswer(at: Date)
}

public enum BarContent: Equatable, Sendable {
    case text(String)                                   // "🇸🇪 203.0.113.7"
    case symbol(name: String, description: String)      // "network", "OutIP: checking"
}

public struct MenuInfo: Equatable, Sendable {
    public var header: String                           // "Sweden", "Unknown country", "No answer", "Checking…"
    public var address: String?                         // what Copy puts on the clipboard
    public var copyTitle: String?                       // "Copy 203.0.113.7"
    public var detail: String?                          // "12:05:13 PM · ipv4.icanhazip.com", "Tried 12:05:13 PM"
}

public enum Display {
    public static func flag(for countryCode: String?) -> String
    public static func bar(for status: Status, showAddress: Bool) -> BarContent
    public static func info(for status: Status, calendar: Calendar, locale: Locale) -> MenuInfo
}

public enum Interval {
    public static let options: [Int]                    // 10, 30, 60, 300
    public static let fallback: Int                     // 30
    public static func title(for seconds: Int) -> String
    public static func resolve(_ stored: Int?) -> Int
}

public enum Schedule {
    public static let attemptTimeout: TimeInterval      // 3
    public static let lastAttemptStart: TimeInterval    // 6.5
    public static let debounce: TimeInterval            // 1.5
    public static func delay(interval: TimeInterval, failures: Int, afterTrigger: Bool) -> TimeInterval
}
```

## Project Structure

```
Package.swift
Sources/OutIPCore/Reading.swift         Reading, the address and country rules
Sources/OutIPCore/Lookup.swift          Endpoint, the chain, parse
Sources/OutIPCore/Display.swift         Status, the flag, the bar, the menu text
Sources/OutIPCore/Schedule.swift        Interval, Schedule
Tests/OutIPCoreTests/                   one file per rule family, plus Support.swift (the fixed calendar, `at(…)`, the fixtures)
```

## Tech Stack

Swift 6 (the Mac has Swift 6.4 with Xcode 27.2), SwiftPM, Foundation, Swift Testing. No dependencies.

## Commands

```
swift build
swift test
swift test --filter Lookup          # one suite
```

Checks (the gate, unattended): `swift build && swift test`

## Code Style

A rule is a small static function with a one-line doc that cites its requirement, and a table test beside it:

```swift
/// "🇸🇪" for "SE": two regional indicators; "🌐" without a code (core-rules R14).
public static func flag(for countryCode: String?) -> String {
    guard let countryCode else { return "🌐" }
    return countryCode.unicodeScalars.map { String(UnicodeScalar(0x1F1E6 + $0.value - 65)!) }.joined()
}
```

```swift
@Test(arguments: [("SE", "🇸🇪"), ("JP", "🇯🇵"), (nil, "🌐")] as [(String?, String)])
func flag(code: String?, expected: String) {
    #expect(Display.flag(for: code) == expected)
}
```

Names in code use American spelling. UI text is English and is written once, in the function that returns it.

## Testing Strategy

- Swift Testing in `Tests/OutIPCoreTests`, with table tests (`@Test(arguments:)`).
- Every table and example in the Requirements is a test, row for row.
- Fixed inputs only: a Gregorian calendar in `Asia/Kolkata` (a half-hour offset catches UTC assumptions), the locale `en_US`, dates built from components. R18 adds the one `en_GB` case.
- The fixtures of R10 to R12 are string constants in `Support.swift`. No test makes a request or holds a real reply.
- In `en_US` the time has U+202F, a narrow no-break space, before `AM` and `PM`. Tests write `"12:05:13\u{202F}PM"`, never a typed space.

## Boundaries

- Always: pass bytes, dates, `calendar` and `locale` in; add the test in the same commit as the rule; run `swift build && swift test` before each commit.
- Ask first (in an unattended run, stop and report it): a dependency; a public name other than those in Interface; a rule this spec doesn't state; a change to the chain or to the constants of R23.
- Never: import AppKit, Network or SwiftUI in `OutIPCore`; use `URLSession`; read the real clock, calendar, locale or `UserDefaults` in the library or its tests; put an address or a country from a real request in a test.

## Success Criteria

Done when: `OutIPCore` holds every rule of this spec with each case as a passing test, and `swift build && swift test` pass.

Manual QA: none.

## Open Questions

None of its own. The product assumptions behind these rules are in the map.
