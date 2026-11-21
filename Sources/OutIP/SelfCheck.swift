import AppKit
import OutIPCore

/// `OutIP --self-check`: the real status item and menu on sample data, printed (R20–R26).
enum SelfCheck {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "GMT")!
        return calendar
    }()
    static let locale = Locale(identifier: "en_US")

    /// 203.0.113.7 in SE from ipv4.icanhazip.com, at 2026-11-21 12:05:13 GMT (R21).
    static let sample = Status.reading(
        Reading(address: "203.0.113.7", countryCode: "SE", source: "ipv4.icanhazip.com"),
        at: calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 12, minute: 5, second: 13))!
    )

    /// Checks the bar's symbols, prints the bar and the menu, keeps the item on screen for 5 s, prints the footprint and exits.
    static func run(_ item: NSStatusItem) {
        for status in [Status.checking, .noAnswer(at: .distantPast)] {
            if case .symbol(let name, let description) = Display.bar(for: status),
               NSImage(systemSymbolName: name, accessibilityDescription: description) == nil {
                FileHandle.standardError.write(Data("self-check: missing symbol \(name)\n".utf8))
                exit(1)
            }
        }

        var lines = ["bar: " + (item.button?.title ?? "").trimmingCharacters(in: .whitespaces)]
        if let menu = item.menu {
            menu.delegate?.menuNeedsUpdate?(menu)
            lines += menu.items.map { "menu: " + describe($0) }
        }
        print(lines.joined(separator: "\n").replacingOccurrences(of: "\u{202F}", with: " "))

        Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            MainActor.assumeIsolated {
                print(String(format: "footprint: %.1f MB", footprint()))
                exit(0)
            }
        }
    }

    private static func describe(_ item: NSMenuItem) -> String {
        if item.isSeparatorItem { return "---" }
        if item.isSectionHeader { return "# " + item.title }
        var text = checked(item)
        if let submenu = item.submenu {
            text += " > " + submenu.items.map(checked).joined(separator: ", ")
        }
        return text
    }

    private static func checked(_ item: NSMenuItem) -> String {
        (item.state == .on ? "✓ " : "") + item.title
    }

    /// The process's physical footprint in MB, as `footprint` reports it.
    private static func footprint() -> Double {
        var info = rusage_info_v0()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V0, $0)
            }
        }
        return result == 0 ? Double(info.ri_phys_footprint) / 1_048_576 : -1
    }
}
