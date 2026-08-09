import PersistenceModels
import Foundation

/// Travel charge sheet presentation state, extracted from ``CalendarViewModel``.
@MainActor
@Observable
final class CalendarTravelPresentation {
    var isShowingSheet = false
    var selectedSession: Session?
    var selectedInstanceStartDate: Date?
    var selectedInstanceEndDate: Date?
    var daySessions: [DisplayableCalendarItem] = []

    func present(
        for session: Session,
        instanceStart: Date,
        instanceEnd: Date,
        daySessionsProvider: (Session, Date) -> [DisplayableCalendarItem]
    ) {
        selectedSession = session
        selectedInstanceStartDate = instanceStart
        selectedInstanceEndDate = instanceEnd
        daySessions = daySessionsProvider(session, instanceStart)
        isShowingSheet = true
    }

    func dismiss() {
        isShowingSheet = false
        selectedSession = nil
        selectedInstanceStartDate = nil
        selectedInstanceEndDate = nil
        daySessions = []
    }
}
