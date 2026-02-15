import CoreGraphics
import Foundation

enum SplitViewShellStyle {
    case workspacePlusContentDetail
    case workspacePlusDetail
}

struct SplitViewColumnWidthProfile {
    let min: CGFloat
    let ideal: CGFloat
    let max: CGFloat
}

struct SplitViewWidthProfile {
    let sidebar: SplitViewColumnWidthProfile
    let content: SplitViewColumnWidthProfile?
    let detail: SplitViewColumnWidthProfile
}

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case invoices
    case billingHub
    case invoiceTemplateEditor
    case relationships
    case calendar
    case ndisCatalogue
    case settings
    // Old comments removed; this file now only provides tab metadata

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .invoices:
            return "Invoices"
        case .billingHub:
            return "Billing Hub"
        case .invoiceTemplateEditor:
            return "Template Editor"
        case .relationships:
            return "Relationships"
        case .calendar:
            return "Calendar"
        case .ndisCatalogue:
            return "NDIS Catalogue"
        case .settings:
            return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .invoices:
            return "doc.text"
        case .billingHub:
            return "square.grid.3x2"
        case .invoiceTemplateEditor:
            return "doc.richtext"
        case .relationships:
            return "person.2"
        case .calendar:
            return "calendar"
        case .ndisCatalogue:
            return "list.bullet.rectangle"
        case .settings:
            return "gearshape"
        }
    }

    var splitStyle: SplitViewShellStyle {
        switch self {
        case .invoices, .relationships, .ndisCatalogue, .settings:
            return .workspacePlusContentDetail
        default:
            return .workspacePlusDetail
        }
    }

    var widthProfile: SplitViewWidthProfile {
        switch self {
        case .settings:
            return SplitViewWidthProfile(
                sidebar: Self.defaultSidebarWidth,
                content: SplitViewColumnWidthProfile(min: 300, ideal: 360, max: 360),
                detail: Self.defaultDetailWidthThreeColumn
            )

        case .billingHub:
            return SplitViewWidthProfile(
                sidebar: Self.defaultSidebarWidth,
                content: nil,
                detail: SplitViewColumnWidthProfile(min: 880, ideal: 1180, max: .infinity)
            )

        case .invoiceTemplateEditor:
            return SplitViewWidthProfile(
                sidebar: Self.defaultSidebarWidth,
                content: nil,
                detail: SplitViewColumnWidthProfile(min: 900, ideal: 1200, max: .infinity)
            )

        case .ndisCatalogue:
            return SplitViewWidthProfile(
                sidebar: Self.defaultSidebarWidth,
                content: SplitViewColumnWidthProfile(min: 560, ideal: 760, max: .infinity),
                detail: SplitViewColumnWidthProfile(min: 320, ideal: 420, max: 520)
            )

        case .invoices, .relationships:
            return SplitViewWidthProfile(
                sidebar: Self.defaultSidebarWidth,
                content: Self.defaultContentWidth,
                detail: Self.defaultDetailWidthThreeColumn
            )

        case .calendar:
            return SplitViewWidthProfile(
                sidebar: Self.defaultSidebarWidth,
                content: nil,
                detail: Self.defaultDetailWidthTwoColumn
            )
        }
    }

    private static let defaultSidebarWidth = SplitViewColumnWidthProfile(
        min: 220,
        ideal: 260,
        max: 320
    )

    private static let defaultContentWidth = SplitViewColumnWidthProfile(
        min: 300,
        ideal: 360,
        max: 460
    )

    private static let defaultDetailWidthThreeColumn = SplitViewColumnWidthProfile(
        min: 520,
        ideal: 760,
        max: .infinity
    )

    private static let defaultDetailWidthTwoColumn = SplitViewColumnWidthProfile(
        min: 760,
        ideal: 1100,
        max: .infinity
    )
}
