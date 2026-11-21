import Foundation
import OutIPCore

/// The check: the endpoint chain over a new session per check (ip-check R1–R5).
/// The only file with network code (menubar-app R27).
final class Checker {
    private let show: (Status) -> Void
    private var task: Task<Void, Never>?

    init(show: @escaping (Status) -> Void) {
        self.show = show
    }

    /// Starts a check now (R3, R4).
    func check() {
        task = Task {
            let reading = await Self.ask()
            show(reading.map { .reading($0, at: Date()) } ?? .noAnswer(at: Date()))
        }
    }

    /// A new ephemeral session: a new connection, this moment's route and proxy (R2). The caller invalidates it.
    nonisolated private static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Schedule.attemptTimeout
        config.timeoutIntervalForResource = Schedule.attemptTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpCookieStorage = nil
        return URLSession(configuration: config)
    }

    /// Walks the chain until one endpoint answers; nothing about it is logged (R3, R5).
    nonisolated private static func ask() async -> Reading? {
        let session = session()
        defer { session.invalidateAndCancel() }
        let clock = ContinuousClock(), lastStart = clock.now + .seconds(Schedule.lastAttemptStart)
        for endpoint in Lookup.chain where clock.now < lastStart && !Task.isCancelled {
            if let reading = try? await attempt(endpoint, in: session) { return reading }
        }
        return nil
    }

    private nonisolated enum AttemptError: Error { case http(Int), parse }

    /// One GET: a reading when the status is 200 and the body parses (R3).
    nonisolated private static func attempt(_ endpoint: Endpoint, in session: URLSession) async throws -> Reading {
        let (body, response) = try await session.data(from: endpoint.url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw AttemptError.http(status) }
        guard let reading = Lookup.parse(body, from: endpoint) else { throw AttemptError.parse }
        return reading
    }
}
