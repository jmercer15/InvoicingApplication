//
//  WorkspaceCommandActionsKey.swift
//  InvoicingApplication
//
//  Focused scene value for app-level menu commands (New Invoice, New Session, Go to tab).
//

import SwiftUI
import Core
import Observation

struct WorkspaceCommandAvailability: Equatable {
    let selectedTab: AppTab
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let canCreateNewInvoice: Bool
    let canCreateNewSession: Bool
    let canToggleInspector: Bool
}

/// Actions available to the app command layer when the workspace window is focused.
@Observable
final class WorkspaceCommandActions {
    @ObservationIgnored private var availability: WorkspaceCommandAvailability
    var switchToTab: (AppTab) -> Void
    var navigateBack: () -> Void
    var navigateForward: () -> Void
    var createNewInvoice: (() -> Void)?
    var createNewSession: (() -> Void)?
    var toggleInspector: (() -> Void)?
    var canSwitchToTab: (AppTab) -> Bool
    var canNavigateBack: () -> Bool
    var canNavigateForward: () -> Bool
    var canCreateNewInvoice: Bool
    var canCreateNewSession: Bool
    var canToggleInspector: Bool

    init(
        availability: WorkspaceCommandAvailability,
        switchToTab: @escaping (AppTab) -> Void,
        navigateBack: @escaping () -> Void = {},
        navigateForward: @escaping () -> Void = {},
        createNewInvoice: (() -> Void)? = nil,
        createNewSession: (() -> Void)? = nil,
        toggleInspector: (() -> Void)? = nil,
        canSwitchToTab: @escaping (AppTab) -> Bool = { _ in true },
        canNavigateBack: @escaping () -> Bool = { false },
        canNavigateForward: @escaping () -> Bool = { false },
        canCreateNewInvoice: Bool = true,
        canCreateNewSession: Bool = true,
        canToggleInspector: Bool = true
    ) {
        self.availability = availability
        self.switchToTab = switchToTab
        self.navigateBack = navigateBack
        self.navigateForward = navigateForward
        self.createNewInvoice = createNewInvoice
        self.createNewSession = createNewSession
        self.toggleInspector = toggleInspector
        self.canSwitchToTab = canSwitchToTab
        self.canNavigateBack = canNavigateBack
        self.canNavigateForward = canNavigateForward
        self.canCreateNewInvoice = canCreateNewInvoice
        self.canCreateNewSession = canCreateNewSession
        self.canToggleInspector = canToggleInspector
    }

    /// Refreshes only command values whose semantic availability changed. Action endpoints are
    /// fixed for one workspace composition, so rebuilding them on every route observer would
    /// create redundant focused-value publications during one navigation frame.
    @discardableResult
    func apply(_ source: WorkspaceCommandActions) -> Bool {
        let previous = availability
        let next = source.availability
        guard previous != next else { return false }

        if previous.selectedTab != next.selectedTab {
            canSwitchToTab = source.canSwitchToTab
        }
        if previous.canNavigateBack != next.canNavigateBack {
            canNavigateBack = source.canNavigateBack
        }
        if previous.canNavigateForward != next.canNavigateForward {
            canNavigateForward = source.canNavigateForward
        }
        if canCreateNewInvoice != source.canCreateNewInvoice {
            canCreateNewInvoice = source.canCreateNewInvoice
        }
        if canCreateNewSession != source.canCreateNewSession {
            canCreateNewSession = source.canCreateNewSession
        }
        if canToggleInspector != source.canToggleInspector {
            canToggleInspector = source.canToggleInspector
        }
        availability = next
        return true
    }
}

private struct WorkspaceCommandActionsKey: FocusedValueKey {
    typealias Value = WorkspaceCommandActions
}

extension FocusedValues {
    var workspaceCommandActions: WorkspaceCommandActions? {
        get { self[WorkspaceCommandActionsKey.self] }
        set { self[WorkspaceCommandActionsKey.self] = newValue }
    }
}
