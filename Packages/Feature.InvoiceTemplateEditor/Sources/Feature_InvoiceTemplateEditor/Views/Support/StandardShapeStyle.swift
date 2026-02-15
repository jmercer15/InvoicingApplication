import SwiftUI

struct StandardShapeStyle<S: Shape>: ViewModifier {
    let component: InvoiceComponent
    let shape: S
    let document: InvoiceDocument
    
    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize

    func body(content: Content) -> some View {
        // Note: The content of this modifier is largely ignored because we rebuild the shape
        // to apply fill and stroke modifiers correctly.
        // We use the passed-in 'shape' parameter to render the styled shape.
        
        shape
            .fill(component.style.backgroundColorSwiftUI)
            .opacity(component.style.backgroundOpacity)
            .overlay {
                if component.style.borderWidth > 0 {
                    shape
                        .stroke(component.style.borderColorSwiftUI, lineWidth: component.style.borderWidth)
                }
            }
            .aspectRatio(component.style.aspectRatio > 0 ? component.style.aspectRatio : 1.0, contentMode: .fit)
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

extension View {
    // Note: This extension is slightly unusual because it requires passing the shape again.
    // Ideally, we'd apply this to 'some Shape', but ViewModifier works on 'some View'.
    // Usage: MyShape().modifier(StandardShapeStyle(component: ..., shape: MyShape(), ...))
    // Or Helper: MyShape().standardShapeStyle(...) which internally does the duplication or wrapping.
    
    // Better Approach:
    // Since we need to apply fill/stroke to the shape itself, which returns a View,
    // we can't easily make a modifier that takes a generic View and casts it back to Shape.
    // Instead, let's make this a view builder function or a modifier that takes the original shape logic.
    //
    // However, looking at the patterns:
    // Ellipse().fill(...)
    //
    // Let's make a View extensions that applies the style to the shape.
}

extension Shape {
    func standardShapeStyle(component: InvoiceComponent, document: InvoiceDocument, autoAspectRatio: Bool = true) -> some View {
        self
            .fill(component.style.backgroundColorSwiftUI)
            .opacity(component.style.backgroundOpacity)
            .overlay {
                if component.style.borderWidth > 0 {
                    self
                        .stroke(component.style.borderColorSwiftUI, lineWidth: component.style.borderWidth)
                }
            }
            .modifier(AspectRatioModifier(ratio: component.style.aspectRatio, enabled: autoAspectRatio))
            .shadow(
                color: component.style.shadowEnabled ? component.style.shadowColorSwiftUI.opacity(component.style.shadowOpacity) : .clear,
                radius: component.style.shadowRadius,
                x: component.style.shadowOffsetX,
                y: component.style.shadowOffsetY
            )
            .modifier(StandardShapeFrameModifier(component: component, document: document))
    }
}

private struct AspectRatioModifier: ViewModifier {
    let ratio: CGFloat
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            content.aspectRatio(ratio > 0 ? ratio : 1.0, contentMode: .fit)
        } else {
            content
        }
    }
}

// Special case for LineShape since it might handle aspect ratio differently
// actually LineShapeComponent uses Line() which is a Shape.
// But some shapes might not want aspectRatio(1.0) enforced if not specified.
// The existing code has `.aspectRatio(... : 1.0)`.

struct StandardShapeFrameModifier: ViewModifier {
    let component: InvoiceComponent
    let document: InvoiceDocument
    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize
    
    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: isMeasuringIdealSize ? nil : .infinity,
                maxHeight: isMeasuringIdealSize ? nil : .infinity
            )
            .padding(component.style.padding)
            .padding(component.style.margin)
            .reportComponentSize(for: component, document: document)
    }
}
