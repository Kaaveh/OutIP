import Foundation
import Testing
import OutIPCore

@Suite struct LookupTests {
    static let trace = Lookup.chain[0]
    static let identJSON = Lookup.chain[1]
    static let plainAddress = Lookup.chain[4]

    @Test func chain() {
        #expect(Lookup.chain.map(\.url.absoluteString) == [
            "https://ipv4.icanhazip.com/cdn-cgi/trace",
            "https://4.ident.me/json",
            "https://1.1.1.1/cdn-cgi/trace",
            "https://1.0.0.1/cdn-cgi/trace",
            "https://checkip.amazonaws.com/",
        ])
        #expect(Lookup.chain.map(\.format) == [.trace, .identJSON, .trace, .trace, .plainAddress])
    }

    @Test(arguments: [
        (trace, Fixture.trace, "SE"),
        (trace, Fixture.trace.replacingOccurrences(of: "\n", with: "\r\n"), "SE"),
        (trace, Fixture.trace.replacingOccurrences(of: "loc=SE", with: "loc=XX"), nil),
        (trace, Fixture.trace.replacingOccurrences(of: "loc=SE", with: "loc=T1"), nil),
        (trace, Fixture.trace.replacingOccurrences(of: "loc=SE\n", with: ""), nil),
        (identJSON, Fixture.identJSON, "SE"),
        (identJSON, #"{"ip":"203.0.113.7","cc":"se"}"#, "SE"),
        (identJSON, #"{"ip":"203.0.113.7"}"#, nil),
        (plainAddress, Fixture.plainAddress, nil),
    ] as [(Endpoint, String, String?)])
    func reading(endpoint: Endpoint, body: String, country: String?) {
        let reading = Lookup.parse(Data(body.utf8), from: endpoint)
        #expect(reading == Reading(address: "203.0.113.7", countryCode: country, source: endpoint.url.host()!))
    }

    @Test(arguments: [
        (trace, Fixture.trace.replacingOccurrences(of: "ip=203.0.113.7", with: "ip=2001:db8::7")),
        (trace, Fixture.trace.replacingOccurrences(of: "ip=203.0.113.7\n", with: "")),
        (trace, "<html><body>Access denied</body></html>"),
        (identJSON, #"{"ip":3405803783,"cc":"SE"}"#),
        (identJSON, #"["203.0.113.7"]"#),
        (identJSON, "<html>"),
        (plainAddress, "203.0.113.7 extra"),
        (plainAddress, "<html>"),
        (plainAddress, ""),
    ] as [(Endpoint, String)])
    func noReading(endpoint: Endpoint, body: String) {
        #expect(Lookup.parse(Data(body.utf8), from: endpoint) == nil)
    }

    static let fixtures = [(trace, Fixture.trace), (identJSON, Fixture.identJSON), (plainAddress, Fixture.plainAddress)]

    @Test(arguments: fixtures)
    func sizeLimit(endpoint: Endpoint, fixture: String) {
        func padded(to size: Int) -> Data { Data((fixture + String(repeating: " ", count: size - fixture.utf8.count)).utf8) }
        #expect(Lookup.parse(padded(to: 4096), from: endpoint) != nil)
        #expect(Lookup.parse(padded(to: 4097), from: endpoint) == nil)
    }

    @Test(arguments: fixtures.map(\.0))
    func notUTF8(endpoint: Endpoint) {
        #expect(Lookup.parse(Data([0xFF, 0xFE]), from: endpoint) == nil)
    }
}
