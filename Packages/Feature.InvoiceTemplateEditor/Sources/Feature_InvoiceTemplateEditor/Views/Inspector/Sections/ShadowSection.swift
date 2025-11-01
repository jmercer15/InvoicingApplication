import SwiftUI
import Core

struct ShadowSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernToggleEditor(
                title: "Shadow",
                isOn: component.style.shadowEnabled,
                onChange: { document.updateShadowEnabled(for: component.id, enabled: $0) }
            )

            if component.style.shadowEnabled {
                ModernColorEditor(
                    title: "Shadow Color",
                    color: component.style.shadowColorSwiftUI,
                    hexColor: component.style.shadowColor,
                    onChange: { document.updateShadowColor(for: component.id, color: $0) }
                )

                ModernSliderEditor(
                    title: "Shadow Opacity",
                    value: component.style.shadowOpacity,
                    range: 0.0...1.0,
                    step: 0.1,
                    formatter: "%.1f",
                    onChange: { document.updateShadowOpacity(for: component.id, opacity: $0) }
                )

                ModernSliderEditor(
                    title: "Shadow Radius",
                    value: component.style.shadowRadius,
                    range: 0...20,
                    step: 0.5,
                    formatter: "%.1f",
                    onChange: { document.updateShadowRadius(for: component.id, radius: $0) }
                )

                ModernShadowOffsetEditor(
                    offsetX: component.style.shadowOffsetX,
                    offsetY: component.style.shadowOffsetY,
                    onChange: { x, y in document.updateShadowOffset(for: component.id, x: x, y: y) }
                )
            }
        }
    }
}

