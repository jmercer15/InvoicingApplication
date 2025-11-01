import SwiftUI

// MARK: - Rectangle Shape Component

struct RectangleShapeComponent: View {
let component: InvoiceComponent
@EnvironmentObject private var document: InvoiceDocument

var body: some View {
RoundedRectangle(cornerRadius: component.style.cornerRadius)
.fill(component.style.backgroundColorSwiftUI)
.opacity(component.style.backgroundOpacity)
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
.frame(maxWidth: .infinity, maxHeight: .infinity)
.padding(component.style.padding)
.padding(component.style.margin)
}
}

