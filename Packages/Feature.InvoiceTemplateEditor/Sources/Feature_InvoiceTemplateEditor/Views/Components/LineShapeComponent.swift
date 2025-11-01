import SwiftUI

// MARK: - Line Shape Component

struct LineShapeComponent: View {
let component: InvoiceComponent
@EnvironmentObject private var document: InvoiceDocument

var body: some View {
Line(
startDecorator: component.style.lineStartDecorator,
endDecorator: component.style.lineEndDecorator,
thickness: component.style.lineThickness
)
.stroke(component.style.backgroundColorSwiftUI, lineWidth: component.style.lineThickness)
.opacity(component.style.backgroundOpacity)
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

