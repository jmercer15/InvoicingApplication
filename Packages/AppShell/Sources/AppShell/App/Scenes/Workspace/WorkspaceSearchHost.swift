import SwiftUI

struct WorkspaceSearchHost: ViewModifier {
    let isEnabled: Bool
    @Binding var isPresented: Bool
    let text: Binding<String>
    let prompt: LocalizedStringKey

    func body(content: Content) -> some View {
        // Keep one search preference registered for entire window lifetime.
        // Conditionally inserting/removing `.searchable` can leave AppKit's old
        // toolbar item alive for one update cycle and then insert a duplicate
        // `com.apple.SwiftUI.search` item when tabs change.
        content
            .searchable(
                text: text,
                isPresented: presentation,
                placement: .automatic,
                prompt: prompt
            )
            .searchToolbarBehavior(.automatic)
    }

    private var presentation: Binding<Bool> {
        Binding(
            get: { isEnabled && isPresented },
            set: { newValue in
                guard isEnabled, isPresented != newValue else { return }
                isPresented = newValue
            }
        )
    }
}

extension View {
    func workspaceSearchHost(
        isEnabled: Bool,
        isPresented: Binding<Bool>,
        text: Binding<String>,
        prompt: LocalizedStringKey
    ) -> some View {
        modifier(WorkspaceSearchHost(
            isEnabled: isEnabled,
            isPresented: isPresented,
            text: text,
            prompt: prompt
        ))
    }
}
