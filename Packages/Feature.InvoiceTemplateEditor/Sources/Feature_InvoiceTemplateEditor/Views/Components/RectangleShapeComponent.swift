import SwiftUI

// MARK: - Rectangle Shape Component

struct RectangleShapeComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize
    
    var body: some View {
        RoundedRectangle(cornerRadius: component.style.cornerRadius)
            .standardShapeStyle(component: component, document: document, autoAspectRatio: false)
    }
}

// MARK: - Preview

#Preview("RectangleShapeComponent - Visual") {
    HStack(spacing: 20) {
        // No corner radius
        RoundedRectangle(cornerRadius: 0)
            .fill(Color.accentColor)
            .frame(width: 80, height: 60)
        
        // Medium corner radius
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.accentColor)
            .frame(width: 80, height: 60)
        
        // Large corner radius
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.accentColor)
            .frame(width: 80, height: 60)
    }
    .padding()
}
