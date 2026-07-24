import Combine
import EventKit

@MainActor
public protocol CalendarEventService: Sendable {
    var accessGranted: Bool { get }
    var accessGrantedPublisher: AnyPublisher<Bool, Never> { get }
    func fetchEvents(start: Date, end: Date) async -> [EKEvent]
    func delete(syncIdentifier: String, span: EKSpan)
    func getCalendars() -> [EKCalendar]
}
