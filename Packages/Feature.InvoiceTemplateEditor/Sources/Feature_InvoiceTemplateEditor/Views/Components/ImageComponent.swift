import SwiftUI

// MARK: - Image Component

struct ImageComponent: View {
let component: InvoiceComponent
@EnvironmentObject private var document: InvoiceDocument

var body: some View {
VStack {
if component.type == .companyLogo {
// Company Logo placeholder
Image(systemName: "building.2")
.resizable()
.aspectRatio(component.style.aspectRatio > 0 ? component.style.aspectRatio : nil, contentMode: contentMode(from: component.style.imageContentMode))
.foregroundColor(.gray)
.opacity(component.style.imageOpacity)
} else {
// Generic image placeholder
Image(systemName: "photo")
.resizable()
.aspectRatio(component.style.aspectRatio > 0 ? component.style.aspectRatio : nil, contentMode: contentMode(from: component.style.imageContentMode))
.foregroundColor(.gray)
.opacity(component.style.imageOpacity)
}
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
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

private func contentMode(from mode: ImageContentMode) -> ContentMode {
switch mode {
case .fill: return .fill
case .fit: return .fit
}
}
}

