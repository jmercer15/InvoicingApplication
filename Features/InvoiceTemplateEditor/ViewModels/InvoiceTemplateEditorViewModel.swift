import SwiftUI

class InvoiceTemplateEditorViewModel: ObservableObject {
    @Published var document = InvoiceDocument()
    
    // The component palette now drives its own data, so this can be simplified.
    // If you need to programmatically add items, you would do so on the `document`.
}
