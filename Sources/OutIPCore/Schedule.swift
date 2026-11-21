import Foundation

public enum Interval {
    /// The check intervals the menu offers, in seconds (core-rules R19).
    public static let options = [10, 30, 60, 300]
    /// The interval when none is stored or the stored one isn't offered (core-rules R19).
    public static let fallback = 30

    /// "10 seconds", "1 minute", "5 minutes" (core-rules R20).
    public static func title(for seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) seconds" }
        let minutes = seconds / 60
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    /// The stored interval when it is one of the options, the fallback otherwise (core-rules R21).
    public static func resolve(_ stored: Int?) -> Int {
        guard let stored, options.contains(stored) else { return fallback }
        return stored
    }
}

public enum Schedule {
    /// The wait for one endpoint, in seconds (core-rules R23).
    public static let attemptTimeout: TimeInterval = 3
    /// No attempt starts later than this after its check began, in seconds (core-rules R23).
    public static let lastAttemptStart: TimeInterval = 6.5
    /// The wait after a network change, in seconds (core-rules R23).
    public static let debounce: TimeInterval = 1.5

    /// Seconds from the end of one check to the start of the next: 5 at most after 1–3 failures or a trigger (core-rules R22).
    public static func delay(interval: TimeInterval, failures: Int, afterTrigger: Bool) -> TimeInterval {
        (1...3).contains(failures) || afterTrigger ? min(interval, 5) : interval
    }
}
