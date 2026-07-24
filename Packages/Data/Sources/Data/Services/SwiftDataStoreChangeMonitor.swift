import Foundation
import Observation
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
    private var lastToken: DefaultHistoryToken?
    @ObservationIgnored nonisolated(unsafe) private var saveObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var remoteChangeObserver: NSObjectProtocol?

    public init(modelContainer: ModelContainer) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelContext = context
        seedLatestHistoryToken()
        startObserving()
    }

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        seedLatestHistoryToken()
        startObserving()
    }

    deinit {
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

    private func seedLatestHistoryToken() {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        descriptor.sortBy = [SortDescriptor(\.token, order: .reverse)]
        descriptor.fetchLimit = 1
        lastToken = try? modelContext.fetchHistory(descriptor).first?.token
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

        guard let transactions = try? modelContext.fetchHistory(descriptor), !transactions.isEmpty else {
            return
        }

        lastToken = transactions.last?.token ?? lastToken
        revision &+= 1
    }
}
