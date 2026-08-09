import SwiftUI
import EventKit
import Core
import PersistenceModels

@MainActor
enum SessionWeekContextMenu {
    struct Symbols {
        var viewDetails: String = "info.circle"
        var markCompleted: String = "checkmark.circle.fill"
        var markCancelled: String = "xmark.circle.fill"
        var markScheduled: String = "calendar"
        var duplicate: String = "plus.square.on.square.fill"
        var travel: String = "car.fill"
        var delete: String = "trash.fill"
    }

    static func isCalendarLifecycleStatus(_ token: String?) -> Bool {
        switch token {
        case "scheduled", "completed", "cancelled", "no_show", "rescheduled":
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    static func sessionMenu(
        session: Session,
        itemStartDate: Date?,
        itemEndDate: Date?,
        viewModel: CalendarViewModel,
        onViewDetails: @escaping () -> Void,
        symbols: Symbols = Symbols()
    ) -> some View {
        let statusToken = Core.SessionStatus(normalized: session.status?.rawValue ?? "")?.token
        let isCompleted = statusToken == Core.SessionStatus.completed.token
        let isCancelled = statusToken == Core.SessionStatus.cancelled.token
        let canEditCalendarStatus = isCalendarLifecycleStatus(statusToken)

        Button(action: onViewDetails) {
            Label("View Details", systemImage: symbols.viewDetails)
        }

        if canEditCalendarStatus {
            if !isCompleted && !isCancelled {
                Divider()
                Button {
                    markSession(session, as: .completed, viewModel: viewModel)
                } label: {
                    Label("Mark as Completed", systemImage: symbols.markCompleted)
                }
                Button {
                    markSession(session, as: .cancelled, viewModel: viewModel)
                } label: {
                    Label("Mark as Cancelled", systemImage: symbols.markCancelled)
                }
            }

            if isCompleted || isCancelled {
                Divider()
                Button {
                    markSession(session, as: .scheduled, viewModel: viewModel)
                } label: {
                    Label("Mark as Scheduled", systemImage: symbols.markScheduled)
                }
            }
        }

        Divider()

        Button {
            if !viewModel.isBulkSelectionMode {
                viewModel.toggleBulkSelectionMode()
            }
            viewModel.toggleSelection(for: session.id)
        } label: {
            Label("Select Multiple...", systemImage: "checklist")
        }

        Button {
            viewModel.duplicateSession(session)
        } label: {
            Label("Duplicate Session", systemImage: symbols.duplicate)
        }

        if !session.isTravel {
            Button {
                viewModel.presentTravelCharge(
                    for: session,
                    instanceStart: itemStartDate ?? Date(),
                    instanceEnd: itemEndDate ?? Date()
                )
            } label: {
                Label("Add Travel Charges", systemImage: symbols.travel)
            }
        }

        Button(role: .destructive) {
            Task { @MainActor in
                await viewModel.deleteSessionFromCalendar(sessionID: session.id)
            }
        } label: {
            Label("Delete Session...", systemImage: symbols.delete)
        }
    }

    @ViewBuilder
    static func convertEventMenu(
        event: EKEvent,
        viewModel: CalendarViewModel
    ) -> some View {
        Button {
            viewModel.convertEventToSession(event)
        } label: {
            Label("Convert to Session", systemImage: "arrow.right.circle.fill")
        }
    }

    private static func markSession(
        _ session: Session,
        as status: Core.SessionStatus,
        viewModel: CalendarViewModel
    ) {
        guard isCalendarLifecycleStatus(
            Core.SessionStatus(normalized: session.status?.rawValue ?? "")?.token
        ) else {
            return
        }
        Task { @MainActor in
            await viewModel.markSession(session, as: status)
        }
    }
}
