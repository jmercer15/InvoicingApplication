//
//  ToolWindowContextKey.swift
//  AppShell
//
//  Focused scene values for utility tool windows (Inspector, Activity).
//

import SwiftUI

/// Scene-local presentation state for a utility tool window, published via focused scene values.
@Observable
@MainActor
final class ToolWindowContext {
    enum Kind: Equatable, Sendable {
        case standaloneInspector
        case activityMonitor
    }

    let kind: Kind
    var isOpen: Bool

    init(kind: Kind, isOpen: Bool = false) {
        self.kind = kind
        self.isOpen = isOpen
    }
}

/// Combines split-column and standalone inspector visibility for workspace UI decisions.
struct InspectorPresentationState: Equatable {
    var splitPresented = false
    var standaloneOpen = false

    var isVisible: Bool {
        splitPresented || standaloneOpen
    }
}

private struct ToolWindowContextKey: FocusedValueKey {
    typealias Value = ToolWindowContext
}

private struct WorkspaceInspectorSplitPresentedKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var toolWindowContext: ToolWindowContext? {
        get { self[ToolWindowContextKey.self] }
        set { self[ToolWindowContextKey.self] = newValue }
    }

    var workspaceInspectorSplitPresented: Bool? {
        get { self[WorkspaceInspectorSplitPresentedKey.self] }
        set { self[WorkspaceInspectorSplitPresentedKey.self] = newValue }
    }
}
