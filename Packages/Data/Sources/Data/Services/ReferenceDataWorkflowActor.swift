import Foundation
import SwiftData
import PersistenceModels

/// A background actor dedicated to fetching references (PersistentIdentifiers) of core data
/// so that ViewModels can populate pickers and drop-downs asynchronously without
/// blocking the main thread or using unbounded `@Query` property wrappers.
@ModelActor
public actor ReferenceDataWorkflowActor {

    /// Fetches all Client persistent identifiers, sorted by full name.
    public func fetchAllClientIDs() throws -> [PersistentIdentifier] {
        var descriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
        descriptor.propertiesToFetch = [\.fullName] // Optimize fetch if supported by backend
        let clients = try modelContext.fetch(descriptor)
        return clients.map(\.id) // SwiftData PersistentIdentifier
    }

    /// Fetches all Payee persistent identifiers, sorted by full name.
    public func fetchAllPayeeIDs() throws -> [PersistentIdentifier] {
        var descriptor = FetchDescriptor<Payee>(sortBy: [SortDescriptor(\.fullName)])
        descriptor.propertiesToFetch = [\.fullName]
        let payees = try modelContext.fetch(descriptor)
        return payees.map(\.id)
    }

    /// Fetches all PlanManager persistent identifiers, sorted by name.
    public func fetchAllPlanManagerIDs() throws -> [PersistentIdentifier] {
        var descriptor = FetchDescriptor<PlanManager>(sortBy: [SortDescriptor(\.name)])
        descriptor.propertiesToFetch = [\.name]
        let managers = try modelContext.fetch(descriptor)
        return managers.map(\.id)
    }

    /// Fetches all Business persistent identifiers, sorted by name.
    public func fetchAllBusinessIDs() throws -> [PersistentIdentifier] {
        var descriptor = FetchDescriptor<Business>(sortBy: [SortDescriptor(\.name)])
        descriptor.propertiesToFetch = [\.name]
        let businesses = try modelContext.fetch(descriptor)
        return businesses.map(\.id)
    }
    
    /// Fetches unbilled drafted sessions (BillableDraft) to show in the Claim Wizard
    public func fetchUnbilledDraftIDs() throws -> [PersistentIdentifier] {
        let readyStatus = "ready"
        let lockedStatus = "locked"
        let predicate = #Predicate<BillableDraft> {
            $0.draftStatus == readyStatus || $0.draftStatus == lockedStatus
        }
        let descriptor = FetchDescriptor<BillableDraft>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
        )
        let drafts = try modelContext.fetch(descriptor)
        return drafts.map(\.id)
    }

    /// Fetches all NDISItem persistent identifiers, sorted by item number.
    public func fetchAllNDISItemIDs() throws -> [PersistentIdentifier] {
        var descriptor = FetchDescriptor<NDISItem>(sortBy: [SortDescriptor(\.itemNumber)])
        descriptor.propertiesToFetch = [\.itemNumber]
        let items = try modelContext.fetch(descriptor)
        return items.map(\.id)
    }

    /// Fetches all Invoice persistent identifiers, sorted by issue date descending.
    public func fetchAllInvoiceIDs() throws -> [PersistentIdentifier] {
        let descriptor = FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.issueDate, order: .reverse)])
        let invoices = try modelContext.fetch(descriptor)
        return invoices.map(\.id)
    }

    /// Fetches all Session persistent identifiers, sorted by start time.
    public func fetchAllSessionIDs() throws -> [PersistentIdentifier] {
        let descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startTime)])
        let sessions = try modelContext.fetch(descriptor)
        return sessions.map(\.id)
    }

    /// Fetches Session persistent identifiers within a date range that have a client and service.
    public func fetchSessionIDs(from start: Date, to end: Date) throws -> [PersistentIdentifier] {
        let predicate = #Predicate<Session> { session in
            if let st = session.startTime {
                return st >= start && st <= end && session.client != nil && session.clientService != nil
            } else {
                return false
            }
        }
        let descriptor = FetchDescriptor<Session>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(\.id)
    }

    /// Fetches all BulkClaimBatch persistent identifiers, sorted by creation date descending.
    public func fetchAllBulkClaimBatchIDs() throws -> [PersistentIdentifier] {
        let descriptor = FetchDescriptor<BulkClaimBatch>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let batches = try modelContext.fetch(descriptor)
        return batches.map(\.id)
    }

    /// Fetches all TravelChargeReviewItem persistent identifiers, sorted by timestamp descending.
    public func fetchAllTravelChargeReviewItemIDs() throws -> [PersistentIdentifier] {
        let descriptor = FetchDescriptor<TravelChargeReviewItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let items = try modelContext.fetch(descriptor)
        return items.map(\.id)
    }

    /// Fetches BulkClaimLine persistent identifiers for a specific batch, sorted by support delivered from.
    public func fetchBulkClaimLineIDs(forBatch batchId: UUID) throws -> [PersistentIdentifier] {
        let predicate = #Predicate<BulkClaimLine> { line in line.batch?.id == batchId }
        let descriptor = FetchDescriptor<BulkClaimLine>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.supportsDeliveredFrom)]
        )
        let lines = try modelContext.fetch(descriptor)
        return lines.map(\.id)
    }

    // MARK: - Client & Billing Relationship Fetches

    /// Fetches ClientService persistent identifiers for a specific client, sorted by start date descending.
    public func fetchClientServiceIDs(forClient clientId: UUID) throws -> [PersistentIdentifier] {
        let predicate = #Predicate<ClientService> { $0.client?.id == clientId }
        let descriptor = FetchDescriptor<ClientService>(predicate: predicate, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.id)
    }

    /// Fetches Invoice persistent identifiers for a specific client, sorted by issue date descending.
    public func fetchInvoiceIDs(forClient clientId: UUID) throws -> [PersistentIdentifier] {
        let predicate = #Predicate<Invoice> { $0.client?.id == clientId }
        let descriptor = FetchDescriptor<Invoice>(predicate: predicate, sortBy: [SortDescriptor(\.issueDate, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.id)
    }

    /// Fetches ServiceAgreement persistent identifiers for a specific client, sorted by effective from date descending.
    public func fetchServiceAgreementIDs(forClient clientId: UUID) throws -> [PersistentIdentifier] {
        let predicate = #Predicate<ServiceAgreement> { $0.client?.id == clientId }
        let descriptor = FetchDescriptor<ServiceAgreement>(predicate: predicate, sortBy: [SortDescriptor(\.effectiveFrom, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.id)
    }

    /// Fetches Invoice persistent identifiers for a specific payee (Client with isPayee == true).
    public func fetchInvoiceIDs(forPayee payeeId: UUID) throws -> [PersistentIdentifier] {
        let predicate = #Predicate<Invoice> { $0.payee?.id == payeeId }
        let descriptor = FetchDescriptor<Invoice>(predicate: predicate, sortBy: [SortDescriptor(\.issueDate, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.id)
    }

    /// Fetches Client persistent identifiers that are associated with a specific payee.
    public func fetchClientIDs(associatedWithPayee payeeId: UUID) throws -> [PersistentIdentifier] {
        let predicate = #Predicate<Client> { $0.payee?.id == payeeId }
        let descriptor = FetchDescriptor<Client>(predicate: predicate, sortBy: [SortDescriptor(\.fullName)])
        return try modelContext.fetch(descriptor).map(\.id)
    }

    /// Fetches Invoice persistent identifiers for a specific plan manager.
    public func fetchInvoiceIDs(forPlanManager planManagerId: UUID) throws -> [PersistentIdentifier] {
        let predicate = #Predicate<Invoice> { $0.client?.planManager?.id == planManagerId }
        let descriptor = FetchDescriptor<Invoice>(predicate: predicate, sortBy: [SortDescriptor(\.issueDate, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.id)
    }

    /// Fetches Client persistent identifiers that are managed by a specific plan manager.
    public func fetchClientIDs(managedBy planManagerId: UUID) throws -> [PersistentIdentifier] {
        let predicate = #Predicate<Client> { $0.planManager?.id == planManagerId }
        let descriptor = FetchDescriptor<Client>(predicate: predicate, sortBy: [SortDescriptor(\.fullName)])
        return try modelContext.fetch(descriptor).map(\.id)
    }
}
