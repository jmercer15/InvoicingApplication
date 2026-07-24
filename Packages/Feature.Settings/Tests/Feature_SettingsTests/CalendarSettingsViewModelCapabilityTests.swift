import Core
import Combine
import Data
import EventKit
@testable import Feature_Settings
import SwiftData
import XCTest

@MainActor
final class CalendarSettingsViewModelCapabilityTests: XCTestCase {
    func testCalendarIdentifierEqualityIncludesCalendarIdentifierAndTitle() {
        let first = CalendarSettingsViewModel.CalendarIdentifier(id: "cal-1", title: "Work")
        let renamed = CalendarSettingsViewModel.CalendarIdentifier(id: "cal-1", title: "Work Renamed")
        let other = CalendarSettingsViewModel.CalendarIdentifier(id: "cal-2", title: "Personal")

        XCTAssertNotEqual(first, renamed)
        XCTAssertNotEqual(first, other)

        let set: Set<CalendarSettingsViewModel.CalendarIdentifier> = [first, renamed, other]
        XCTAssertEqual(set.count, 3)
    }

    func testClearAllSessionsPreservesDisabledAutosavePolicy() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        context.insert(Session(title: "Session to clear"))
        try context.save()
        let viewModel = CalendarSettingsViewModel(
            modelContext: context,
            preferencesStore: CalendarPreferencesStore(),
            eventKitService: MockCalendarIntegrationService()
        )

        await viewModel.clearAllSessions()

        let remainingSessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertTrue(remainingSessions.isEmpty)
        XCTAssertFalse(context.autosaveEnabled)
    }

    func testClearAllSessionsRestoresPriorAutosaveValue() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = true
        context.insert(Session(title: "Session to clear"))
        try context.save()
        let viewModel = CalendarSettingsViewModel(
            modelContext: context,
            preferencesStore: CalendarPreferencesStore(),
            eventKitService: MockCalendarIntegrationService()
        )

        await viewModel.clearAllSessions()

        let remainingSessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertTrue(remainingSessions.isEmpty)
        XCTAssertTrue(context.autosaveEnabled)
    }
}

@MainActor
private final class MockCalendarIntegrationService: CalendarIntegrationService, @unchecked Sendable {
    var accessGranted = false
    var availableCalendars: [EKCalendar] = []

    var accessGrantedPublisher: AnyPublisher<Bool, Never> {
        Just(accessGranted).eraseToAnyPublisher()
    }

    var availableCalendarsPublisher: AnyPublisher<[EKCalendar], Never> {
        Just(availableCalendars).eraseToAnyPublisher()
    }

    func requestAccess() async -> Bool {
        accessGranted
    }

    func fetchAvailableCalendars() async {}

    func createCalendar(title _: String, color _: CGColor?) async throws {}
}
