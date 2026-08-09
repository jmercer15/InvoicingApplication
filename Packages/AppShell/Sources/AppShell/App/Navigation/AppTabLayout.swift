//
//  AppTabs.swift
//  InvoicingApplication
//
//  Workspace layout types and AppTab (Core) extension for split style and column widths.
//

import Core
import CoreGraphics
import Foundation

// MARK: - Layout types (app-specific)

enum SplitViewShellStyle {
    case workspacePlusContentDetail
    case workspacePlusDetail
}

struct SplitViewColumnWidthProfile {
    let min: CGFloat
    let ideal: CGFloat
    /// Upper bound for split resize; `nil` omits `max` on `navigationSplitViewColumnWidth` / `inspectorColumnWidth` (no artificial cap).
    let max: CGFloat?
}

struct SplitViewWidthProfile {
    let sidebar: SplitViewColumnWidthProfile
    let content: SplitViewColumnWidthProfile?
    let detail: SplitViewColumnWidthProfile
}

// MARK: - AppTab layout extension (single source of truth: Core.AppTab)

extension AppTab {
    /// Invoice workspaces own purpose-built inspectors inside their editor hierarchy. App shell
    /// must not add its generic inspector beside them.
    var usesIntegratedInvoiceEditorInspector: Bool {
        self == .invoices || self == .invoiceTemplateEditor
    }

    /// Drives `NavigationSplitView` shape in `ContentView`: two-column (sidebar + detail) vs three-column (+ list).
    var splitStyle: SplitViewShellStyle {
        switch self {
        case .invoices, .relationships, .ndisCatalogue:
            return .workspacePlusContentDetail
        case .billingHub, .invoiceTemplateEditor, .calendar:
            return .workspacePlusDetail
        }
    }

    var widthProfile: SplitViewWidthProfile {
        switch self {
        case .billingHub:
            return SplitViewWidthProfile(
                sidebar: Self.defaultSidebarWidth,
                content: Self.collapsedContentWidth,
                detail: SplitViewColumnWidthProfile(min: 560, ideal: 1180, max: nil)
            )
        case .invoiceTemplateEditor:
            return SplitViewWidthProfile(
                sidebar: Self.defaultSidebarWidth,
                content: Self.collapsedContentWidth,
                detail: SplitViewColumnWidthProfile(min: 600, ideal: 1200, max: nil)
            )
        case .ndisCatalogue:
            return SplitViewWidthProfile(
                sidebar: Self.defaultSidebarWidth,
                content: SplitViewColumnWidthProfile(min: 280, ideal: 640, max: nil),
                detail: SplitViewColumnWidthProfile(min: 280, ideal: 420, max: nil)
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
                content: Self.collapsedContentWidth,
                detail: Self.defaultDetailWidthTwoColumn
            )
        }
    }

    private static let defaultSidebarWidth = SplitViewColumnWidthProfile(
        min: 200,
        ideal: 260,
        max: 280
    )
    /// Zero-width content column for tabs that render sidebar + detail only.
    private static let collapsedContentWidth = SplitViewColumnWidthProfile(
        min: 0,
        ideal: 0,
        max: 0
    )
    private static let defaultContentWidth = SplitViewColumnWidthProfile(
        min: 260,
        ideal: 360,
        max: nil
    )
    private static let defaultDetailWidthThreeColumn = SplitViewColumnWidthProfile(
        min: 400,
        ideal: 760,
        max: nil
    )
    private static let defaultDetailWidthTwoColumn = SplitViewColumnWidthProfile(
        min: 480,
        ideal: 1100,
        max: nil
    )
}
