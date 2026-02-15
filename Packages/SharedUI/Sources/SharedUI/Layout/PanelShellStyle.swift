import SwiftUI

/// Shell role used to tune panel treatment.
public enum PanelShellRole: Sendable {
    case contentPanel
    case detailPanel
    case singlePanel
}

public struct PanelShellStyle: ViewModifier {
    private let role: PanelShellRole

    public init(role: PanelShellRole) {
        self.role = role
    }

    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(backgroundColor)
    }

    private var backgroundColor: Color {
        switch role {
        case .contentPanel:
            return PanelShellTokens.contentPanelBackground
        case .detailPanel, .singlePanel:
            return PanelShellTokens.detailPanelBackground
        }
    }
}
