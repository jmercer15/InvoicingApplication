import SwiftUI

// MARK: - Ellipse Shape Component

struct EllipseShapeComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize
    
    var body: some View {
        Ellipse()
            .standardShapeStyle(component: component, document: document)
    }
}

// MARK: - Preview

#Preview("EllipseShapeComponent - Visual") {
    HStack(spacing: 20) {
        // Circle
        Ellipse()
            .fill(Color.orange)
            .frame(width: 60, height: 60)
        
        // Horizontal ellipse
        Ellipse()
            .fill(Color.orange)
            .frame(width: 100, height: 50)
        
        // Vertical ellipse
        Ellipse()
            .fill(Color.orange)
            .frame(width: 50, height: 80)
    }
    .padding()
}
