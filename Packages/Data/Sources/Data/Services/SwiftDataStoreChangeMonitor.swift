import Core
import Foundation
import Observation
import os
import SwiftData

/// Observes SwiftData persistent history and surfaces a monotonic revision for projection refresh.
///
/// Uses token-based `fetchHistory` (WWDC24) so CloudKit merges and cross-context saves bump revision
/// without relying on broad `NSManagedObjectContextDidSave` notifications. When `HistoryObserver`
/// ships in a future SDK, this type can swap its backend without changing feature view models.
@Observable
@MainActor
public final class SwiftDataStoreChangeMonitor {

    public private(set) var revision: Int = 0

    private let modelContext: ModelContext
    private let tokenStore: HistoryTokenStore
    private var lastToken: DefaultHistoryToken?
    @ObservationIgnored private var revisionBumpTask: Task<Void, Never>?
    private let revisionBumpDelay: Duration = .milliseconds(300)
    @ObservationIgnored private var saveObserver: NSObjectProtocol?
    @ObservationIgnored private var remoteChangeObserver: NSObjectProtocol?

    public init(modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelContext = context
        self.tokenStore = HistoryTokenStore(container: modelContainer)
        restoreOrSeedHistoryToken()
        startObserving()
    }

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.tokenStore = HistoryTokenStore(container: modelContext.container)
        restoreOrSeedHistoryToken()
        startObserving()
    }

    isolated deinit {
        revisionBumpTask?.cancel()
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
        }
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
        }
    }

    /// Keeps projection-driven view models aligned with persisted store changes.
    public func onRevisionChange(_ handler: @escaping @MainActor (Int) -> Void) {
        beginRevisionObservation(handler: handler)
        handler(revision)
    }

    private func beginRevisionObservation(handler: @escaping @MainActor (Int) -> Void) {
        withObservationTracking {
            _ = revision
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                handler(self.revision)
                self.beginRevisionObservation(handler: handler)
            }
        }
    }

    private func restoreOrSeedHistoryToken() {
        if let restored = tokenStore.load() {
            lastToken = restored
            return
        }
        seedLatestHistoryToken()
    }

    private func seedLatestHistoryToken() {
        do {
            var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
            descriptor.sortBy = [SortDescriptor(\.token, order: .reverse)]
            descriptor.fetchLimit = 1
            let token = try modelContext.fetchHistory(descriptor).first?.token
            lastToken = token
            if let token {
                tokenStore.save(token)
            }
        } catch {
            Logger.data.error("SwiftDataStoreChangeMonitor seedLatestHistoryToken failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startObserving() {
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.consumeHistoryTransactions()
            }
        }

        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.consumeHistoryTransactions()
            }
        }

    }

    private func consumeHistoryTransactions() {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        descriptor.sortBy = [SortDescriptor(\.token, order: .forward)]
        if let lastToken {
            let token = lastToken
            descriptor.predicate = #Predicate<DefaultHistoryTransaction> { transaction in
                transaction.token > token
            }
        }

        let transactions: [DefaultHistoryTransaction]
        do {
            transactions = try modelContext.fetchHistory(descriptor)
        } catch {
            if isHistoryTokenExpired(error) {
                Logger.data.warning("SwiftDataStoreChangeMonitor history token expired; re-seeding latest token")
                tokenStore.clear()
                seedLatestHistoryToken()
                scheduleRevisionBump(immediate: true)
            } else {
                Logger.data.error("SwiftDataStoreChangeMonitor fetchHistory failed: \(error.localizedDescription, privacy: .public)")
                scheduleRevisionBump(immediate: true)
            }
            return
        }

        guard !transactions.isEmpty else { return }

        if let newToken = transactions.last?.token {
            lastToken = newToken
            tokenStore.save(newToken)
        }

        // Do not deleteHistory here. CloudKit mirroring keeps its own history token;
        // purging past this monitor's token invalidates CloudKit's token → 134301
        // HistoryExpired → export thrash → permanent "exporting" / reset loops.
        scheduleRevisionBump(immediate: false)
    }

    private func scheduleRevisionBump(immediate: Bool) {
        revisionBumpTask?.cancel()
        if immediate {
            revision &+= 1
            return
        }
        revisionBumpTask = Task { @MainActor [weak self] in
            guard await Task.waitUnlessCancelled(for: self?.revisionBumpDelay ?? .milliseconds(300)) else { return }
            guard !Task.isCancelled, let self else { return }
            self.revision &+= 1
        }
    }

    private func isHistoryTokenExpired(_ error: Error) -> Bool {
        let description = String(describing: error)
        return description.localizedCaseInsensitiveContains("historyTokenExpired")
            || description.localizedCaseInsensitiveContains("history token is expired")
            || description.localizedCaseInsensitiveContains("token expired")
            || description.localizedCaseInsensitiveContains("token is expired")
    }
}
