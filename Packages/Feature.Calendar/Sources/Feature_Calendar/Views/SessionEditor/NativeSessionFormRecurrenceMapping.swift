import Foundation

/// Maps persisted recurrence fields to the simplified repeat dropdown.
enum NativeSessionFormRecurrenceMapping {
    static func repeatPickerValue(for model: SessionFormModel) -> RepeatOption? {
        switch model.recurrenceFrequency {
        case .none:
            return .never
        case .daily:
            return model.recurrenceInterval == 1 ? .everyDay : .custom
        case .weekly:
            if model.recurrenceInterval == 1 {
                return .everyWeek
            } else if model.recurrenceInterval == 2 {
                return .every2Weeks
            } else {
                return .custom
            }
        case .monthly:
            return model.recurrenceInterval == 1 ? .everyMonth : .custom
        case .yearly:
            return model.recurrenceInterval == 1 ? .everyYear : .custom
        }
    }
}
