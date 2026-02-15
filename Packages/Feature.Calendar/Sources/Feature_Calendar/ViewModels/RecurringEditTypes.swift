import Foundation

enum RecurringEditMode: CaseIterable {
    case thisOnly
    case thisAndFuture
    case all

    var title: String {
        switch self {
        case .thisOnly:
            return "This Event Only"
        case .thisAndFuture:
            return "This and Future Events"
        case .all:
            return "All Events in Series"
        }
    }

    var iconName: String {
        switch self {
        case .thisOnly:
            return "smallcircle.filled.circle"
        case .thisAndFuture:
            return "arrow.right.circle"
        case .all:
            return "rectangle.3.group"
        }
    }

    func detailText(isDelete: Bool) -> String {
        switch self {
        case .thisOnly:
            return isDelete ? "Delete only the selected occurrence." : "Apply changes only to this occurrence."
        case .thisAndFuture:
            return isDelete ? "Delete this occurrence and everything after it." : "Apply changes from this point forward."
        case .all:
            return isDelete ? "Delete every occurrence in the series." : "Apply changes to the entire series."
        }
    }
}

enum RecurringModificationType {
    case move(newStartTime: Date)
    case resize(newStartTime: Date, newEndTime: Date)
} 
