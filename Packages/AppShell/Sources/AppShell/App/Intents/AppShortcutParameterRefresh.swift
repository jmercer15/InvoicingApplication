import Foundation

/// Refreshes Shortcuts parameter catalogs after persisted client catalog changes.
///
/// The `AppShortcutsProvider` lives in the main app target (required for Shortcuts
/// metadata discovery). The app wires `refreshHandler` at launch.
///
/// Calls coalesce: store-revision storms (CloudKit history reset) must not spam
/// `updateAppShortcutParameters` / LinkDaemon / Core Spotlight donations.
@MainActor
public enum AppShortcutParameterRefresh {
    public static var refreshHandler: (@MainActor () -> Void)?

    private static var pendingRefreshTask: Task<Void, Never>?
    private static let coalesceDelay: Duration = .milliseconds(750)
    /// LinkDaemon / App Intents metadata often not queryable early in launch under Xcode.
    private static let launchReadyDelay: Duration = .seconds(8)
    private static var isLaunchReady = false
    private static var launchReadyTask: Task<Void, Never>?
    /// After LNMetadataProvider 9004 / LinkDaemon flake, back off to avoid console + CS donation spam.
    private static var providerUnavailableUntil: Date?

    public static func prepareForLaunch() {
        guard launchReadyTask == nil, !isLaunchReady else { return }
        launchReadyTask = Task {
            guard await Task.waitUnlessCancelled(for: launchReadyDelay) else { return }
            guard !Task.isCancelled else { return }
            isLaunchReady = true
        }
    }

    public static func noteProviderUnavailable() {
        providerUnavailableUntil = Date().addingTimeInterval(60)
    }

    public static func refreshClientParameters() {
        prepareForLaunch()
        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task {
            if !isLaunchReady {
                guard await Task.waitUnlessCancelled(for: launchReadyDelay) else { return }
                guard !Task.isCancelled else { return }
                isLaunchReady = true
            } else {
                guard await Task.waitUnlessCancelled(for: coalesceDelay) else { return }
                guard !Task.isCancelled else { return }
            }
            if let until = providerUnavailableUntil, Date() < until {
                return
            }
            refreshHandler?()
        }
    }
}
