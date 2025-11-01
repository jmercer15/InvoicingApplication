import SwiftUI

// MARK: - Ellipse Shape Component

struct EllipseShapeComponent: View {
let component: InvoiceComponent
@EnvironmentObject private var document: InvoiceDocument

var body: some View {
Ellipse()
.fill(component.style.backgroundColorSwiftUI)
.opacity(component.style.backgroundOpacity)
.overlay {
if component.style.borderWidth > 0 {
Ellipse()
.stroke(component.style.borderColorSwiftUI, lineWidth: component.style.borderWidth)
}
}
.aspectRatio(component.style.aspectRatio > 0 ? component.style.aspectRatio : 1.0, contentMode: .fit)
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

