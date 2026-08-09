import SwiftUI
import SwiftData

/// Supplies a scene `ModelContext` with autosave disabled at creation time.
struct ManualSaveModelContextModifier: ViewModifier {
    let container: ModelContainer
    @State private var manualContext: ModelContext

    init(container: ModelContainer) {
        self.container = container
        let context = ModelContext(container)
        context.autosaveEnabled = false
        _manualContext = State(initialValue: context)
    }

    func body(content: Content) -> some View {
        content
            .modelContainer(container)
            .modelContext(manualContext)
    }
}

extension View {
    func manualSaveModelContext(container: ModelContainer) -> some View {
        modifier(ManualSaveModelContextModifier(container: container))
    }
}
