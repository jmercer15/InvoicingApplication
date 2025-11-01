import SwiftUI
import Core

struct ShapeSpecificSectionContent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument

    var body: some View {
        PropertyGrid {
            switch component.type {
            case .lineShape:
                ModernSliderEditor(
                    title: "Thickness",
                    value: component.style.lineThickness,
                    range: 0.5...10,
                    step: 0.5,
                    formatter: "%.1f",
                    onChange: { document.updateLineThickness(for: component.id, thickness: $0) }
                )

                ModernPickerEditor(
                    title: "Line Style",
                    selection: component.style.lineStyle,
                    onChange: { document.updateLineStyle(for: component.id, style: $0) }
                )

            case .triangleShape:
                ModernPickerEditor(
                    title: "Direction",
                    selection: component.style.triangleDirection,
                    onChange: { document.updateTriangleDirection(for: component.id, direction: $0) }
                )

            case .starShape:
                ModernSliderEditor(
                    title: "Points",
                    value: Double(component.style.starPoints),
                    range: 3...12,
                    step: 1,
                    formatter: "%.0f",
                    onChange: { document.updateStarPoints(for: component.id, points: Int($0)) }
                )

                ModernSliderEditor(
                    title: "Smoothness",
                    value: component.style.starSmoothness,
                    range: 0.1...1.0,
                    step: 0.05,
                    formatter: "%.2f",
                    onChange: { document.updateStarSmoothness(for: component.id, smoothness: $0) }
                )

            default:
                EmptyView()
            }
        }
    }
}

