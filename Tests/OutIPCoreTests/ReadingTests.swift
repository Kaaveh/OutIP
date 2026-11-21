import Testing
@testable import OutIPCore

@Suite struct ReadingTests {
    @Test(arguments: [
        ("203.0.113.7", true), ("0.0.0.0", true), ("255.255.255.255", true),
        ("256.0.113.7", false), ("203.0.113", false), ("203.0.113.7.1", false),
        ("203.0.113.", false), (".203.0.113.7", false),
        ("203.0.113.07", false), ("203.0.113.+7", false), ("203.0.113.7 ", false), ("203.0.113.7:443", false),
        ("٢٠٣.0.113.7", false), ("2001:db8::7", false), ("", false),
    ])
    func address(text: String, valid: Bool) {
        #expect(Reading.isValidAddress(text) == valid)
    }

    @Test(arguments: [
        ("SE", "SE"), ("se", "SE"),
        ("XX", nil), ("xx", nil), ("T1", nil), ("SWE", nil), ("S", nil), ("5E", nil), ("", nil), (nil, nil),
    ] as [(String?, String?)])
    func country(value: String?, expected: String?) {
        #expect(Reading.countryCode(from: value) == expected)
    }
}
