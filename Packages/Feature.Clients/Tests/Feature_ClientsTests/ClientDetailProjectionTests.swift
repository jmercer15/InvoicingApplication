import XCTest
import Core
@testable import Feature_Clients

final class ClientDetailProjectionTests: XCTestCase {
    func testRefreshTaskIDTracksQuerySnapshotCounts() {
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

        XCTAssertEqual(
            projection.refreshTaskID,
            ClientDetailProjectionRefreshID(
                clientId: clientId,
                clientServices: [clientService],
                relatedInvoices: [invoice],
                serviceAgreements: []
            )
        )
    }
}
