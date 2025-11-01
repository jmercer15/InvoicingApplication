import SwiftUI

// MARK: - Text Box Component

struct TextBoxComponent: View {
let component: InvoiceComponent
@EnvironmentObject private var document: InvoiceDocument

var body: some View {
let baseFontSize = component.style.fontSize > 0 ? component.style.fontSize : 12
let alignment = component.style.textAlignment
let displayText = component.style.placeholderText.isEmpty ? "Text" : component.style.placeholderText

VStack(alignment: alignment.horizontalAlignment, spacing: 4) {
Text(applyTextTransform(displayText, transform: component.style.textTransform))
.font(component.style.fontFamily(baseFontSize, component.style.fontWeightValue))
.foregroundColor(component.style.textColorSwiftUI)
.opacity(component.style.textOpacity)
.multilineTextAlignment(alignment.swiftUIAlignment)
.lineSpacing(component.style.lineSpacing)
.tracking(component.style.letterSpacing)
.underline(component.style.textUnderline)
.strikethrough(component.style.textStrikethrough)
}
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frameAlignment)
.padding(component.style.padding)
.background(
RoundedRectangle(cornerRadius: component.style.cornerRadius)
.fill(component.style.backgroundColorSwiftUI)
.opacity(component.style.backgroundOpacity)
)
.overlay {
if component.style.borderWidth > 0 {
RoundedRectangle(cornerRadius: component.style.cornerRadius)
.stroke(component.style.borderColorSwiftUI, lineWidth: component.style.borderWidth)
}
}
.shadow(
color: component.style.shadowEnabled ? component.style.shadowColorSwiftUI.opacity(component.style.shadowOpacity) : .clear,
radius: component.style.shadowRadius,
x: component.style.shadowOffsetX,
y: component.style.shadowOffsetY
)
.padding(component.style.margin)
}

private func applyTextTransform(_ text: String, transform: TextTransform) -> String {
switch transform {
case .none: return text
case .uppercase: return text.uppercased()
case .lowercase: return text.lowercased()
case .capitalize: return text.capitalized
}
}
}

