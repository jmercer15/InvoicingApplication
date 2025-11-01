import SwiftUI

/// Wrapper for inspector content with a stable, caller-provided token to control equality
public struct InspectorContent: Equatable {
    let token: AnyHashable
    public let view: AnyView

    public init(id token: AnyHashable, view: AnyView) {
        self.token = token
        self.view = view
    }

    public static func == (lhs: InspectorContent, rhs: InspectorContent) -> Bool {
        lhs.token == rhs.token
    }
}

public struct InspectorContentPreferenceKey: @preconcurrency PreferenceKey {
    @MainActor public static var defaultValue: InspectorContent? = nil
    public static func reduce(value: inout InspectorContent?, nextValue: () -> InspectorContent?) {
        value = nextValue() ?? value
    }
}


