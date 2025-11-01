import XCTest
import SwiftData
import Core
@testable import Data

/// Unit tests for UpdateInvoiceStatus use case
/// Tests the critical invoice status update scenarios to prevent regression
@MainActor
final class UpdateInvoiceStatusTests: XCTestCase {
    
    private var modelContext: ModelContext!
    private var repository: InvoicesRepositorySwiftData!
    private var updateInvoiceStatus: UpdateInvoiceStatus!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model context for testing
        let schema = Schema([
            InvoiceEntity.self,
            ClientEntity.self,
            BusinessEntity.self,
            PayeeEntity.self,
            SessionEntity.self,
            InvoiceItemEntity.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        repository = InvoicesRepositorySwiftData(modelContext: modelContext)
        updateInvoiceStatus = UpdateInvoiceStatus(repository: repository)
    }
    
    override func tearDown() async throws {
        modelContext = nil
        repository = nil
        updateInvoiceStatus = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Data Setup
    
    private func createTestInvoice(status: String = "draft") -> InvoiceEntity {
        let entity = InvoiceEntity(id: UUID())
        entity.invoiceNumber = "INV-001"
        entity.totalAmount = 1000.0
        entity.status = status
        entity.issueDate = Date()
        entity.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        entity.currencyCode = "AUD"
        entity.businessName = "Test Business"
        entity.businessABN = "12345678901"
        entity.clientName = "Test Client"
        entity.clientNDISNumber = "123456789"
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    // MARK: - General Status Update Tests
    
    func testUpdateInvoiceStatus_Success() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        let newStatus = "approved"
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(id: invoice.id, status: newStatus)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, newStatus)
        XCTAssertEqual(updatedInvoice.id, invoice.id)
        
        // Verify in database
        let fetchedInvoice = try await repository.fetch(by: invoice.id)
        XCTAssertEqual(fetchedInvoice?.status, newStatus)
    }
    
    func testUpdateInvoiceStatus_InvoiceNotFound() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When/Then
        do {
            _ = try await updateInvoiceStatus(id: nonExistentId, status: "approved")
            XCTFail("Expected InvoiceError.invoiceNotFound")
        } catch InvoiceError.invoiceNotFound {
            // Expected
        } catch {
            XCTFail("Expected InvoiceError.invoiceNotFound, got \(error)")
        }
    }
    
    // MARK: - Mark as Sent Tests
    
