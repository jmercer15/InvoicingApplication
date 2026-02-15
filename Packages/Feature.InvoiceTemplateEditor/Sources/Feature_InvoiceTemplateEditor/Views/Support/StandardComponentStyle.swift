import SwiftUI

struct StandardComponentStyle: ViewModifier {
    let component: InvoiceComponent
    let document: InvoiceDocument
    let alignment: Alignment
    
    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize

    init(component: InvoiceComponent, document: InvoiceDocument, alignment: Alignment = .center) {
        self.component = component
        self.document = document
        self.alignment = alignment
    }

    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: isMeasuringIdealSize ? nil : .infinity,
                maxHeight: isMeasuringIdealSize ? nil : .infinity,
                alignment: alignment
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

extension View {
    func standardComponentStyle(component: InvoiceComponent, document: InvoiceDocument, alignment: Alignment = .center) -> some View {
        modifier(StandardComponentStyle(component: component, document: document, alignment: alignment))
    }
}
