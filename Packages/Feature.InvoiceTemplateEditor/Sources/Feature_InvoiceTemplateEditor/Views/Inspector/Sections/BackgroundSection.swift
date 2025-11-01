import SwiftUI
import Core

struct BackgroundSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            if component.type.supportsBackgroundFill {
                ModernColorEditor(
                    title: "Background",
                    color: component.style.backgroundColorSwiftUI,
                    hexColor: component.style.backgroundColor,
                    onChange: { document.updateBackgroundColor(for: component.id, color: $0) }
                )

                ModernSliderEditor(
                    title: "Opacity",
                    value: component.style.backgroundOpacity,
                    range: 0.0...1.0,
                    step: 0.1,
                    formatter: "%.1f",
                    onChange: { document.updateBackgroundOpacity(for: component.id, opacity: $0) }
                )
            }

            if component.type.supportsBorderControls {
                ModernColorEditor(
                    title: "Border Color",
                    color: component.style.borderColorSwiftUI,
                    hexColor: component.style.borderColor,
                    onChange: { document.updateBorderColor(for: component.id, color: $0) }
                )

                ModernSliderEditor(
                    title: "Border Width",
                    value: component.style.borderWidth,
                    range: 0...10,
                    step: 0.5,
                    formatter: "%.1f",
                    onChange: { document.updateBorderWidth(for: component.id, width: $0) }
                )
            }

            if component.type.supportsCornerRadius {
                ModernSliderEditor(
                    title: "Corner Radius",
                    value: component.style.cornerRadius,
                    range: 0...25,
                    step: 0.5,
                    formatter: "%.1f",
                    onChange: { document.updateCornerRadius(for: component.id, radius: $0) }
                )
            }
        }
    }
}

