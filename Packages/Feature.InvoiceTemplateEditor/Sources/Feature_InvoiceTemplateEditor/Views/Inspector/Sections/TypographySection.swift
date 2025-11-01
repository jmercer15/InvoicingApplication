import SwiftUI
import Core

struct TypographySectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            ModernTextField(
                title: "Font Family",
                value: component.style.fontFamily,
                onValueChange: { document.updateFontFamily(for: component.id, family: $0) }
            )

            ModernSliderEditor(
                title: "Font Size",
                value: component.style.fontSize,
                range: 6...72,
                step: 1,
                formatter: "%.0f",
                onChange: { document.updateFontSize(for: component.id, fontSize: $0) }
            )

            ModernTextField(
                title: "Font Weight",
                value: component.style.fontWeight,
                onValueChange: { document.updateFontWeight(for: component.id, weight: $0) }
            )

            ModernPickerEditor(
                title: "Text Alignment",
                selection: component.style.textAlignment,
                onChange: { document.updateTextAlignment(for: component.id, alignment: $0) }
            )

            ModernSliderEditor(
                title: "Line Spacing",
                value: component.style.lineSpacing,
                range: 0.5...3.0,
                step: 0.1,
                formatter: "%.1f",
                onChange: { document.updateLineSpacing(for: component.id, spacing: $0) }
            )

            ModernSliderEditor(
                title: "Letter Spacing",
                value: component.style.letterSpacing,
                range: -2.0...5.0,
                step: 0.1,
                formatter: "%.1f",
                onChange: { document.updateLetterSpacing(for: component.id, spacing: $0) }
            )

            ModernColorEditor(
                title: "Text Color",
                color: component.style.textColorSwiftUI,
                hexColor: component.style.textColor,
                onChange: { document.updateTextColor(for: component.id, color: $0) }
            )

            ModernSliderEditor(
                title: "Text Opacity",
                value: component.style.textOpacity,
                range: 0.0...1.0,
                step: 0.1,
                formatter: "%.1f",
                onChange: { document.updateTextOpacity(for: component.id, opacity: $0) }
            )

            ModernPickerEditor(
                title: "Text Transform",
                selection: component.style.textTransform,
                onChange: { document.updateTextTransform(for: component.id, transform: $0) }
            )

            ModernToggleEditor(
                title: "Underline",
                isOn: component.style.textUnderline,
                onChange: { document.updateTextUnderline(for: component.id, underline: $0) }
            )

            ModernToggleEditor(
                title: "Strikethrough",
                isOn: component.style.textStrikethrough,
                onChange: { document.updateTextStrikethrough(for: component.id, strikethrough: $0) }
            )
        }
    }
}

