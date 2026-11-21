import AppKit
import Network
import OutIPCore

/// The check: the endpoint chain over a new session per check, and when to ask again (ip-check R1–R11).
/// The only file with network code (menubar-app R27).
final class Checker {
    private let show: (Status) -> Void
    private let interval: () -> Int
    private var task: Task<Void, Never>?
    private var timer: Timer?
    /// The shared wait of the debounced triggers (R9).
    private var debounce: Timer?
    /// Between screensDidSleep and screensDidWake no check starts (R10).
    private var screensAsleep = false
    /// Bumped whenever a check is replaced; a check that finds a newer one drops its answer (R8).
    private var generation = 0
    /// Failed checks in a row (R7).
    private var failures = 0
    /// Whether the last check was started by a debounced trigger (R8).
    private var afterTrigger = false

    init(show: @escaping (Status) -> Void, interval: @escaping () -> Int) {
        self.show = show
        self.interval = interval
    }

    /// Starts watching the triggers and runs the launch check (R8–R10).
    func start() {
        let center = NSWorkspace.shared.notificationCenter
        _ = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.trigger() }
        }
        _ = center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screensAsleep = false
                self?.trigger()
            }
        }
        _ = center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensDidSleep() }
        }
        Task { [weak self] in
            // The first update is the current path, not a change.
            for await _ in NWPathMonitor().dropFirst() { self?.trigger() }
        }
        check()
    }

    /// Starts a check now, in place of the pending timer and a running check (R4, R6–R8).
    func check(afterTrigger: Bool = false) {
        replace()
        let current = generation
        task = Task {
            let reading = await Self.ask()
            guard current == generation else { return }
            task = nil
            failures = reading == nil ? failures + 1 : 0
            show(reading.map { .reading($0, at: Date()) } ?? .noAnswer(at: Date()))
            self.afterTrigger = afterTrigger
            schedule()
        }
    }

    /// A new interval replaces the pending timer; a running check is left alone (R11).
    func intervalChanged() {
        guard let timer else { return }
        timer.invalidate()
        schedule()
    }

    /// A debounced trigger: drops the pending timer and a running check, and starts a check
    /// `Schedule.debounce` after the latest trigger; the old reading stays meanwhile (R8, R9).
    private func trigger() {
        guard !screensAsleep else { return }
        replace()
        debounce = oneShot(after: Schedule.debounce) { [weak self] in self?.check(afterTrigger: true) }
    }

    /// No timer and no trigger until the display wakes; a running check may finish (R10).
    private func screensDidSleep() {
        screensAsleep = true
        timer?.invalidate()
        timer = nil
        debounce?.invalidate()
        debounce = nil
    }

    /// Cancels the pending timers and a running check, whose answer is then dropped (R8).
    private func replace() {
        timer?.invalidate()
        timer = nil
        debounce?.invalidate()
        debounce = nil
        task?.cancel()
        task = nil
        generation += 1
    }

    /// The timer for the next check; none while the display sleeps (R6, R10).
    private func schedule() {
        guard !screensAsleep else { return }
        let delay = Schedule.delay(interval: TimeInterval(interval()), failures: failures, afterTrigger: afterTrigger)
        timer = oneShot(after: delay) { [weak self] in self?.check() }
    }

    /// A one-shot timer in `.common` run-loop modes with a tolerance of a tenth of the delay (R6).
    private func oneShot(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> Timer {
        let timer = Timer(timeInterval: delay, repeats: false) { _ in MainActor.assumeIsolated(action) }
        timer.tolerance = delay / 10
        RunLoop.main.add(timer, forMode: .common)
        return timer
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

    /// `OutIP --probe`: asks every endpoint once, each over its own session, and prints no address or country (R12–R14).
    /// Returns the exit status: 0 when at least one endpoint answered.
    static func probe() async -> Int32 {
        var readings: [Reading] = []
        for endpoint in Lookup.chain {
            let session = session()
            let start = Date()
            let outcome: String
            do {
                readings.append(try await attempt(endpoint, in: session))
                outcome = "ok"
            } catch AttemptError.http(let status) {
                outcome = "failed (http \(status))"
            } catch AttemptError.parse {
                outcome = "failed (parse)"
            } catch let error as URLError where error.code == .timedOut {
                outcome = "failed (timeout)"
            } catch {
                let error = error as NSError
                outcome = "failed (\(error.domain) \(error.code))"
            }
            session.invalidateAndCancel()
            print("\(endpoint.url.host() ?? ""): \(outcome) \(String(format: "%.1f", Date().timeIntervalSince(start))) s")
        }
        let countries = readings.compactMap(\.countryCode)
        let agree = readings.count < 2 ? "n/a"
            : Set(readings.map(\.address)).count == 1 && Set(countries).count <= 1 ? "yes" : "no"
        print("agree: \(agree)")
        return readings.isEmpty ? 1 : 0
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
