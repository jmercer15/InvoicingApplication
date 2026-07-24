import SwiftUI

enum NavigationSplitViewStateCodec {
    static func encodeColumnVisibility(_ value: NavigationSplitViewVisibility) -> String {
        switch value {
        case .all:
            return "all"
        case .doubleColumn:
            return "doubleColumn"
        case .detailOnly:
            return "detailOnly"
        case .automatic:
            return "automatic"
        default:
            return "automatic"
        }
    }

    static func decodeColumnVisibility(_ rawValue: String) -> NavigationSplitViewVisibility {
        switch rawValue {
        case "all":
            return .all
        case "doubleColumn":
            return .doubleColumn
        case "detailOnly":
            return .detailOnly
        default:
            return .automatic
        }
    }

    static func encodePreferredCompactColumn(_ value: NavigationSplitViewColumn) -> String {
        if value == .sidebar {
            return "sidebar"
        }
        if value == .content {
            return "content"
        }
        if value == .detail {
            return "detail"
        }
        return "detail"
    }

    static func decodePreferredCompactColumn(
        _ rawValue: String,
        fallback: NavigationSplitViewColumn
    ) -> NavigationSplitViewColumn {
        switch rawValue {
        case "sidebar":
            return .sidebar
        case "content":
            return .content
        case "detail":
            return .detail
        default:
            return fallback
        }
    }
}
