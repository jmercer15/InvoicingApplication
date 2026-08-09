import Foundation

/// Debounced board projection refresh. On cancel during sleep, skip refresh so rapid
/// `dataRevision` / filter churn does not stack stale completions.
@MainActor
enum BillingHubProjectionDebounce {
    static func run(
        delay: Duration = .milliseconds(150),
        refresh: @MainActor () async -> Void
    ) async {
        do {
            try await Task.sleep(for: delay)
        } catch {
            // CancellationError (or other sleep failure): do not refresh.
            return
        }
        await refresh()
    }
}
