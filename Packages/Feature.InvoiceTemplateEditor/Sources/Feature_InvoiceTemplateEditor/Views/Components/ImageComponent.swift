import SwiftUI

// MARK: - Image Component

struct ImageComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize

    var body: some View {
        VStack {
            if component.type == .companyLogo {
                // Company Logo placeholder
                Image("fluent-ic_fluent_building_20_regular", bundle: .module)
                    .resizable()
                    .aspectRatio(component.style.aspectRatio > 0 ? component.style.aspectRatio : nil, contentMode: component.style.imageContentMode.swiftUIContentMode)
                    .foregroundColor(.gray)
                    .opacity(component.style.imageOpacity)
            } else {
                // Generic image placeholder
                Image("fluent-ic_fluent_image_20_regular", bundle: .module)
                    .resizable()
                    .aspectRatio(component.style.aspectRatio > 0 ? component.style.aspectRatio : nil, contentMode: component.style.imageContentMode.swiftUIContentMode)
                    .foregroundColor(.gray)
                    .opacity(component.style.imageOpacity)
            }
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

// MARK: - Preview

#Preview("ImageComponent - Visual") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            // Photo placeholder
            VStack {
                Image("fluent-ic_fluent_image_20_regular", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
                    .frame(width: 80, height: 80)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                Text("Photo").font(.caption)
            }
            
            // Company logo
            VStack {
                Image("fluent-ic_fluent_building_20_regular", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
                    .frame(width: 80, height: 80)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                Text("Logo").font(.caption)
            }
        }
        
        // With border and shadow
        Image("fluent-ic_fluent_image_20_regular", bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(.gray)
            .frame(width: 120, height: 80)
            .padding(8)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(radius: 4)
    }
    .padding()
}
