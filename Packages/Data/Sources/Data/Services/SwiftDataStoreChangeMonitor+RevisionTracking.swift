import Foundation

extension SwiftDataStoreChangeMonitor {

    /// Subscribes to monotonic store revision updates, falling back to legacy save notifications in tests/previews.
    public static func subscribeToStoreChanges(
        monitor: SwiftDataStoreChangeMonitor?,
        onRevision: @escaping @MainActor (Int) -> Void
    ) {
        if let monitor {
            monitor.onRevisionChange(onRevision)
            return
        }

        final class LegacyRevisionTracker: @unchecked Sendable {
            var revision = 0
        }
        let tracker = LegacyRevisionTracker()
        NotificationCenter.default.addObserver(
            forName: Notification.Name.NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                tracker.revision &+= 1
                onRevision(tracker.revision)
            }
        }
    }
}
