import SwiftUI

// MARK: - Star Shape Component

struct StarShapeComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize
    
    var body: some View {
        Star(points: component.style.starPoints, smoothness: component.style.starSmoothness)
            .standardShapeStyle(component: component, document: document)
    }
}

// MARK: - Preview

#Preview("StarShapeComponent - Visual") {
    HStack(spacing: 20) {
        Star(points: 5, smoothness: 0.5)
            .fill(Color.yellow)
            .frame(width: 60, height: 60)
        
        Star(points: 6, smoothness: 0.4)
            .fill(Color.yellow)
            .frame(width: 60, height: 60)
        
        Star(points: 8, smoothness: 0.6)
            .fill(Color.yellow)
            .frame(width: 60, height: 60)
    }
    .padding()
}
