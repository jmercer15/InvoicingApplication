#if DEBUG
import Foundation

/// Fixed clock for repeatable integration tests (2023-11-14 22:13:20 UTC).
public enum TestClock {
    public static let reference = Date(timeIntervalSince1970: 1_700_000_000)

    public static var now: Date { reference }

    public static func addingTimeInterval(_ interval: TimeInterval) -> Date {
        reference.addingTimeInterval(interval)
    }
}
#endif
