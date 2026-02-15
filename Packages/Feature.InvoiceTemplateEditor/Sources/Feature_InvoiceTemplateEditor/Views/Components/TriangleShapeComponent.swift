import SwiftUI

// MARK: - Triangle Shape Component

struct TriangleShapeComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize
    
    var body: some View {
        Triangle(direction: component.style.triangleDirection)
            .standardShapeStyle(component: component, document: document)
    }
}

// MARK: - Preview

#Preview("TriangleShapeComponent - Visual") {
    HStack(spacing: 20) {
        ForEach([TriangleDirection.up, .down, .left, .right], id: \.self) { direction in
            Triangle(direction: direction)
                .fill(Color.green)
                .frame(width: 50, height: 50)
        }
    }
    .padding()
}
