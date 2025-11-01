import SwiftUI

// MARK: - Participant Component

struct ParticipantComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    // Context parameters for targeted data access
    let clientId: UUID?
    let invoiceId: UUID?
    
    var body: some View {
        // Use DocumentGridComponent which automatically detects this is a section component
        // and generates appropriate Participant data
        DocumentGridComponent(component: component, clientId: clientId, invoiceId: invoiceId)
    }
    
    // Initializer with context parameters
    init(component: InvoiceComponent, clientId: UUID? = nil, invoiceId: UUID? = nil) {
        self.component = component
        self.clientId = clientId
        self.invoiceId = invoiceId
    }
}