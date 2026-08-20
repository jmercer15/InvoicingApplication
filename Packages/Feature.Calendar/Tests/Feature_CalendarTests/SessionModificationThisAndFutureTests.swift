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
struct SessionModificationThisAndFutureTests {
    @MainActor
    private struct Harness {
        let container: ModelContainer
        let context: ModelContext
        let recurrenceRuleManager: RecurrenceRuleManager
        let syncService: RecordingSyncService
        let service: SessionModificationService

        init() throws {
            let (container, context) = try ModelContainerFactory.makeInMemoryContext()
            self.container = container
            self.context = context
            self.recurrenceRuleManager = RecurrenceRuleManager()
            self.syncService = RecordingSyncService()
            self.service = SessionModificationService(
                modelContainer: container,
                syncService: syncService,
                eventKitService: StubCalendarEventService(),
                recurrenceRuleManager: recurrenceRuleManager
            )
        }

        func session(id: UUID) throws -> Session {
            var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return try #require(try context.fetch(descriptor).first)
        }
    }

    @Test func thisAndFutureSplitKeepsExpandableRRULEOnNewMaster() async throws {
        let harness = try Harness()
        let calendar = Calendar(identifier: .gregorian)
        let seriesStart = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 10))!
        let seriesEnd = seriesStart.addingTimeInterval(3600)
        let splitDate = calendar.date(byAdding: .day, value: 3, to: seriesStart)!
        let rangeEnd = calendar.date(byAdding: .day, value: 14, to: seriesStart)!

        let client = Client(id: UUID(), ndisNumber: "4300000001", fullName: "Test Client", status: .active)
        let clientService = ClientService(serviceName: "Therapy", unit: "hour", rate: 193.99)
        clientService.client = client
        harness.context.insert(client)
        harness.context.insert(clientService)

        let originalRule = EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            daysOfTheWeek: nil,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        )
        let originalRuleData = try #require(harness.recurrenceRuleManager.serialize(originalRule))

        let master = Session(
            id: UUID(),
            title: "Daily Session",
            startTime: seriesStart,
            endTime: seriesEnd,
            status: .scheduled,
            recurrenceRuleData: originalRuleData
        )
        master.client = client
        master.clientService = clientService
        harness.context.insert(master)
        try harness.context.save()

        var form = SessionFormModel(from: master, recurrenceRuleManager: harness.recurrenceRuleManager)
        form.startTime = splitDate
        form.endTime = splitDate.addingTimeInterval(3600)
        form.title = "Daily Session (future)"

        let newMasterID = try await harness.service.modifySession(
            sessionID: master.id,
            with: form,
            mode: .thisAndFuture,
            originalInstanceDate: splitDate
        )
        let newMaster = try harness.session(id: newMasterID)

        #expect(newMaster.id != master.id)
        #expect(newMaster.startTime == splitDate)
        #expect(newMaster.groupID == nil, "Future-split master must not inherit groupID")
        #expect(newMaster.groupedPosition == 0)

        let truncatedMaster = try harness.session(id: master.id)
        let oldRuleData = try #require(truncatedMaster.recurrenceRuleData)
        let oldRule = try #require(harness.recurrenceRuleManager.deserialize(oldRuleData))
        let oldEnd = try #require(oldRule.recurrenceEnd?.endDate)
        #expect(oldEnd < splitDate)

        let newRuleData = try #require(newMaster.recurrenceRuleData)
        let newRule = try #require(harness.recurrenceRuleManager.deserialize(newRuleData))
        if let newEnd = newRule.recurrenceEnd?.endDate {
            #expect(newEnd >= splitDate)
        }

        let expander = RecurrenceService(recurrenceRuleManager: harness.recurrenceRuleManager)
        let futureInstances = expander.expandRecurringSession(
            newMaster, rule: newRule,
            masterStartTime: try #require(newMaster.startTime),
            masterEndTime: try #require(newMaster.endTime),
            rangeStart: splitDate,
            rangeEnd: rangeEnd)
        #expect(!futureInstances.isEmpty, "Future master must expand occurrences after split date")
        #expect(futureInstances.allSatisfy { $0.instanceStart >= splitDate })

        let pastInstances = expander.expandRecurringSession(
            master, rule: oldRule,
            masterStartTime: try #require(master.startTime),
            masterEndTime: try #require(master.endTime),
            rangeStart: seriesStart,
            rangeEnd: rangeEnd)
        #expect(!pastInstances.isEmpty)
        #expect(pastInstances.allSatisfy { $0.instanceStart < splitDate })

        let syncedIDs = await waitForSyncedSessionIDs(harness.syncService, expectedCount: 2)
        #expect(Set(syncedIDs) == Set([master.id, newMaster.id]))
    }

    @Test func thisOnlyDetachFromInvoicedMasterStampsUninvoicedNote() async throws {
        let harness = try Harness()
        let calendar = Calendar(identifier: .gregorian)
        let seriesStart = calendar.date(from: DateComponents(year: 2026, month: 4, day: 6, hour: 10))!
        let seriesEnd = seriesStart.addingTimeInterval(3600)
        let occurrenceDate = calendar.date(byAdding: .day, value: 2, to: seriesStart)!

        let client = Client(id: UUID(), ndisNumber: "4300000001", fullName: "Test Client", status: .active)
        let clientService = ClientService(serviceName: "Therapy", unit: "hour", rate: 193.99)
        clientService.client = client
        harness.context.insert(client)
        harness.context.insert(clientService)

        let originalRule = EKRecurrenceRule(
            recurrenceWith: .daily, interval: 1,
            daysOfTheWeek: nil,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil)
        let originalRuleData = try #require(harness.recurrenceRuleManager.serialize(originalRule))

        let invoice = Invoice(id: UUID(), invoiceNumber: "DETACH-001")
        let master = Session(
            id: UUID(),
            title: "Invoiced Series",
            startTime: seriesStart,
            endTime: seriesEnd,
            status: .completed,
            recurrenceRuleData: originalRuleData
        )
        master.client = client
        master.clientService = clientService
        master.invoice = invoice
        harness.context.insert(invoice)
        harness.context.insert(master)
        try harness.context.save()

        var form = SessionFormModel(from: master, recurrenceRuleManager: harness.recurrenceRuleManager)
        form.startTime = occurrenceDate
        form.endTime = occurrenceDate.addingTimeInterval(3600)
        form.title = "Detached occurrence"
        form.status = Core.SessionStatus.completed.rawValue

        let detachedID = try await harness.service.modifySession(
            sessionID: master.id,
            with: form,
            mode: .thisOnly,
            originalInstanceDate: occurrenceDate
        )
        let detached = try harness.session(id: detachedID)

        #expect(detached.id != master.id)
        #expect(detached.isDetached)
        #expect(detached.invoice == nil)
        #expect(detached.notes?.contains(SessionModificationService.detachedFromInvoicedSeriesNote) == true)
    }

    @Test func thisAndFutureSplitFromInvoicedMasterStampsUninvoicedNote() async throws {
        let harness = try Harness()
        let calendar = Calendar(identifier: .gregorian)
        let seriesStart = calendar.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 10))!
        let seriesEnd = seriesStart.addingTimeInterval(3600)
        let splitDate = calendar.date(byAdding: .day, value: 3, to: seriesStart)!

        let client = Client(id: UUID(), ndisNumber: "4300000001", fullName: "Test Client", status: .active)
        let clientService = ClientService(serviceName: "Therapy", unit: "hour", rate: 193.99)
        clientService.client = client
        harness.context.insert(client)
        harness.context.insert(clientService)

        let originalRule = EKRecurrenceRule(
            recurrenceWith: .daily, interval: 1,
            daysOfTheWeek: nil,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil)
        let originalRuleData = try #require(harness.recurrenceRuleManager.serialize(originalRule))

        let invoice = Invoice(id: UUID(), invoiceNumber: "FUTURE-001")
        let master = Session(
            id: UUID(),
            title: "Invoiced Series",
            startTime: seriesStart,
            endTime: seriesEnd,
            status: .completed,
            recurrenceRuleData: originalRuleData
        )
        master.client = client
        master.clientService = clientService
        master.invoice = invoice
        harness.context.insert(invoice)
        harness.context.insert(master)
        try harness.context.save()

        var form = SessionFormModel(from: master, recurrenceRuleManager: harness.recurrenceRuleManager)
        form.startTime = splitDate
        form.endTime = splitDate.addingTimeInterval(3600)
        form.title = "Invoiced Series (future)"

        let newMasterID = try await harness.service.modifySession(
            sessionID: master.id,
            with: form,
            mode: .thisAndFuture,
            originalInstanceDate: splitDate
        )
        let newMaster = try harness.session(id: newMasterID)

        #expect(newMaster.id != master.id)
        #expect(newMaster.invoice == nil)
        #expect(newMaster.notes?.contains(SessionModificationService.detachedFromInvoicedSeriesNote) == true)
    }

    private func waitForSyncedSessionIDs(
        _ syncService: RecordingSyncService,
        expectedCount: Int
    ) async -> [UUID] {
        let deadline = TestClock.addingTimeInterval(2)
        while TestClock.now < deadline {
            let ids = syncService.snapshotSyncedIDs()
            if ids.count >= expectedCount {
                return ids
            }
            guard await Task.waitUnlessCancelled(nanoseconds: 20_000_000) else {
                return syncService.snapshotSyncedIDs()
            }
        }
        return syncService.snapshotSyncedIDs()
    }
}

