import Foundation

/// Use case for creating invoices from sessions
public struct CreateInvoiceFromSessions: Sendable {
    private let invoicesRepository: InvoicesRepository
    private let sessionsRepository: SessionsRepository
    private let clientsRepository: ClientsRepository
    
    public init(
        invoicesRepository: InvoicesRepository,
        sessionsRepository: SessionsRepository,
        clientsRepository: ClientsRepository
    ) {
        self.invoicesRepository = invoicesRepository
        self.sessionsRepository = sessionsRepository
        self.clientsRepository = clientsRepository
    }
    
    /// Create an invoice from grouped sessions
    public func callAsFunction(_ sessionIds: [UUID]) async throws -> Invoice {
        guard !sessionIds.isEmpty else {
            throw InvoiceError.noSessionsProvided
        }
        
        // Fetch sessions
        let sessions = try await withThrowingTaskGroup(of: Session?.self) { group in
            var fetchedSessions: [Session] = []
            
            for sessionId in sessionIds {
                group.addTask { [sessionsRepository] in
                    try await sessionsRepository.fetch(byId: sessionId)
                }
            }
            
            for try await session in group {
                if let session = session {
                    fetchedSessions.append(session)
                }
            }
            
            return fetchedSessions
        }
        
        guard !sessions.isEmpty else {
            throw InvoiceError.sessionsNotFound
        }
        
        // Validate all sessions belong to the same client
        guard let firstClientId = sessions.first?.clientId else {
            throw InvoiceError.sessionsHaveNoClient
        }
        
        let allSameClient = sessions.allSatisfy { $0.clientId == firstClientId }
        guard allSameClient else {
            throw InvoiceError.sessionsHaveDifferentClients
        }
        
        // Fetch client information
        guard let client = try await clientsRepository.fetch(by: firstClientId) else {
            throw InvoiceError.clientNotFound
        }
        
        // Generate invoice number
        let invoiceNumber = try await invoicesRepository.generateInvoiceNumber()
        
        // Create invoice
        let invoice = Invoice(
            id: UUID(),
            invoiceNumber: invoiceNumber,
            dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            issueDate: Date(),
            status: "draft",
            clientName: client.fullName,
            clientNDISNumber: client.ndisNumber,
            clientEmail: client.email,
            clientPhone: client.phone,
            clientAddress: client.address?.fullFormattedAddress,
            clientId: firstClientId,
            sessionIds: sessionIds
        )
        
        let createdInvoice = try await invoicesRepository.create(invoice)
        
        // Update session statuses to indicate they're now part of an invoice
        for sessionId in sessionIds {
            try await sessionsRepository.updateBillingStatus(id: sessionId, status: .reviewDrafts)
        }
        
        return createdInvoice
    }
}

