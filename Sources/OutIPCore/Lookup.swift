import Foundation

/// A URL to ask and the format of its reply (core-rules R8).
public struct Endpoint: Equatable, Sendable {
    public enum Format: Sendable { case trace, identJSON, plainAddress }
    public var url: URL
    public var format: Format

    public init(url: URL, format: Format) {
        self.url = url
        self.format = format
    }
}

public enum Lookup {
    /// The five endpoints, asked in this order; the first valid answer wins (core-rules R8).
    public static let chain: [Endpoint] = [
        Endpoint(url: URL(string: "https://ipv4.icanhazip.com/cdn-cgi/trace")!, format: .trace),
        Endpoint(url: URL(string: "https://4.ident.me/json")!, format: .identJSON),
        Endpoint(url: URL(string: "https://1.1.1.1/cdn-cgi/trace")!, format: .trace),
        Endpoint(url: URL(string: "https://1.0.0.1/cdn-cgi/trace")!, format: .trace),
        Endpoint(url: URL(string: "https://checkip.amazonaws.com/")!, format: .plainAddress),
    ]

    /// A reply's body as a reading, or nil when it is too large, not UTF-8 or holds no valid address (core-rules R9–R12).
    public static func parse(_ body: Data, from endpoint: Endpoint) -> Reading? {
        guard body.count <= 4096, let text = String(data: body, encoding: .utf8) else { return nil }
        let address: String?
        let country: String?
        switch endpoint.format {
        case .trace:
            let lines = text.components(separatedBy: "\n").map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
            func value(_ key: String) -> String? {
                lines.first { $0.hasPrefix(key) }.map { String($0.dropFirst(key.count)) }
            }
            address = value("ip=")
            country = value("loc=")
        case .identJSON:
            let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            address = object?["ip"] as? String
            country = object?["cc"] as? String
        case .plainAddress:
            address = text.trimmingCharacters(in: .whitespacesAndNewlines)
            country = nil
        }
        guard let address, Reading.isValidAddress(address) else { return nil }
        return Reading(address: address, countryCode: Reading.countryCode(from: country), source: endpoint.url.host() ?? "")
    }
}
