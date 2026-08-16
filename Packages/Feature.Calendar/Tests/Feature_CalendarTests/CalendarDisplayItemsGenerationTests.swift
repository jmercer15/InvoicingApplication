import Combine
import Core
import PersistenceModels
import Data
import EventKit
import SwiftData
import Testing
@testable import Feature_Calendar

@MainActor
@Suite(.tags(.integration))
struct CalendarDisplayItemsGenerationTests {
    @Test
    func rapidDisplayRefreshRequestsAdvanceGenerationWithoutStuckLoading() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = CalendarViewModel(
            modelContext: context,
            modelContainer: container,
            syncService: CalendarGenerationTestSyncService(),
            eventKitService: CalendarGenerationTestEventService(),
            recurrenceRuleManager: RecurrenceRuleManager()
        )

        async let firstRefresh: Void = runDisplayRefresh(viewModel)
        async let secondRefresh: Void = runDisplayRefresh(viewModel)
        await firstRefresh
        await secondRefresh

        #expect(viewModel.displayItemsUpdateGeneration >= 2)
        #expect(viewModel.isLoading == false)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelledDisplayRefreshDoesNotApplyStaleGeneration() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = CalendarViewModel(
            modelContext: context, modelContainer: container,
            syncService: CalendarGenerationTestSyncService(),
            eventKitService: CalendarGenerationTestEventService(),
            recurrenceRuleManager: RecurrenceRuleManager())

        viewModel.updateDisplayableItems()
        let staleGeneration = viewModel.displayItemsUpdateGeneration

        viewModel.displayItemsUpdateTask?.cancel()
        viewModel.displayItemsUpdateGeneration &+= 1
        viewModel.updateDisplayableItems()
        if let task = viewModel.displayItemsUpdateTask {
            await task.value
        }

        #expect(viewModel.displayItemsUpdateGeneration > staleGeneration)
        #expect(viewModel.isLoading == false)
    }

    private func runDisplayRefresh(_ viewModel: CalendarViewModel) async {
        viewModel.updateDisplayableItems()
        if let task = viewModel.displayItemsUpdateTask {
            await task.value
        }
    }
}

private struct CalendarGenerationTestSyncService: SyncService {
    var accessGranted: Bool { true }
    var syncEnabled: Bool { true }
    var lastSyncDate: Date? { nil }
    var syncStatus: SyncStatus { .idle }
    var availableCalendars: [CalendarInfo] { [] }
    var monitoredCalendarIdentifiers: Set<String> { [] }

    func requestAccess() async throws -> Bool { true }
    func setSyncEnabled(_ enabled: Bool) async {}
    func sync(session: SessionSnapshot) async throws {}
    func delete(syncIdentifier: String) async throws {}
    func update(session: SessionSnapshot) async throws {}
    func fetchEvents(start: Date, end: Date) async throws -> [CalendarEvent] { [] }
    func updateSessionFromRemote(session: SessionSnapshot, remoteEvent: CalendarEvent) async throws -> SessionSnapshot {
        session
    }
    func handleExternalChanges() async throws {}
}

@MainActor
private final class CalendarGenerationTestEventService: CalendarEventService {
    var accessGranted: Bool { true }
    var accessGrantedPublisher: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }

    func fetchEvents(start: Date, end: Date) async -> [EKEvent] { [] }
    func delete(syncIdentifier: String, span: EKSpan) {}
    func getCalendars() -> [EKCalendar] { [] }
}
