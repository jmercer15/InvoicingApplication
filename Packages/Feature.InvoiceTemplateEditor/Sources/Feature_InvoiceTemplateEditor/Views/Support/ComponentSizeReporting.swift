import SwiftUI

// MARK: - Component Size Reporting

/// PreferenceKey to report the rendered size of a component
struct ComponentSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

extension View {
    /// Reports the rendered size of the component to the document model
    func reportComponentSize(for component: InvoiceComponent, document: InvoiceDocument) -> some View {
        self.modifier(ComponentSizeReporter(component: component, document: document))
    }
}

struct ComponentSizeReporter: ViewModifier {
    let component: InvoiceComponent
    @ObservedObject var document: InvoiceDocument
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ComponentSizePreferenceKey.self,
                        value: geometry.size
                    )
                }
            )
            .onPreferenceChange(ComponentSizePreferenceKey.self) { size in
                updateSize(size)
            }
    }
    
    private func updateSize(_ size: CGSize) {
        guard size != .zero else { return }
        
        // Get the current component state from the document to ensure we have the latest data
        guard let currentComponent = document.component(component.id) else { return }
        
        // Avoid updates while the user is actively resizing the component
        guard !currentComponent.isResizing else { return }
        
        // Only update if the size has changed significantly to avoid infinite loops
        // Using a threshold of 0.5 points
        let currentSize = currentComponent.size
        let widthDiff = abs(size.width - currentSize.width)
        let heightDiff = abs(size.height - currentSize.height)
        
        if widthDiff > 0.5 || heightDiff > 0.5 {
            // Update the component size in the document
            // We use a direct update to avoid triggering unnecessary view refreshes if possible
            document.updateComponent(id: component.id) { comp in
                comp.size = size
            }
        }
    }
}
