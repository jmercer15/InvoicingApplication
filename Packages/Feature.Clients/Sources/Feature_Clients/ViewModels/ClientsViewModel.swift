import Foundation
import SwiftUI
import Core

/// ViewModel for the Clients feature using clean architecture
@MainActor
public class ClientsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public var clients: [Client] = []
    @Published public var selectedClient: Client?
    @Published public var searchText: String = ""
    @Published public var selectedStatusFilter: String? = nil
    @Published public var isShowingNewClientSheet: Bool = false
    @Published public var isShowingEditClientSheet: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var error: Error?
    @Published public private(set) var lastUpdated: Date = Date()
    
    // MARK: - Dependencies
    private let unitOfWork: UnitOfWorkService
    
    // MARK: - Initialization
    public init(unitOfWork: UnitOfWorkService) {
        self.unitOfWork = unitOfWork
        
        Task {
            await loadClients()
        }
    }
    
    // MARK: - Computed Properties
    
    public var filteredClients: [Client] {
        var filtered = clients
        
        // Filter by search text
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = filtered.filter { client in
                client.fullName.localizedCaseInsensitiveContains(searchText) ||
                client.ndisNumber.localizedCaseInsensitiveContains(searchText) ||
                client.email?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Filter by status
        if let statusFilter = selectedStatusFilter {
            filtered = filtered.filter { $0.status == statusFilter }
        }
        
        return filtered.sorted { $0.fullName < $1.fullName }
    }
    
    public var availableStatuses: [String] {
        let statuses = Set(clients.map { $0.status })
        return Array(statuses).sorted()
    }
    
    public var activeClientsCount: Int {
        clients.filter { $0.status == "active" }.count
    }
    
    public var totalClientsCount: Int {
        clients.count
    }
    
    // MARK: - Public Methods
    
    public func loadClients() async {
        isLoading = true
        error = nil
        
        do {
            clients = try await unitOfWork.clients.fetchAll()
            lastUpdated = Date()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    public func createClient(_ client: Client) async {
        do {
            let createdClient = try await unitOfWork.clients.create(client)
            clients.append(createdClient)
            lastUpdated = Date()
        } catch {
            self.error = error
        }
    }
    
    public func updateClient(_ client: Client) async {
        do {
            let updatedClient = try await unitOfWork.clients.update(client)
            if let index = clients.firstIndex(where: { $0.id == client.id }) {
                clients[index] = updatedClient
            }
            lastUpdated = Date()
        } catch {
            self.error = error
        }
    }
    
    public func deleteClient(_ client: Client) async {
        do {
            try await unitOfWork.clients.delete(id: client.id)
            clients.removeAll { $0.id == client.id }
            lastUpdated = Date()
        } catch {
            self.error = error
        }
    }
    
    public func archiveClient(_ client: Client) async {
        do {
            try await unitOfWork.clients.archive(id: client.id)
            if let index = clients.firstIndex(where: { $0.id == client.id }) {
                var updatedClient = clients[index]
                // Update status to archived
                let archivedClient = Client(
                    id: updatedClient.id,
                    ndisNumber: updatedClient.ndisNumber,
                    fullName: updatedClient.fullName,
                    status: "archived",
                    // colorHex property removed - using deterministic color system instead
                    email: updatedClient.email,
                    notes: updatedClient.notes,
                    phone: updatedClient.phone,
                    creditAmount: updatedClient.creditAmount,
                    isMinor: updatedClient.isMinor,
                    hasNdisPlan: updatedClient.hasNdisPlan,
                    planManagementType: updatedClient.planManagementType,
                    billingAuthority: updatedClient.billingAuthority,
                    address: updatedClient.address,
                    planManager: updatedClient.planManager,
                    payee: updatedClient.payee,
                    sendInvoicesToClient: updatedClient.sendInvoicesToClient,
                    sendInvoicesToPayee: updatedClient.sendInvoicesToPayee,
                    sendInvoicesToPlanManager: updatedClient.sendInvoicesToPlanManager
                )
                clients[index] = archivedClient
            }
            lastUpdated = Date()
        } catch {
            self.error = error
        }
    }
    
    public func reactivateClient(_ client: Client) async {
        do {
            try await unitOfWork.clients.reactivate(id: client.id)
            if let index = clients.firstIndex(where: { $0.id == client.id }) {
                var updatedClient = clients[index]
                // Update status to active
                let activeClient = Client(
                    id: updatedClient.id,
                    ndisNumber: updatedClient.ndisNumber,
                    fullName: updatedClient.fullName,
                    status: "active",
                    // colorHex property removed - using deterministic color system instead
                    email: updatedClient.email,
                    notes: updatedClient.notes,
                    phone: updatedClient.phone,
                    creditAmount: updatedClient.creditAmount,
                    isMinor: updatedClient.isMinor,
                    hasNdisPlan: updatedClient.hasNdisPlan,
                    planManagementType: updatedClient.planManagementType,
                    billingAuthority: updatedClient.billingAuthority,
                    address: updatedClient.address,
                    planManager: updatedClient.planManager,
                    payee: updatedClient.payee,
                    sendInvoicesToClient: updatedClient.sendInvoicesToClient,
                    sendInvoicesToPayee: updatedClient.sendInvoicesToPayee,
                    sendInvoicesToPlanManager: updatedClient.sendInvoicesToPlanManager
                )
                clients[index] = activeClient
            }
            lastUpdated = Date()
        } catch {
            self.error = error
        }
    }
    
    public func searchClients(query: String) async {
        do {
            let searchResults = try await unitOfWork.clients.search(query: query)
            // For now, we'll update the local clients array
            // In a more sophisticated implementation, you might want to maintain separate search results
            clients = searchResults
            lastUpdated = Date()
        } catch {
            self.error = error
        }
    }
    
    public func selectClient(_ client: Client?) {
        selectedClient = client
    }
    
    public func showNewClientSheet() {
        isShowingNewClientSheet = true
    }
    
    public func hideNewClientSheet() {
        isShowingNewClientSheet = false
    }
    
    public func showEditClientSheet(for client: Client) {
        selectedClient = client
        isShowingEditClientSheet = true
    }
    
    public func hideEditClientSheet() {
        isShowingEditClientSheet = false
        selectedClient = nil
    }
    
    public func clearFilters() {
        searchText = ""
        selectedStatusFilter = nil
    }
    
    public func refresh() async {
        await loadClients()
    }
    
    // MARK: - Client Statistics
    
    /// Compute real client statistics from session and invoice data
    public func getClientStatistics(for client: Client) async -> ClientStatistics {
        do {
            let sessions = try await unitOfWork.sessions.fetch(byClientId: client.id)
            
            let totalSessions = sessions.count
            
            // Calculate total hours from session durations
            let totalHours = sessions.reduce(0.0) { sum, session in
                guard let start = session.startTime, let end = session.endTime else { return sum }
                let duration = end.timeIntervalSince(start) / 3600.0 // Convert seconds to hours
                return sum + duration
            }
            
            // Calculate total revenue from invoices if available
            var totalRevenue = 0.0
            
            let invoices = try await unitOfWork.invoices.fetch(byClientId: client.id)
            totalRevenue = invoices.reduce(0.0) { $0 + $1.totalAmount }
            
            // Find last session date
            let lastSessionDate = sessions
                .compactMap { $0.startTime }
                .sorted()
                .last
            
            // Calculate average session duration
            let averageSessionDuration = totalSessions > 0 ? totalHours / Double(totalSessions) : 0.0
            
            return ClientStatistics(
                totalSessions: totalSessions,
                totalHours: totalHours,
                totalRevenue: totalRevenue,
                lastSessionDate: lastSessionDate,
                averageSessionDuration: averageSessionDuration
            )
        } catch {
            // On error, return default statistics
            return ClientStatistics(
                totalSessions: 0,
                totalHours: 0.0,
                totalRevenue: 0.0,
                lastSessionDate: nil,
                averageSessionDuration: 0.0
            )
        }
    }
}

// MARK: - Supporting Types

public struct ClientStatistics {
    public let totalSessions: Int
    public let totalHours: Double
    public let totalRevenue: Double
    public let lastSessionDate: Date?
    public let averageSessionDuration: Double
    
    public init(
        totalSessions: Int,
        totalHours: Double,
        totalRevenue: Double,
        lastSessionDate: Date?,
        averageSessionDuration: Double
    ) {
        self.totalSessions = totalSessions
        self.totalHours = totalHours
        self.totalRevenue = totalRevenue
        self.lastSessionDate = lastSessionDate
        self.averageSessionDuration = averageSessionDuration
    }
}
