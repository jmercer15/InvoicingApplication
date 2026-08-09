import Foundation

/// Notification-based UserDefaults observation for profile/settings fields.
/// `UserDefaults` stays on the caller's main actor; stream lifetime owns its observation task.
@MainActor
public extension UserDefaults {
    func observedValue<Value: Sendable>(
        forKey key: String,
        as type: Value.Type
    ) -> AsyncStream<Value?> {
        let (stream, continuation) = AsyncStream.makeStream(of: Value?.self)
        continuation.yield(object(forKey: key) as? Value)

        let defaults = self
        let observationTask = Task { @MainActor [weak defaults] in
            guard let defaults else { return }
            for await notification in NotificationCenter.default.notifications(
                named: UserDefaults.didChangeNotification
            ) {
                guard let changedDefaults = notification.object as? UserDefaults,
                      changedDefaults === defaults else {
                    continue
                }
                continuation.yield(defaults.object(forKey: key) as? Value)
            }
        }

        continuation.onTermination = { _ in
            observationTask.cancel()
        }

        return stream
    }
}
