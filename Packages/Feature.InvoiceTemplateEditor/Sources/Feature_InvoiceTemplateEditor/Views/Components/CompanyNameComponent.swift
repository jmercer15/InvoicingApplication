import SwiftUI

// MARK: - Company Name Component

struct CompanyNameComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var templateDataService: TemplateDataService
    
    private var businessData: BusinessTemplateData {
        templateDataService.getBusinessData()
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

