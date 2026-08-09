import Foundation

/// Observes persisted store changes and surfaces a monotonic revision for projection refresh.
///
/// Implemented by `SwiftDataStoreChangeMonitor` in the Data package; features depend on this
/// protocol rather than the concrete monitor type.
@MainActor
public protocol StoreChangeMonitoring: AnyObject {
    /// Monotonically increasing revision bumped after each processed store change batch.
    var revision: Int { get }

    /// Registers a handler invoked on the main actor whenever `revision` advances.
    ///
    /// - Parameter handler: Called with the new revision value after a store change is processed.
    func onRevisionChange(_ handler: @escaping @MainActor (Int) -> Void)
}

@MainActor
public enum StoreChangeMonitoringSubscription {
    /// Subscribes a view model to store revision bumps when a monitor is available.
    ///
    /// - Parameters:
    ///   - monitor: Optional monitor from app composition; no-op when `nil`.
    ///   - handler: Invoked on the main actor with the latest revision.
    public static func subscribe(
        monitor: (any StoreChangeMonitoring)?,
        handler: @escaping @MainActor (Int) -> Void
    ) {
        guard let monitor else { return }
        monitor.onRevisionChange(handler)
    }
}
