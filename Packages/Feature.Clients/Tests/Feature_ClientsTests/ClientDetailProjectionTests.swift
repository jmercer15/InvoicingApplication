import Foundation
import PersistenceModels
import Testing
import Core
@testable import Feature_Clients

@Suite struct ClientDetailProjectionTests {
    @Test func RefreshTaskIDTracksQuerySnapshotCounts() {
        let clientId = UUID()
        let invoice = Invoice(invoiceNumber: "INV-1")
        invoice.issueDate = Date()
        let clientService = ClientService(serviceName: "Therapy", unit: "hour", rate: 120)
        
        let projection = ClientDetailProjection(
            clientId: clientId,
            clientServices: [clientService],
            relatedInvoices: [invoice],
            serviceAgreements: []
        )

        #expect(projection.refreshTaskID == ClientDetailProjectionRefreshID(
                clientId: clientId,
                clientServices: [clientService],
                relatedInvoices: [invoice],
                serviceAgreements: []
            ))
    }
}
