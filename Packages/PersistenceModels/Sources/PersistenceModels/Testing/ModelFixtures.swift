#if DEBUG
import Core
import Foundation

/// Stable reference timestamps for repeatable tests (2023-11-14 UTC).
public enum ModelFixtures {
    public static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
}

public extension Client {
    static func fixture(
        id: UUID = UUID(),
        ndisNumber: String = "123456789",
        fullName: String = "Test Client",
        status: ClientStatus = .active
    ) -> Client {
        Client(id: id, ndisNumber: ndisNumber, fullName: fullName, status: status)
    }
}

public extension Session {
    static func fixture(
        id: UUID = UUID(),
        title: String = "Test Session",
        startTime: Date = ModelFixtures.referenceDate,
        endTime: Date = ModelFixtures.referenceDate.addingTimeInterval(3600),
        status: SessionStatus? = .completed,
        client: Client? = nil
    ) -> Session {
        let session = Session(
            id: id,
            title: title,
            startTime: startTime,
            endTime: endTime,
            status: status
        )
        session.client = client
        return session
    }
}

public extension Invoice {
    static func fixture(
        id: UUID = UUID(),
        invoiceNumber: String = "INV-001",
        status: InvoiceStatus = .reviewDraft,
        totalAmount: Decimal = 100,
        client: Client? = nil
    ) -> Invoice {
        let invoice = Invoice(id: id, invoiceNumber: invoiceNumber)
        invoice.status = status
        invoice.totalAmount = totalAmount
        invoice.issueDate = ModelFixtures.referenceDate
        invoice.date = ModelFixtures.referenceDate
        invoice.client = client
        return invoice
    }
}

public extension Business {
    static func fixture(
        id: UUID = UUID(),
        abn: String = "12 345 678 901",
        name: String = "Test Business"
    ) -> Business {
        let business = Business(id: id, abn: abn)
        business.name = name
        return business
    }
}

public extension NDISBillingReport {
    static func fixture(
        invoice: InvoiceSnapshot? = nil,
        processedSessionsCount: Int = 0,
        successfulSessionsCount: Int = 0,
        failedSessions: [NDISBillingIssue] = [],
        warnings: [String] = []
    ) -> NDISBillingReport {
        NDISBillingReport(
            invoice: invoice,
            processedSessionsCount: processedSessionsCount,
            successfulSessionsCount: successfulSessionsCount,
            failedSessions: failedSessions,
            warnings: warnings
        )
    }

    static var empty: NDISBillingReport { fixture() }
}
#endif
