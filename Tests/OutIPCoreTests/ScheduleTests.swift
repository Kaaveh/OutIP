import Foundation
import Testing
import OutIPCore

@Suite struct IntervalTests {
    @Test func options() {
        #expect(Interval.options == [10, 30, 60, 300])
        #expect(Interval.fallback == 30)
    }

    @Test(arguments: [(10, "10 seconds"), (30, "30 seconds"), (60, "1 minute"), (300, "5 minutes")])
    func title(seconds: Int, expected: String) {
        #expect(Interval.title(for: seconds) == expected)
    }

    @Test(arguments: [(10, 10), (30, 30), (60, 60), (300, 300), (nil, 30), (0, 30), (45, 30), (-5, 30)] as [(Int?, Int)])
    func resolve(stored: Int?, expected: Int) {
        #expect(Interval.resolve(stored) == expected)
    }
}

@Suite struct ScheduleTests {
    @Test(arguments: [
        (30, 0, false, 30), (30, 1, false, 5), (30, 3, false, 5), (30, 4, false, 30), (30, 0, true, 5),
        (30, 4, true, 5), (300, 0, false, 300), (300, 2, true, 5), (10, 0, true, 5), (10, 1, false, 5),
    ] as [(TimeInterval, Int, Bool, TimeInterval)])
    func delay(interval: TimeInterval, failures: Int, afterTrigger: Bool, expected: TimeInterval) {
        #expect(Schedule.delay(interval: interval, failures: failures, afterTrigger: afterTrigger) == expected)
    }

    @Test func constants() {
        #expect(Schedule.attemptTimeout == 3)
        #expect(Schedule.lastAttemptStart == 6.5)
        #expect(Schedule.debounce == 1.5)
    }
}
