//
//  AppToolbarComponents.swift
//  SharedUI
//
//  Shared toolbar controls and label helpers used across workspace features.
//

import SwiftUI

// MARK: - Label helpers

public enum AppToolbarMenuLabel {
    /// `Filter` or `Filter (2)` when count is positive.
    public static func withCount(_ base: String, count: Int) -> String {
        count > 0 ? "\(base) (\(count))" : base
    }

    /// `Category` or `Category (1)` when a single filter is active.
    public static func withActiveFlag(_ base: String, isActive: Bool) -> String {
        isActive ? "\(base) (1)" : base
    }
}

// MARK: - View styling

private struct AppToolbarLinkStyleModifier: ViewModifier {
    let help: String?

    func body(content: Content) -> some View {
        if let help {
            content.help(help).pointerStyle(.link)
        } else {
            content.pointerStyle(.link)
        }
    }
}

extension View {
    /// Icon-only labels in macOS toolbars (Apple toolbar density guidance).
    @ViewBuilder
    public func appToolbarCompactLabelStyle() -> some View {
        #if os(macOS)
        self.labelStyle(.iconOnly)
        #else
        self
        #endif
    }

    /// Standard link pointer + optional help for toolbar icon/menu controls.
    /// Set `compactLabels` to `false` for primary actions that should keep visible titles (e.g. “New Invoice”).
    @ViewBuilder
    public func appToolbarLinkStyle(help: String? = nil, compactLabels: Bool = true) -> some View {
        Group {
            if compactLabels {
                appToolbarCompactLabelStyle()
            } else {
                self
            }
        }
        .modifier(AppToolbarLinkStyleModifier(help: help))
    }

    /// Prominent system glass style for primary create actions in list toolbars.
    public func appToolbarPrimaryCreateStyle() -> some View {
        buttonStyle(.glassProminent)
    }
}

// MARK: - Buttons

public struct AppToolbarPrimaryCreateButton: View {
    private let title: String
    private let systemImage: String
    private let help: String
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String = "plus",
        help: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .appToolbarPrimaryCreateStyle()
        .appToolbarLinkStyle(help: help, compactLabels: false)
    }
}

public struct AppToolbarIconButton: View {
    private let systemName: String
    private let accessibilityLabel: String
    private let help: String?
    private let isDisabled: Bool
    private let action: () -> Void

    public init(
        systemName: String,
        accessibilityLabel: String? = nil,
        help: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel ?? help ?? "Toolbar action"
        self.help = help
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(accessibilityLabel, systemImage: systemName, action: action)
            .disabled(isDisabled)
            .appToolbarLinkStyle(help: help)
    }
}

public struct AppToolbarToggleButton: View {
    private let systemName: String
    private let isOn: Bool
    private let help: String
    private let action: () -> Void

    public init(
        systemName: String,
        isOn: Bool,
        help: String,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.isOn = isOn
        self.help = help
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(help, systemImage: systemName)
                .symbolVariant(isOn ? .fill : .none)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
        }
        .appToolbarLinkStyle(help: help)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

public struct AppToolbarSheetCancellationButton: View {
    private let title: String
    private let isDisabled: Bool
    private let action: () -> Void

    public init(
        _ title: String = "Cancel",
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(title, role: .cancel, action: action)
            .disabled(isDisabled)
    }
}

public struct AppToolbarSheetConfirmationButton: View {
    private let title: String
    private let isDisabled: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)
    }
}

/// Standard overflow menu for secondary/detail actions (`ellipsis.circle`).
public struct AppToolbarActionsMenu<MenuContent: View>: View {
    private let title: String
    private let systemImage: String
    private let help: String
    private let menuContent: MenuContent

    public init(
        title: String = "Actions",
        systemImage: String = "ellipsis.circle",
        help: String = "More actions",
        @ViewBuilder content: () -> MenuContent
    ) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.menuContent = content()
    }

    public var body: some View {
        Menu {
            menuContent
        } label: {
            Label(title, systemImage: systemImage)
        }
        .appToolbarLinkStyle(help: help)
    }
}

/// Dismiss-only sheet toolbar (`cancellationAction` placement).
public struct AppToolbarSheetDismissBar: ToolbarContent {
    private let title: String
    private let isCancellation: Bool
    private let action: () -> Void

    public init(
        _ title: String = "Done",
        isCancellation: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isCancellation = isCancellation
        self.action = action
    }

    public var body: some ToolbarContent {
        if isCancellation {
            ToolbarItem(placement: .cancellationAction) {
                AppToolbarSheetCancellationButton(title, action: action)
                #if os(macOS)
                .keyboardShortcut(.cancelAction)
                #endif
            }
        } else {
            ToolbarItem(placement: .confirmationAction) {
                AppToolbarSheetConfirmationButton(title, action: action)
                #if os(macOS)
                .keyboardShortcut(.defaultAction)
                #endif
            }
        }
    }
}

