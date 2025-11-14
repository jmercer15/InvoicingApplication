import SwiftUI
import SwiftData
import Data
import Core

@MainActor
public final class NDISBillingWorkspaceViewModel: ObservableObject {
    // MARK: - Dependencies
    private let clientsRepository: ClientsRepository
    private let sessionsRepository: SessionsRepository
    private let invoicesRepository: InvoicesRepository
    private let ndisBillingService: NDISBillingIntegrationService
    private var modelContext: ModelContext // Needed only for NDISBillingAutomationOrchestrator which requires entities
    
    // MARK: - Published Properties (Domain Models)
    @Published public var selectedClient: Client?
    @Published public var selectedSessions: [Session] = []
    @Published public var searchText: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var generatedInvoice: Invoice?
    @Published public var selectedSession: Session?
    @Published public var billingContext: NDISBillingContext = NDISBillingContext()
    @Published public var sessionContexts: [UUID: NDISBillingContext] = [:]
    @Published public var shouldAutoDetermine: Bool = false
    @Published public var isClientSectionExpanded: Bool = true
    @Published public var isSessionSectionExpanded: Bool = true
    @Published public var isPerSessionBillingExpanded: Bool = true
    @Published public var expandedSessionIds: Set<UUID> = []
    
    // MARK: - Cached Data
    @Published private(set) var allClients: [Client] = []

    public init(
        clientsRepository: ClientsRepository,
        sessionsRepository: SessionsRepository,
        invoicesRepository: InvoicesRepository,
        ndisBillingService: NDISBillingIntegrationService,
        modelContext: ModelContext
    ) {
        self.clientsRepository = clientsRepository
        self.sessionsRepository = sessionsRepository
        self.invoicesRepository = invoicesRepository
        self.ndisBillingService = ndisBillingService
        self.modelContext = modelContext
        Task {
            await loadClients()
        }
    }

    public func updateContextIfNeeded(_ newContext: ModelContext) {
        guard modelContext !== newContext else { return }
        self.modelContext = newContext
    }

    // MARK: - Data Loading
    
    private func loadClients() async {
        do {
            let clients = try await clientsRepository.fetchAll()
            await MainActor.run {
                self.allClients = clients.sorted { $0.fullName < $1.fullName }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load clients: \(error.localizedDescription)"
            }
        }
    }
    
    public func filteredClients() -> [Client] {
        guard !searchText.isEmpty else { return allClients }
        return allClients.filter { client in
            client.fullName.localizedCaseInsensitiveContains(searchText) ||
            client.ndisNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    public func sessions(for client: Client) async throws -> [Session] {
        try await sessionsRepository.fetch(byClientId: client.id)
            .sorted { ($0.startTime ?? Date.distantPast) > ($1.startTime ?? Date.distantPast) }
    }

    // MARK: - Session Management
    
    public func toggleSession(_ session: Session) {
        if let index = selectedSessions.firstIndex(where: { $0.id == session.id }) {
            selectedSessions.remove(at: index)
        } else {
            selectedSessions.append(session)
        }
        refreshAutomation()
    }

    public func clearSessions() {
        selectedSessions.removeAll()
        expandedSessionIds.removeAll()
        shouldAutoDetermine = false
        selectedSession = nil
        billingContext = NDISBillingContext()
        sessionContexts.removeAll()
    }

    public func selectClient(_ client: Client?) {
        selectedClient = client
        selectedSessions.removeAll()
        selectedSession = nil
        billingContext = NDISBillingContext()
        sessionContexts = [:]
        expandedSessionIds.removeAll()
        shouldAutoDetermine = false
    }

    public func contextBinding(for session: Session) -> Binding<NDISBillingContext> {
        Binding(
            get: { [weak self] in
                self?.sessionContexts[session.id] ?? NDISBillingContext()
            },
            set: { [weak self] newValue in
                self?.sessionContexts[session.id] = newValue
            }
        )
    }

    // MARK: - Automation
    
    public func refreshAutomation() {
        guard let first = selectedSessions.first else {
            selectedSession = nil
            billingContext = NDISBillingContext()
            sessionContexts = [:]
            shouldAutoDetermine = false
            return
        }

        selectedSession = first
        
        // Note: NDISBillingAutomationOrchestrator requires entities, so we fetch them here
        // This is acceptable as it's a Data layer service
        Task { @MainActor in
            do {
                // Fetch entity for orchestrator (Data layer service needs entities)
                let entityFetch = try fetchSessionEntity(by: first.id)
                guard let sessionEntity = entityFetch else {
                    self.errorMessage = "Session not found"
                    return
                }
                
                let orchestrator = NDISBillingAutomationOrchestrator(modelContext: modelContext)
                
                for session in selectedSessions {
                    // Fetch entity for each session
                    guard let sessionEntity = try? fetchSessionEntity(by: session.id) else { continue }
                    
                    var context = sessionContexts[session.id] ?? billingContext
                    _ = await orchestrator.executeAutomationFlow(for: sessionEntity, context: &context)
                    self.sessionContexts[session.id] = context
                }
                self.shouldAutoDetermine = true
            } catch {
                self.errorMessage = "Failed to refresh automation: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Invoice Generation
    
    public func generateInvoice() {
        guard !selectedSessions.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                guard let client = selectedClient else {
                    self.errorMessage = "No client selected"
                    self.isLoading = false
                    return
                }

                // Use domain model method from NDISBillingIntegrationService
                let invoice = try ndisBillingService.generateNDISInvoice(
                    for: selectedSessions,
                    client: client
                )

                self.generatedInvoice = invoice
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helper Methods (Entity Fetching for Orchestrator Only)
    
    /// Fetches a session entity by ID - required only for NDISBillingAutomationOrchestrator
    /// Note: The orchestrator is a Data layer service that requires entities for its automation flow.
    /// This is a minimal, localized violation needed for integration with legacy Data layer services.
    /// TODO: Future refactoring should migrate orchestrator to accept domain models.
    private func fetchSessionEntity(by id: UUID) throws -> SessionEntity? {
        let predicate = #Predicate<SessionEntity> { $0.id == id }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
}
