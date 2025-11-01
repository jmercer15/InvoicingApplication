import SwiftUI
import Core

struct ContentSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernTextField(
                title: "Content",
                value: component.style.placeholderText,
                onValueChange: { document.updatePlaceholderText(for: component.id, text: $0) }
            )
        }
    }
}

