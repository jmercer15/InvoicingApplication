import SwiftUI
import Core

struct SectionLayoutSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernPickerEditor(
                title: "Layout",
                selection: component.style.sectionLayout,
                onChange: { document.updateSectionLayout(for: component.id, layout: $0) }
            )

            ModernSliderEditor(
                title: "Spacing",
                value: component.style.contentSpacing,
                range: 0...50,
                step: 1,
                formatter: "%.0f",
                onChange: { document.updateContentSpacing(for: component.id, spacing: $0) }
            )

            ModernSliderEditor(
                title: "Padding",
                value: component.style.contentPadding,
                range: 0...50,
                step: 1,
                formatter: "%.0f",
                onChange: { document.updateContentPadding(for: component.id, padding: $0) }
            )
        }
    }
}

