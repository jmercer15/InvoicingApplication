import SwiftUI

// MARK: - Invoice Title Component

struct InvoiceTitleComponent: View {
let component: InvoiceComponent
@EnvironmentObject private var document: InvoiceDocument

    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize
    
    var body: some View {
        let baseFontSize = component.style.fontSize > 0 ? component.style.fontSize : 18
        let alignment = component.style.textAlignment
        VStack(alignment: alignment.horizontalAlignment, spacing: 4) {
            Text("INVOICE")
                .standardTextStyle(component: component, baseFontSize: baseFontSize)
        }
        .standardComponentStyle(component: component, document: document, alignment: alignment.frameAlignment)
    }
}
