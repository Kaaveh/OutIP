import Foundation
import Testing
import OutIPCore

@Suite struct DisplayTests {
    static let noon = at(12, 5, 13)
    static let enUS = Locale(identifier: "en_US")

    @Test(arguments: [("SE", "🇸🇪"), ("JP", "🇯🇵"), (nil, "🌐")] as [(String?, String)])
    func flag(code: String?, expected: String) {
        #expect(Display.flag(for: code) == expected)
    }

    @Test func flagScalars() {
        #expect(Display.flag(for: "SE").unicodeScalars.map(\.value) == [0x1F1F8, 0x1F1EA])
        #expect(Display.flag(for: "JP").unicodeScalars.map(\.value) == [0x1F1EF, 0x1F1F5])
        #expect(Display.flag(for: nil).unicodeScalars.map(\.value) == [0x1F310])
    }

    static let se = Status.reading(Reading(address: "203.0.113.7", countryCode: "SE", source: "ipv4.icanhazip.com"), at: noon)
    static let none = Status.reading(Reading(address: "203.0.113.7", countryCode: nil, source: "checkip.amazonaws.com"), at: noon)

    @Test(arguments: [
        (se, true, .text("🇸🇪 203.0.113.7")),
        (none, true, .text("🌐 203.0.113.7")),
        (.checking, true, .symbol(name: "network", description: "OutIP: checking")),
        (.noAnswer(at: noon), true, .symbol(name: "network.slash", description: "OutIP: no answer")),
        (se, false, .text("🇸🇪")),
        (none, false, .text("🌐")),
        (.checking, false, .symbol(name: "network", description: "OutIP: checking")),
        (.noAnswer(at: noon), false, .symbol(name: "network.slash", description: "OutIP: no answer")),
    ] as [(Status, Bool, BarContent)])
    func bar(status: Status, showAddress: Bool, expected: BarContent) {
        #expect(Display.bar(for: status, showAddress: showAddress) == expected)
    }

    @Test(arguments: [
        (.reading(Reading(address: "203.0.113.7", countryCode: "SE", source: "ipv4.icanhazip.com"), at: noon),
         MenuInfo(header: "Sweden", address: "203.0.113.7", copyTitle: "Copy 203.0.113.7", detail: "12:05:13\u{202F}PM · ipv4.icanhazip.com")),
        (.reading(Reading(address: "203.0.113.7", countryCode: nil, source: "checkip.amazonaws.com"), at: noon),
         MenuInfo(header: "Unknown country", address: "203.0.113.7", copyTitle: "Copy 203.0.113.7", detail: "12:05:13\u{202F}PM · checkip.amazonaws.com")),
        (.reading(Reading(address: "203.0.113.7", countryCode: "QQ", source: "4.ident.me"), at: noon),
         MenuInfo(header: "Unknown country", address: "203.0.113.7", copyTitle: "Copy 203.0.113.7", detail: "12:05:13\u{202F}PM · 4.ident.me")),
        (.noAnswer(at: noon), MenuInfo(header: "No answer", address: nil, copyTitle: nil, detail: "Tried 12:05:13\u{202F}PM")),
        (.checking, MenuInfo(header: "Checking…", address: nil, copyTitle: nil, detail: nil)),
    ] as [(Status, MenuInfo)])
    func info(status: Status, expected: MenuInfo) {
        #expect(Display.info(for: status, calendar: calendar, locale: Self.enUS) == expected)
    }

    @Test func timeInBritishEnglish() {
        let info = Display.info(for: .noAnswer(at: Self.noon), calendar: calendar, locale: Locale(identifier: "en_GB"))
        #expect(info.detail == "Tried 12:05:13")
    }
}
