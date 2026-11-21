import Foundation

/// One answer of one endpoint: the address, its country and the host that answered (core-rules R5).
public struct Reading: Equatable, Sendable {
    public var address: String
    public var countryCode: String?
    public var source: String

    public init(address: String, countryCode: String?, source: String) {
        self.address = address
        self.countryCode = countryCode
        self.source = source
    }

    /// True for exactly four dot-joined ASCII numbers 0...255 with no leading zero (core-rules R6).
    static func isValidAddress(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            let bytes = Array(part.utf8)
            guard (1...3).contains(bytes.count), bytes.allSatisfy({ (0x30...0x39).contains($0) }) else { return false }
            if bytes.count > 1 && bytes[0] == 0x30 { return false }
            return Int(part)! <= 255
        }
    }

    /// Two ASCII letters in capitals, or nil; "XX" (unknown) gives nil (core-rules R7).
    static func countryCode(from value: String?) -> String? {
        guard let value, value.utf8.count == 2,
              value.utf8.allSatisfy({ (0x41...0x5A).contains($0) || (0x61...0x7A).contains($0) })
        else { return nil }
        let code = value.uppercased()
        return code == "XX" ? nil : code
    }
}