    func testMarkAsSent_Success() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        let beforeDate = Date()
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsSent: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "sent")
        XCTAssertNotNil(updatedInvoice.sentDate)
        XCTAssertGreaterThanOrEqual(updatedInvoice.sentDate!, beforeDate)
        
        // Verify in database
        let fetchedInvoice = try await repository.fetch(by: invoice.id)
        XCTAssertEqual(fetchedInvoice?.status, "sent")
        XCTAssertNotNil(fetchedInvoice?.sentDate)
    }
    
    func testMarkAsSent_UpdatesSentDate() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        let originalSentDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        invoice.sentDate = originalSentDate
        try modelContext.save()
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsSent: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "sent")
        XCTAssertNotNil(updatedInvoice.sentDate)
        XCTAssertNotEqual(updatedInvoice.sentDate, originalSentDate)
        XCTAssertGreaterThan(updatedInvoice.sentDate!, originalSentDate!)
    }
    
    func testMarkAsSent_InvoiceNotFound() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When/Then
        do {
            _ = try await updateInvoiceStatus(markAsSent: nonExistentId)
            XCTFail("Expected InvoiceError.invoiceNotFound")
        } catch InvoiceError.invoiceNotFound {
            // Expected
        } catch {
            XCTFail("Expected InvoiceError.invoiceNotFound, got \(error)")
        }
    }
    
    // MARK: - Mark as Paid Tests
    
    func testMarkAsPaid_Success() async throws {
        // Given
        let invoice = createTestInvoice(status: "sent")
        let beforeDate = Date()
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsPaid: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "paid")
        XCTAssertNotNil(updatedInvoice.paidDate)
        XCTAssertGreaterThanOrEqual(updatedInvoice.paidDate!, beforeDate)
        
        // Verify in database
        let fetchedInvoice = try await repository.fetch(by: invoice.id)
        XCTAssertEqual(fetchedInvoice?.status, "paid")
        XCTAssertNotNil(fetchedInvoice?.paidDate)
    }
    
    func testMarkAsPaid_UpdatesPaidDate() async throws {
        // Given
        let invoice = createTestInvoice(status: "sent")
        let originalPaidDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        invoice.paidDate = originalPaidDate
        try modelContext.save()
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsPaid: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "paid")
        XCTAssertNotNil(updatedInvoice.paidDate)
        XCTAssertNotEqual(updatedInvoice.paidDate, originalPaidDate)
        XCTAssertGreaterThan(updatedInvoice.paidDate!, originalPaidDate!)
    }
    
    func testMarkAsPaid_InvoiceNotFound() async throws {
        // Given
        let nonExistentId = UUID()
        
        // When/Then
        do {
            _ = try await updateInvoiceStatus(markAsPaid: nonExistentId)
            XCTFail("Expected InvoiceError.invoiceNotFound")
        } catch InvoiceError.invoiceNotFound {
            // Expected
        } catch {
            XCTFail("Expected InvoiceError.invoiceNotFound, got \(error)")
        }
    }
    
    // MARK: - Billing Status Update Tests
    
    func testUpdateBillingStatus_Success() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        let billingStatus = BillingStatus.approved
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(id: invoice.id, billingStatus: billingStatus)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "approved")
        XCTAssertEqual(updatedInvoice.id, invoice.id)
        
        // Verify in database
        let fetchedInvoice = try await repository.fetch(by: invoice.id)
        XCTAssertEqual(fetchedInvoice?.status, "approved")
    }
    
    func testUpdateBillingStatus_InvoiceNotFound() async throws {
        // Given
        let nonExistentId = UUID()
        let billingStatus = BillingStatus.approved
        
        // When/Then
        do {
            _ = try await updateInvoiceStatus(id: nonExistentId, billingStatus: billingStatus)
            XCTFail("Expected InvoiceError.invoiceNotFound")
        } catch InvoiceError.invoiceNotFound {
            // Expected
        } catch {
            XCTFail("Expected InvoiceError.invoiceNotFound, got \(error)")
        }
    }
    
    // MARK: - Status Transition Tests
    
    func testStatusTransition_DraftToSent() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsSent: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "sent")
        XCTAssertNotNil(updatedInvoice.sentDate)
        XCTAssertNil(updatedInvoice.paidDate)
    }
    
    func testStatusTransition_SentToPaid() async throws {
        // Given
        let invoice = createTestInvoice(status: "sent")
        invoice.sentDate = Date()
        try modelContext.save()
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsPaid: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "paid")
        XCTAssertNotNil(updatedInvoice.sentDate)
        XCTAssertNotNil(updatedInvoice.paidDate)
    }
    
    func testStatusTransition_DraftToPaid() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsPaid: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "paid")
        XCTAssertNil(updatedInvoice.sentDate) // Should not set sentDate when going directly to paid
        XCTAssertNotNil(updatedInvoice.paidDate)
    }
    
    // MARK: - Data Integrity Tests
    
    func testStatusUpdate_PreservesOtherProperties() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        let originalTotalAmount = invoice.totalAmount
        let originalInvoiceNumber = invoice.invoiceNumber
        let originalClientName = invoice.clientName
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsSent: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.totalAmount, originalTotalAmount)
        XCTAssertEqual(updatedInvoice.invoiceNumber, originalInvoiceNumber)
        XCTAssertEqual(updatedInvoice.clientName, originalClientName)
        XCTAssertEqual(updatedInvoice.status, "sent")
    }
    
    func testMultipleStatusUpdates_Sequential() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        
        // When - Draft -> Sent -> Paid
        let sentInvoice = try await updateInvoiceStatus(markAsSent: invoice.id)
        let paidInvoice = try await updateInvoiceStatus(markAsPaid: invoice.id)
        
        // Then
        XCTAssertEqual(sentInvoice.status, "sent")
        XCTAssertEqual(paidInvoice.status, "paid")
        XCTAssertNotNil(paidInvoice.sentDate)
        XCTAssertNotNil(paidInvoice.paidDate)
        XCTAssertGreaterThanOrEqual(paidInvoice.paidDate!, paidInvoice.sentDate!)
    }
    
    // MARK: - Edge Cases
    
    func testStatusUpdate_WithNilDates() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        invoice.sentDate = nil
        invoice.paidDate = nil
        try modelContext.save()
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsSent: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "sent")
        XCTAssertNotNil(updatedInvoice.sentDate)
        XCTAssertNil(updatedInvoice.paidDate)
    }
    
    func testStatusUpdate_WithExistingDates() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        let existingSentDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        let existingPaidDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        invoice.sentDate = existingSentDate
        invoice.paidDate = existingPaidDate
        try modelContext.save()
        
        // When
        let updatedInvoice = try await updateInvoiceStatus(markAsSent: invoice.id)
        
        // Then
        XCTAssertEqual(updatedInvoice.status, "sent")
        XCTAssertNotNil(updatedInvoice.sentDate)
        XCTAssertNotEqual(updatedInvoice.sentDate, existingSentDate) // Should update
        XCTAssertEqual(updatedInvoice.paidDate, existingPaidDate) // Should preserve
    }
    
    // MARK: - Performance Tests
    
    func testStatusUpdate_Performance() async throws {
        // Given
        let invoice = createTestInvoice(status: "draft")
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await updateInvoiceStatus(markAsSent: invoice.id)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(timeElapsed, 1.0, "Status update should complete within 1 second")
    }
    
    func testMultipleStatusUpdates_Performance() async throws {
        // Given
        let invoices = (0..<10).map { _ in createTestInvoice(status: "draft") }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        for invoice in invoices {
            _ = try await updateInvoiceStatus(markAsSent: invoice.id)
        }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(timeElapsed, 5.0, "Multiple status updates should complete within 5 seconds")
    }
}