/// Sheet toolbar with `cancellationAction` + `confirmationAction` placements (Apple HIG).
public struct AppToolbarSheetBar: ToolbarContent {
    private let cancelTitle: String
    private let confirmTitle: String
    private let showsCancel: Bool
    private let isCancelDisabled: Bool
    private let isConfirmDisabled: Bool
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    public init(
        cancelTitle: String = "Cancel",
        confirmTitle: String,
        showsCancel: Bool = true,
        isCancelDisabled: Bool = false,
        isConfirmDisabled: Bool = false,
        onCancel: @escaping () -> Void = {},
        onConfirm: @escaping () -> Void
    ) {
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.showsCancel = showsCancel
        self.isCancelDisabled = isCancelDisabled
        self.isConfirmDisabled = isConfirmDisabled
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some ToolbarContent {
        if showsCancel {
            ToolbarItem(placement: .cancellationAction) {
                AppToolbarSheetCancellationButton(
                    cancelTitle,
                    isDisabled: isCancelDisabled,
                    action: onCancel
                )
                #if os(macOS)
                .keyboardShortcut(.cancelAction)
                #endif
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            AppToolbarSheetConfirmationButton(
                confirmTitle,
                isDisabled: isConfirmDisabled,
                action: onConfirm
            )
            #if os(macOS)
            .keyboardShortcut(.defaultAction)
            #endif
        }
    }
}

// MARK: - Menu rows

/// Trailing checkmark used in filter/sort menus when a row is selected.
public struct AppToolbarMenuCheckmark: View {
    private let isSelected: Bool

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    public var body: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color("Primary", bundle: .sharedUI))
            }
        }
    }
}

/// Standard filter/sort menu label with inactive + active icon names.
public struct AppToolbarFilterMenuLabel: View {
    private let title: String
    private let systemImage: String
    private let activeSystemImage: String
    private let selectionCount: Int

    public init(
        _ title: String,
        systemImage: String,
        activeSystemImage: String? = nil,
        selectionCount: Int = 0
    ) {
        self.title = title
        self.systemImage = systemImage
        self.activeSystemImage = activeSystemImage ?? "\(systemImage).fill"
        self.selectionCount = selectionCount
    }

    public var body: some View {
        Label {
            Text(AppToolbarMenuLabel.withCount(title, count: selectionCount))
        } icon: {
            Image(systemName: selectionCount > 0 ? activeSystemImage : systemImage)
        }
    }
}

// MARK: - Toolbar content

/// Workspace back/forward navigation for detail columns.
public struct AppToolbarHistoryNavigation: ToolbarContent {
    private let canNavigateBack: Bool
    private let canNavigateForward: Bool
    private let navigateBack: () -> Void
    private let navigateForward: () -> Void

    public init(
        canNavigateBack: Bool,
        canNavigateForward: Bool,
        navigateBack: @escaping () -> Void,
        navigateForward: @escaping () -> Void
    ) {
        self.canNavigateBack = canNavigateBack
        self.canNavigateForward = canNavigateForward
        self.navigateBack = navigateBack
        self.navigateForward = navigateForward
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            AppToolbarHistoryNavigationControlGroup(
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                navigateBack: navigateBack,
                navigateForward: navigateForward
            )
        }
    }
}

// MARK: - Navigation controls

/// Back/forward history controls using `ControlGroup` navigation style (macOS toolbar HIG).
public struct AppToolbarHistoryNavigationControlGroup: View {
    private let canNavigateBack: Bool
    private let canNavigateForward: Bool
    private let navigateBack: () -> Void
    private let navigateForward: () -> Void

    public init(
        canNavigateBack: Bool,
        canNavigateForward: Bool,
        navigateBack: @escaping () -> Void,
        navigateForward: @escaping () -> Void
    ) {
        self.canNavigateBack = canNavigateBack
        self.canNavigateForward = canNavigateForward
        self.navigateBack = navigateBack
        self.navigateForward = navigateForward
    }

    public var body: some View {
        ControlGroup {
            AppToolbarIconButton(
                systemName: "chevron.left",
                help: "Go back",
                isDisabled: !canNavigateBack,
                action: navigateBack
            )

            AppToolbarIconButton(
                systemName: "chevron.right",
                help: "Go forward",
                isDisabled: !canNavigateForward,
                action: navigateForward
            )
        }
        .controlGroupStyle(.navigation)
    }
}

/// Calendar-style period stepping: previous, today, next.
public struct AppToolbarPeriodNavigation: ToolbarContent {
    private let onPrevious: () -> Void
    private let onToday: () -> Void
    private let onNext: () -> Void

    public init(
        onPrevious: @escaping () -> Void,
        onToday: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.onPrevious = onPrevious
        self.onToday = onToday
        self.onNext = onNext
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ControlGroup {
                Button("Previous period", systemImage: "chevron.left", action: onPrevious)
                    .labelStyle(.iconOnly)
                    .help("Previous period")

                Button("Today", action: onToday)
                    .help("Jump to today")

                Button("Next period", systemImage: "chevron.right", action: onNext)
                    .labelStyle(.iconOnly)
                    .help("Next period")
            }
            .controlGroupStyle(.navigation)
        }
    }
}

/// Secondary utility cluster (filters, organize, overflow) — separated from primary actions on macOS.
public struct AppToolbarUtilityGroup<Content: View>: ToolbarContent {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some ToolbarContent {
        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .automatic) {
            content
        }
    }
}

/// Transient feedback and undo affordances — standalone status surface on macOS.
public struct AppToolbarStatusGroup<Content: View>: ToolbarContent {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .status) {
            content
        }
        .sharedBackgroundVisibility(.hidden)
    }
}
