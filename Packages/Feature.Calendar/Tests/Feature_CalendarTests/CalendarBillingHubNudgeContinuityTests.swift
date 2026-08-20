import Combine
import Core
import PersistenceModels
import Data
import EventKit
import SwiftData
import Testing
import CoreTesting
@testable import Feature_Calendar

@MainActor
@Suite(.tags(.integration))
struct CalendarBillingHubNudgeContinuityTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @Test func clearBillingHubNudgeMessageKeepsFocusSessionIDs() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = CalendarViewModel(
            modelContext: context,
            modelContainer: container,
            syncService: IdleSyncService(),
            eventKitService: EmptyCalendarEventService(),
            recurrenceRuleManager: RecurrenceRuleManager()
        )
        let focusID = UUID()

        viewModel.setBillingHubNudge(message: "Session ready for billing", sessionIDs: [focusID])
        viewModel.clearBillingHubNudgeMessage()

        #expect(viewModel.sessionReadyForBillingHubMessage == nil)
        #expect(viewModel.sessionReadyForBillingHubSessionIDs == [focusID])
    }

    @Test func clearBillingHubNudgeClearsMessageAndFocusIDs() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = CalendarViewModel(
            modelContext: context, modelContainer: container,
            syncService: IdleSyncService(),
            eventKitService: EmptyCalendarEventService(),
            recurrenceRuleManager: RecurrenceRuleManager())

        viewModel.setBillingHubNudge(message: "Session ready for billing", sessionIDs: [UUID()])
        viewModel.clearBillingHubNudge()

        #expect(viewModel.sessionReadyForBillingHubMessage == nil)
        #expect(viewModel.sessionReadyForBillingHubSessionIDs.isEmpty)
    }

    @Test func subsequentCompletionNudgeKeepsEarlierPendingFocusIDs() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = CalendarViewModel(
            modelContext: context, modelContainer: container,
            syncService: IdleSyncService(),
            eventKitService: EmptyCalendarEventService(),
            recurrenceRuleManager: RecurrenceRuleManager())
        let first = UUID()
        let second = UUID()

        viewModel.setBillingHubNudge(
            message: "Session ready for Billing Hub.",
            sessionIDs: [first]
        )
        viewModel.clearBillingHubNudgeMessage()
        viewModel.setBillingHubNudge(
            message: "Session ready for Billing Hub.",
            sessionIDs: [second, first]
        )

        #expect(viewModel.sessionReadyForBillingHubSessionIDs == [first, second]
        )
        #expect(viewModel.sessionReadyForBillingHubMessage == "2 sessions ready for Billing Hub."
        )
    }
}

private struct IdleSyncService: SyncService {
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
private final class EmptyCalendarEventService: CalendarEventService {
    var accessGranted: Bool { true }
    var accessGrantedPublisher: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }

    func fetchEvents(start: Date, end: Date) async -> [EKEvent] { [] }
    func delete(syncIdentifier: String, span: EKSpan) {}
    func getCalendars() -> [EKCalendar] { [] }
}
