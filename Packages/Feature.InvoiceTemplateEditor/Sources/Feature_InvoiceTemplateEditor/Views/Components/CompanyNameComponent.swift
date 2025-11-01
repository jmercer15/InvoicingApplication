import SwiftUI

// MARK: - Company Name Component

struct CompanyNameComponent: View {
let component: InvoiceComponent
@EnvironmentObject private var document: InvoiceDocument
@Environment(\.modelContext) private var modelContext

private var businessData: BusinessTemplateData {
// Initialize shared instance if not already done
if TemplateDataService.shared == nil {
TemplateDataService.initializeShared(with: modelContext)
}
return TemplateDataService.getShared().getBusinessData()
}

var body: some View {
let baseFontSize = component.style.fontSize > 0 ? component.style.fontSize : 12
let alignment = component.style.textAlignment
VStack(alignment: alignment.horizontalAlignment, spacing: 4) {
Text(businessData.name)
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
}

// MARK: - Company Name Property Editor

struct CompanyNamePropertyEditor: View {
@EnvironmentObject private var document: InvoiceDocument
let component: InvoiceComponent

@Binding var isTypographyExpanded: Bool
@Binding var isBackgroundExpanded: Bool
@Binding var isBorderExpanded: Bool
@Binding var isShadowExpanded: Bool

var body: some View {
LazyVStack(alignment: .leading, spacing: 0) {
// Typography Section
ExpandablePropertySection(
title: "Typography",
isExpanded: isTypographyExpanded,
onToggle: { isTypographyExpanded.toggle() }
) {
SliderPropertyEditor(
title: "Font Size",
value: component.style.fontSize,
range: 8...48,
step: 1
) { newValue in
document.updateFontSize(for: component.id, fontSize: newValue)
}

PickerPropertyEditor(title: "Font Weight", selection: FontWeightOption(styleValue: component.style.fontWeight)) { newValue in
document.updateFontWeight(for: component.id, weight: newValue.styleValue)
}

PickerPropertyEditor(title: "Font Style", selection: FontFamilyOption(styleValue: component.style.fontFamily)) { newValue in
document.updateFontFamily(for: component.id, family: newValue.styleValue)
}

PickerPropertyEditor(title: "Alignment", selection: component.style.textAlignment) { newValue in
document.updateTextAlignment(for: component.id, alignment: newValue)
}

SliderPropertyEditor(
title: "Line Spacing",
value: component.style.lineSpacing,
range: 0.8...2.5,
step: 0.05,
formatter: "%.2f"
) { newValue in
document.updateLineSpacing(for: component.id, spacing: newValue)
}

SliderPropertyEditor(
title: "Letter Spacing",
value: component.style.letterSpacing,
range: -2...10,
step: 0.1,
formatter: "%.1f"
) { newValue in
document.updateLetterSpacing(for: component.id, spacing: newValue)
}

ColorPropertyEditor(
title: "Text Color",
color: component.style.textColorSwiftUI,
hexColor: component.style.textColor
) { newHex in
document.updateTextColor(for: component.id, color: sanitizedHex(newHex))
}

// Advanced Typography
TogglePropertyEditor(
title: "Underline",
isOn: component.style.textUnderline
) { newValue in
document.updateTextUnderline(for: component.id, underline: newValue)
}

TogglePropertyEditor(
title: "Strikethrough",
isOn: component.style.textStrikethrough
) { newValue in
document.updateTextStrikethrough(for: component.id, strikethrough: newValue)
}

PickerPropertyEditor(title: "Text Transform", selection: component.style.textTransform) { newValue in
document.updateTextTransform(for: component.id, transform: newValue)
}

SliderPropertyEditor(
title: "Text Opacity",
value: component.style.textOpacity,
range: 0...1,
step: 0.05,
formatter: "%.2f"
) { newValue in
document.updateTextOpacity(for: component.id, opacity: newValue)
}
}

// Background & Border Section
ExpandablePropertySection(
title: "Background & Border",
isExpanded: isBackgroundExpanded,
onToggle: { isBackgroundExpanded.toggle() }
) {
ColorPropertyEditor(
title: "Background Color",
color: component.style.backgroundColorSwiftUI,
hexColor: component.style.backgroundColor
) { newHex in
document.updateBackgroundColor(for: component.id, color: sanitizedHex(newHex))
}

SliderPropertyEditor(
title: "Background Opacity",
value: component.style.backgroundOpacity,
range: 0...1,
step: 0.05,
formatter: "%.2f"
) { newValue in
document.updateBackgroundOpacity(for: component.id, opacity: newValue)
}

SliderPropertyEditor(
title: "Border Width",
value: component.style.borderWidth,
range: 0...10,
step: 0.5
) { newValue in
document.updateBorderWidth(for: component.id, width: newValue)
}

ColorPropertyEditor(
title: "Border Color",
color: component.style.borderColorSwiftUI,
hexColor: component.style.borderColor
) { newHex in
document.updateBorderColor(for: component.id, color: sanitizedHex(newHex))
}

SliderPropertyEditor(
title: "Corner Radius",
value: component.style.cornerRadius,
range: 0...20,
step: 1
) { newValue in
document.updateCornerRadius(for: component.id, radius: newValue)
}
}

// Shadow Section
ExpandablePropertySection(
title: "Shadow",
isExpanded: isShadowExpanded,
onToggle: { isShadowExpanded.toggle() }
) {
TogglePropertyEditor(
title: "Enable Shadow",
isOn: component.style.shadowEnabled
) { newValue in
document.updateShadowEnabled(for: component.id, enabled: newValue)
}

if component.style.shadowEnabled {
SliderPropertyEditor(
title: "Shadow Radius",
value: component.style.shadowRadius,
range: 0...20,
step: 0.5
) { newValue in
document.updateShadowRadius(for: component.id, radius: newValue)
}

SliderPropertyEditor(
title: "Shadow Opacity",
value: component.style.shadowOpacity,
range: 0...1,
step: 0.05,
formatter: "%.2f"
) { newValue in
document.updateShadowOpacity(for: component.id, opacity: newValue)
}

ShadowOffsetEditor(
offsetX: component.style.shadowOffsetX,
offsetY: component.style.shadowOffsetY
) { x, y in
document.updateShadowOffset(for: component.id, x: x, y: y)
}

ColorPropertyEditor(
title: "Shadow Color",
color: component.style.shadowColorSwiftUI,
hexColor: component.style.shadowColor
) { newHex in
document.updateShadowColor(for: component.id, color: sanitizedHex(newHex))
}
}
}
}
.frame(maxWidth: .infinity, alignment: .leading)
}
}


private func sanitizedHex(_ hex: String) -> String {
let cleaned = hex.replacingOccurrences(of: "#", with: "").uppercased()
return cleaned
}
