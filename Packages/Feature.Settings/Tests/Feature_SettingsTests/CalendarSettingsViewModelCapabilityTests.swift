import Combine
import Core
import DataInterfaces
import EventKit
@testable import Feature_Settings
import Testing

@MainActor
@Suite struct CalendarSettingsViewModelCapabilityTests {
    @Test func CalendarIdentifierEqualityIncludesCalendarIdentifierAndTitle() {
        let first = CalendarSettingsViewModel.CalendarIdentifier(id: "cal-1", title: "Work")
        let renamed = CalendarSettingsViewModel.CalendarIdentifier(id: "cal-1", title: "Work Renamed")
        let other = CalendarSettingsViewModel.CalendarIdentifier(id: "cal-2", title: "Personal")

        #expect(first != renamed)
        #expect(first != other)

        let set: Set<CalendarSettingsViewModel.CalendarIdentifier> = [first, renamed, other]
        #expect(set.count == 3)
    }

    @Test func ClearAllSessionsDelegatesToSessionWiper() async {
        let wiper = MockCalendarSessionWiper()
        let viewModel = CalendarSettingsViewModel(
            preferencesStore: CalendarPreferencesStore(),
            eventKitService: MockCalendarIntegrationService(),
            sessionWiper: wiper
        )

        await viewModel.clearAllSessions()

        #expect(wiper.wipeCallCount == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func ClearAllSessionsSurfacesWiperFailure() async {
        let wiper = MockCalendarSessionWiper(shouldFail: true)
        let viewModel = CalendarSettingsViewModel(
            preferencesStore: CalendarPreferencesStore(),
            eventKitService: MockCalendarIntegrationService(),
            sessionWiper: wiper
        )

        await viewModel.clearAllSessions()

        #expect(wiper.wipeCallCount == 1)
        #expect(viewModel.errorMessage?.contains("Failed to delete sessions") == true)
    }
}

@MainActor
private final class MockCalendarIntegrationService: CalendarIntegrationService {
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

@MainActor
private final class MockCalendarSessionWiper: CalendarSessionWiping {
    let shouldFail: Bool
    private(set) var wipeCallCount = 0

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func wipeAllSessions() async throws {
        wipeCallCount += 1
        if shouldFail {
            throw NSError(domain: "MockCalendarSessionWiper", code: 1)
        }
    }
}