// MARK: - Test Utilities

extension UpdateInvoiceStatusTests {
    
    /// Helper to create a test invoice with specific properties
    private func createTestInvoiceWithProperties(
        id: UUID = UUID(),
        status: String = "draft",
        totalAmount: Double = 1000.0,
        invoiceNumber: String = "INV-001"
    ) -> InvoiceEntity {
        let entity = InvoiceEntity(id: id)
        entity.invoiceNumber = invoiceNumber
        entity.totalAmount = totalAmount
        entity.status = status
        entity.issueDate = Date()
        entity.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        entity.currencyCode = "AUD"
        entity.businessName = "Test Business"
        entity.businessABN = "12345678901"
        entity.clientName = "Test Client"
        entity.clientNDISNumber = "123456789"
        
        modelContext.insert(entity)
        try! modelContext.save()
        return entity
    }
    
    /// Helper to verify invoice status in database
    private func verifyInvoiceStatusInDatabase(id: UUID, expectedStatus: String) async throws {
        let fetchedInvoice = try await repository.fetch(by: id)
        XCTAssertEqual(fetchedInvoice?.status, expectedStatus)
    }
    
    /// Helper to verify invoice dates in database
    private func verifyInvoiceDatesInDatabase(
        id: UUID,
        expectedSentDate: Date? = nil,
        expectedPaidDate: Date? = nil
    ) async throws {
        let fetchedInvoice = try await repository.fetch(by: id)
        
        if let expectedSentDate = expectedSentDate {
            XCTAssertEqual(fetchedInvoice?.sentDate, expectedSentDate)
        }
        
        if let expectedPaidDate = expectedPaidDate {
            XCTAssertEqual(fetchedInvoice?.paidDate, expectedPaidDate)
        }
    }
}
