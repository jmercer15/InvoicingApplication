#if DEBUG
import Combine
import Core
import Data
import EventKit
import SwiftData
import SwiftUI

private struct PreviewSyncService: SyncService {
    var accessGranted: Bool { true }
    var syncEnabled: Bool { false }
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
    func updateSessionFromRemote(session: SessionSnapshot, remoteEvent: CalendarEvent) async throws -> SessionSnapshot { session }
    func handleExternalChanges() async throws {}
}

@MainActor
private final class PreviewCalendarEventService: CalendarEventService {
    var accessGranted: Bool { true }
    var accessGrantedPublisher: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }

    func fetchEvents(start: Date, end: Date) async -> [EKEvent] { [] }
    func delete(syncIdentifier: String, span: EKSpan) {}
    func getCalendars() -> [EKCalendar] { [] }
}

@MainActor
enum CalendarPreviewSupport {
    static func makeContainer() -> ModelContainer {
        try! ModelContainerFactory.makeInMemoryContainer()
    }

    static func makeViewModel(
        container: ModelContainer,
        viewType: CalendarViewType = .week
    ) -> CalendarViewModel {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return CalendarViewModel(
            modelContext: context,
            modelContainer: container,
            syncService: PreviewSyncService(),
            eventKitService: PreviewCalendarEventService(),
            recurrenceRuleManager: RecurrenceRuleManager(),
            selectedDate: Date(timeIntervalSinceReferenceDate: 773_280_000),
            calendarViewType: viewType
        )
    }
}

#Preview("Calendar Content") {
    let container = CalendarPreviewSupport.makeContainer()
    let viewModel = CalendarPreviewSupport.makeViewModel(container: container)

    NavigationStack {
        CalendarContentColumn(viewModel: viewModel)
    }
    .modelContainer(container)
    .frame(width: 980, height: 620)
}

#Preview("Calendar Month") {
    let container = CalendarPreviewSupport.makeContainer()
    let viewModel = CalendarPreviewSupport.makeViewModel(container: container, viewType: .month)

    CalendarTabView(viewModel: viewModel)
        .modelContainer(container)
        .frame(width: 980, height: 620)
}
#endif
