import Core

enum SessionFormReadiness {
    static func message(for errors: [SessionFormModel.ValidationError]) -> String? {
        let actions = errors.map(\.readinessAction)
        guard !actions.isEmpty else { return nil }
        return "To save, \(naturalList(actions))."
    }

    private static func naturalList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            return "\(items.dropLast().joined(separator: ", ")), and \(items.last ?? "")"
        }
    }
}

extension SessionFormModel.ValidationError {
    var readinessAction: String {
        switch self {
        case .emptyTitle:
            "add a title"
        case .noClientSelected:
            "select a client"
        case .noServiceSelected:
            "select a service"
        case .invalidTimeRange:
            "set an end time after the start"
        case .invalidRecurrenceInterval:
            "set a recurrence interval above zero"
        case .noWeekdaysSelected:
            "select at least one weekday"
        case .invalidRecurrenceCount:
            "set a recurrence count above zero"
        case .invalidRecurrenceEndDate:
            "set recurrence to end after the session starts"
        }
    }
}

enum CalendarSessionStatusGuidance {
    static func message(for status: Core.SessionStatus, isInvoiced: Bool) -> String {
        if isInvoiced {
            return "This session is linked to an invoice. Status changes do not update that invoice."
        }

        switch status {
        case .scheduled:
            return "Scheduled sessions stay in Calendar until marked Completed."
        case .completed:
            return "Saving as Completed makes this session available in Billing Hub. Add travel afterward from Calendar or Billing Hub."
        case .cancelled:
            return "Cancelled sessions stay out of billing preparation."
        case .noShow:
            return "No Show sessions stay out of billing preparation."
        case .rescheduled:
            return "Rescheduled sessions stay in Calendar and out of billing preparation."
        case .grouped, .needsTravel, .reviewDraft, .readyToSend, .pending, .received:
            return "Billing Hub manages this workflow status. Return there to move the session or invoice."
        }
    }

    static func isBillingManaged(_ status: Core.SessionStatus) -> Bool {
        switch status {
        case .scheduled, .completed, .cancelled, .noShow, .rescheduled:
            return false
        case .grouped, .needsTravel, .reviewDraft, .readyToSend, .pending, .received:
            return true
        }
    }
}
