import Foundation

/// What the app knows right now (core-rules R15).
public enum Status: Equatable, Sendable {
    case checking
    case reading(Reading, at: Date)
    case noAnswer(at: Date)
}

/// What the menu bar shows: text, or an SF Symbol with its accessibility description (core-rules R16).
public enum BarContent: Equatable, Sendable {
    case text(String)
    case symbol(name: String, description: String)
}

/// The text of the menu's first block (core-rules R17).
public struct MenuInfo: Equatable, Sendable {
    public var header: String
    public var address: String?
    public var copyTitle: String?
    public var detail: String?

    public init(header: String, address: String?, copyTitle: String?, detail: String?) {
        self.header = header
        self.address = address
        self.copyTitle = copyTitle
        self.detail = detail
    }
}

public enum Display {
    /// "🇸🇪" for "SE": two regional indicators; "🌐" without a code (core-rules R14).
    public static func flag(for countryCode: String?) -> String {
        guard let countryCode else { return "🌐" }
        return countryCode.unicodeScalars.map { String(UnicodeScalar(0x1F1E6 + $0.value - 65)!) }.joined()
    }

    /// "<flag> <address>" for a reading, or the flag alone when `showAddress` is false;
    /// a symbol while checking or after no answer (core-rules R16, compact-bar R1).
    public static func bar(for status: Status, showAddress: Bool) -> BarContent {
        switch status {
        case .reading(let reading, _):
            .text(showAddress ? "\(flag(for: reading.countryCode)) \(reading.address)" : flag(for: reading.countryCode))
        case .checking: .symbol(name: "network", description: "OutIP: checking")
        case .noAnswer: .symbol(name: "network.slash", description: "OutIP: no answer")
        }
    }

    /// The country's name, Copy and the time with the host, per state (core-rules R17, R18).
    public static func info(for status: Status, calendar: Calendar, locale: Locale) -> MenuInfo {
        func time(_ date: Date) -> String {
            date.formatted(Date.FormatStyle(date: .omitted, time: .standard, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
        }
        switch status {
        case .reading(let reading, let date):
            let country = reading.countryCode.flatMap { locale.localizedString(forRegionCode: $0) }
            return MenuInfo(header: country ?? "Unknown country", address: reading.address,
                            copyTitle: "Copy \(reading.address)", detail: "\(time(date)) · \(reading.source)")
        case .noAnswer(let date):
            return MenuInfo(header: "No answer", address: nil, copyTitle: nil, detail: "Tried \(time(date))")
        case .checking:
            return MenuInfo(header: "Checking…", address: nil, copyTitle: nil, detail: nil)
        }
    }
}
