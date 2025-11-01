import SwiftUI

// MARK: - Star Shape Component

struct StarShapeComponent: View {
let component: InvoiceComponent
@EnvironmentObject private var document: InvoiceDocument

var body: some View {
Star(points: component.style.starPoints, smoothness: component.style.starSmoothness)
.fill(component.style.backgroundColorSwiftUI)
.opacity(component.style.backgroundOpacity)
.overlay {
if component.style.borderWidth > 0 {
Star(points: component.style.starPoints, smoothness: component.style.starSmoothness)
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

