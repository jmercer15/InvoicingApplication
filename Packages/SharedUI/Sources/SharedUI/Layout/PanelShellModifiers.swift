import SwiftUI

public struct PanelShellContentPaddingModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content.padding(.horizontal, PanelShellTokens.panelHorizontalPadding)
            .padding(.vertical, PanelShellTokens.panelVerticalPadding)
    }
}

public struct PanelShellTransitionModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content.transaction { transaction in
            transaction.animation = PanelShellTokens.shellTransition
        }
    }
}

public struct ContentPanelListInsetsModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, PanelShellTokens.contentListHorizontalInset)
            .padding(.vertical, PanelShellTokens.contentListVerticalInset)
    }
}

public struct ContentPanelBreadcrumbInsetsModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, PanelShellTokens.contentListHorizontalInset)
            .padding(.top, PanelShellTokens.contentListVerticalInset)
    }
}

public extension View {
    func standardPanelShell(role: PanelShellRole) -> some View {
        modifier(PanelShellStyle(role: role))
    }

    func standardPanelContentPadding() -> some View {
        modifier(PanelShellContentPaddingModifier())
    }

    func standardPanelTransition() -> some View {
        modifier(PanelShellTransitionModifier())
    }

    func standardContentPanelListInsets() -> some View {
        modifier(ContentPanelListInsetsModifier())
    }

    func standardContentPanelBreadcrumbInsets() -> some View {
        modifier(ContentPanelBreadcrumbInsetsModifier())
    }

    @ViewBuilder
    func standardPanelScrollEdgeEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.automatic, for: .top)
        } else {
            self
        }
    }
}