// MARK: - Test doubles

@MainActor
private final class RecordingSyncService: SyncService {
    private var syncedSessionIDs: [UUID] = []

    var accessGranted: Bool { true }
    var syncEnabled: Bool { true }
    var lastSyncDate: Date? { nil }
    var syncStatus: SyncStatus { .idle }
    var availableCalendars: [CalendarInfo] { [] }
    var monitoredCalendarIdentifiers: Set<String> { [] }

    func snapshotSyncedIDs() -> [UUID] { syncedSessionIDs }

    func requestAccess() async throws -> Bool { true }
    func setSyncEnabled(_ enabled: Bool) async {}
    func sync(session: SessionSnapshot) async throws {
        syncedSessionIDs.append(session.id)
    }
    func delete(syncIdentifier: String) async throws {}
    func update(session: SessionSnapshot) async throws {}
    func fetchEvents(start: Date, end: Date) async throws -> [CalendarEvent] { [] }
    func updateSessionFromRemote(session: SessionSnapshot, remoteEvent: CalendarEvent) async throws -> SessionSnapshot {
        session
    }
    func handleExternalChanges() async throws {}
}

@MainActor
private final class StubCalendarEventService: CalendarEventService {
    var accessGranted: Bool { true }
    var accessGrantedPublisher: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }

    func fetchEvents(start: Date, end: Date) async -> [EKEvent] { [] }
    func delete(syncIdentifier: String, span: EKSpan) {}
    func getCalendars() -> [EKCalendar] { [] }
}
