import SwiftUI

// MARK: - Text Box Component

struct TextBoxComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize

    var body: some View {
        let baseFontSize = component.style.fontSize > 0 ? component.style.fontSize : 12
        let alignment = component.style.textAlignment
        let displayText = component.style.placeholderText.isEmpty ? "Enter text here" : component.style.placeholderText
        
        VStack(alignment: alignment.horizontalAlignment) {
            Text(component.style.textTransform.apply(to: displayText))
                .standardTextStyle(component: component, baseFontSize: baseFontSize)
        }
        .standardComponentStyle(component: component, document: document, alignment: alignment.frameAlignment)
    }
}

// MARK: - Preview

#Preview("TextBoxComponent - Visual") {
    VStack(alignment: .leading, spacing: 16) {
        // Heading style
        Text("Invoice Title")
            .font(.title.bold())
        
        // Subheading
        Text("Subtitle text with secondary styling")
            .font(.headline)
            .foregroundColor(.secondary)
        
        // Body text
        Text("This is body text that would appear in a text box component. It can span multiple lines.")
            .font(.body)
        
        // Caption
        Text("Small caption text")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .frame(width: 300)
}
