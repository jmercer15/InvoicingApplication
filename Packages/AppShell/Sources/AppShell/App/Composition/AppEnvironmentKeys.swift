import SwiftUI
import Data

// MARK: - CloudKit sync monitor (optional; activity root supplies the live monitor)

private enum CloudKitSyncMonitorKey: EnvironmentKey {
    static var defaultValue: CloudKitSyncMonitor? { nil }
}

extension EnvironmentValues {
    var cloudKitSyncMonitor: CloudKitSyncMonitor? {
        get { self[CloudKitSyncMonitorKey.self] }
        set { self[CloudKitSyncMonitorKey.self] = newValue }
    }
}
