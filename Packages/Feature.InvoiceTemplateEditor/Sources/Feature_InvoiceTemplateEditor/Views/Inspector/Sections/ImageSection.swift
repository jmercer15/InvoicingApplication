import SwiftUI
import Core

struct ImageSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernPickerEditor(
                title: "Content Mode",
                selection: component.style.imageContentMode,
                onChange: { document.updateImageContentMode(for: component.id, mode: $0) }
            )

            ModernSliderEditor(
                title: "Opacity",
                value: component.style.imageOpacity,
                range: 0.0...1.0,
                step: 0.1,
                formatter: "%.1f",
                onChange: { document.updateImageOpacity(for: component.id, opacity: $0) }
            )
        }
    }
}

