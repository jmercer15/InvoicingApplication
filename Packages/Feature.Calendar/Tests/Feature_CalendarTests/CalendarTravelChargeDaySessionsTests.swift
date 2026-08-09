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
struct CalendarTravelChargeDaySessionsTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @Test func daySessionsForTravelFiltersSameClientSameDayNonTravel() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = makeViewModel(context: context, container: container)

        let client = Client(id: UUID(), ndisNumber: "1", fullName: "Alex", status: "Active")
        context.insert(client)

        let day = Calendar.current.startOfDay(for: Date())
        let mainSession = Session()
        mainSession.client = client
        mainSession.startTime = day.addingTimeInterval(3_600)
        mainSession.endTime = day.addingTimeInterval(7_200)
        mainSession.title = "Main"

        let sameDayPeer = Session()
        sameDayPeer.client = client
        sameDayPeer.startTime = day.addingTimeInterval(10_800)
        sameDayPeer.endTime = day.addingTimeInterval(14_400)
        sameDayPeer.title = "Peer"

        let travelSession = Session()
        travelSession.client = client
        travelSession.isTravel = true
        travelSession.startTime = day.addingTimeInterval(15_000)
        travelSession.endTime = day.addingTimeInterval(16_000)

        let otherClient = Client(id: UUID(), ndisNumber: "2", fullName: "Sam", status: "Active")
        context.insert(otherClient)
        let otherClientSession = Session()
        otherClientSession.client = otherClient
        otherClientSession.startTime = day.addingTimeInterval(18_000)
        otherClientSession.endTime = day.addingTimeInterval(19_000)

        viewModel.timedItems = [
            .session(mainSession),
            .session(sameDayPeer),
            .session(travelSession),
            .session(otherClientSession),
        ]

        let filtered = viewModel.daySessionsForTravel(mainSession: mainSession, on: day)

        #expect(filtered.count == 2)
        #expect(filtered.contains(where: { $0.underlyingSession?.id == mainSession.id }))
        #expect(filtered.contains(where: { $0.underlyingSession?.id == sameDayPeer.id }))
    }

    @Test func presentTravelChargeStoresPrecomputedDaySessions() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = makeViewModel(context: context, container: container)

        let client = Client(id: UUID(), ndisNumber: "1", fullName: "Alex", status: "Active")
        context.insert(client)

        let day = Calendar.current.startOfDay(for: Date())
        let session = Session()
        session.client = client
        session.startTime = day.addingTimeInterval(3_600)
        session.endTime = day.addingTimeInterval(7_200)
        viewModel.timedItems = [.session(session)]

        viewModel.presentTravelCharge(
            for: session, instanceStart: day,
            instanceEnd: day.addingTimeInterval(7_200))

        #expect(viewModel.isShowingTravelChargeSheet)
        #expect(viewModel.travelChargeDaySessions.count == 1)
        #expect(viewModel.selectedSessionForTravel?.id == session.id)

        viewModel.dismissTravelChargePresentation()
        #expect(!(viewModel.isShowingTravelChargeSheet))
        #expect(viewModel.travelChargeDaySessions.isEmpty)
    }

    private func makeViewModel(context: ModelContext, container: ModelContainer) -> CalendarViewModel {
        CalendarViewModel(
            modelContext: context, modelContainer: container,
            syncService: IdleSyncService(),
            eventKitService: EmptyCalendarEventService(),
            recurrenceRuleManager: RecurrenceRuleManager()
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
