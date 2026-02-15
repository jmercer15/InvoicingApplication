import SwiftUI

// MARK: - Image Placeholder Component

struct ImagePlaceholderComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize

    var body: some View {
        VStack {
            ImagePlaceholder()
                .stroke(Color.gray, lineWidth: 2)
                .aspectRatio(component.style.aspectRatio > 0 ? component.style.aspectRatio : nil, contentMode: component.style.imageContentMode.swiftUIContentMode)
                .opacity(component.style.imageOpacity)
            
            Text("Image Placeholder")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .clipped()
        .frame(
            minWidth: component.style.imageMinWidth,
            idealWidth: (component.style.imageWidthMode ?? .auto) == .fixed ? component.style.imageWidth : nil,
            maxWidth: component.style.imageMaxWidth ?? ((component.style.imageWidthMode ?? .auto) == .fill ? .infinity : nil),
            minHeight: component.style.imageMinHeight,
            idealHeight: (component.style.imageHeightMode ?? .auto) == .fixed ? component.style.imageHeight : nil,
            maxHeight: component.style.imageMaxHeight ?? ((component.style.imageHeightMode ?? .auto) == .fill ? .infinity : nil)
        )
        .frame(
            width: (component.style.imageWidthMode ?? .auto) == .fixed ? component.style.imageWidth : nil,
            height: (component.style.imageHeightMode ?? .auto) == .fixed ? component.style.imageHeight : nil
        )
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
        .reportComponentSize(for: component, document: document)
    }
}
