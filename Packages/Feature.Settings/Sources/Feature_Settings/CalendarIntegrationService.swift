import Combine
import EventKit
import Data

@MainActor
public protocol CalendarIntegrationService: Sendable {
    var accessGranted: Bool { get }
    var availableCalendars: [EKCalendar] { get }
    var accessGrantedPublisher: AnyPublisher<Bool, Never> { get }
    var availableCalendarsPublisher: AnyPublisher<[EKCalendar], Never> { get }
    func requestAccess() async -> Bool
    func fetchAvailableCalendars() async
    func createCalendar(title: String, color: CGColor?) async throws
}

extension EventKitSyncService: CalendarIntegrationService {}
