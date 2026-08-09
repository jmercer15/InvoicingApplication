#if DEBUG
import Foundation

public enum TestAsyncError: Error, Equatable, Sendable {
    case timedOut(String)
}

public enum TestAsync {
    /// Polls `condition` until true or `timeout` elapses.
    @MainActor
    public static func waitUntil(
        _ description: String = "condition",
        timeout: Duration = .seconds(2),
        pollInterval: Duration = .milliseconds(10),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            if ContinuousClock.now >= deadline {
                throw TestAsyncError.timedOut(description)
            }
            try await Task.sleep(for: pollInterval)
        }
    }

    /// Awaits `task` completion with an explicit upper bound.
    @MainActor
    public static func awaitTask<T>(
        _ task: Task<T, Never>?,
        timeout: Duration = .seconds(2),
        description: String = "task completion"
    ) async throws {
        guard let task else { return }
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { await task.value }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw TestAsyncError.timedOut(description)
            }
            _ = try await group.next()
            group.cancelAll()
        }
    }
}
#endif
