import SwiftUI

// MARK: - Line Shape Component

struct LineShapeComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize
    
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
        .frame(
            maxWidth: isMeasuringIdealSize ? nil : .infinity,
            maxHeight: isMeasuringIdealSize ? nil : .infinity
        )
        .padding(component.style.padding)
        .padding(component.style.margin)
        .reportComponentSize(for: component, document: document)
    }
}

// MARK: - Preview

#Preview("LineShapeComponent - Visual") {
    VStack(spacing: 20) {
        // Simple line
        Line(startDecorator: .none, endDecorator: .none, thickness: 2)
            .stroke(Color.primary, lineWidth: 2)
            .frame(width: 100, height: 20)
        
        // Arrow line
        Line(startDecorator: .none, endDecorator: .arrow, thickness: 2)
            .stroke(Color.red, lineWidth: 2)
            .frame(width: 100, height: 20)
        
        // Double arrow
        Line(startDecorator: .arrow, endDecorator: .arrow, thickness: 2)
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: 100, height: 20)
        
        // Circle decorators
        Line(startDecorator: .circle, endDecorator: .circle, thickness: 3)
            .stroke(Color.purple, lineWidth: 3)
            .frame(width: 100, height: 30)
    }
    .padding()
}
