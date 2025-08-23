import Foundation

enum RecurringEditMode: CaseIterable {
    case thisOnly
    case thisAndFuture
    case all
}

enum RecurringModificationType {
    case move(newStartTime: Date)
    case resize(newStartTime: Date, newEndTime: Date)
} 