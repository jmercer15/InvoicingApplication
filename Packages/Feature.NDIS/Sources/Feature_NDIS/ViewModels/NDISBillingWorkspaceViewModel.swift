import SwiftUI
import SwiftData
import Data
import Core

@MainActor
public final class NDISBillingWorkspaceViewModel: ObservableObject {
    @Published public var selectedClient: ClientEntity?
    @Published public var selectedSessions: [SessionEntity] = []
    @Published public var searchText: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var generatedInvoice: InvoiceEntity?
    @Published public var selectedSession: SessionEntity?
    @Published public var billingContext: NDISBillingContext = NDISBillingContext()
    @Published public var sessionContexts: [SessionEntity.ID: NDISBillingContext] = [:]
    @Published public var shouldAutoDetermine: Bool = false
    @Published public var isClientSectionExpanded: Bool = true
    @Published public var isSessionSectionExpanded: Bool = true
    @Published public var isPerSessionBillingExpanded: Bool = true
    @Published public var expandedSessionIds: Set<SessionEntity.ID> = []

    private var modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func updateContextIfNeeded(_ newContext: ModelContext) {
        guard modelContext !== newContext else { return }
        modelContext = newContext
    }

    private var billingService: NDISBillingIntegrationService {
        NDISBillingIntegrationService(modelContext: modelContext)
    }

    public var allClients: [ClientEntity] {
        let descriptor = FetchDescriptor<ClientEntity>(sortBy: [SortDescriptor(\.fullName)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func filteredClients() -> [ClientEntity] {
        guard !searchText.isEmpty else { return allClients }
        return allClients.filter { client in
            client.fullName.localizedCaseInsensitiveContains(searchText) ||
            client.ndisNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    public func sessions(for client: ClientEntity) -> [SessionEntity] {
        let clientId = client.id
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: #Predicate { $0.client?.id == clientId },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func toggleSession(_ session: SessionEntity) {
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

    public func selectClient(_ client: ClientEntity?) {
        selectedClient = client
        selectedSessions.removeAll()
        selectedSession = nil
        billingContext = NDISBillingContext()
        sessionContexts = [:]
        expandedSessionIds.removeAll()
        shouldAutoDetermine = false
    }

    public func contextBinding(for session: SessionEntity) -> Binding<NDISBillingContext> {
        Binding(
            get: { [weak self] in
                self?.sessionContexts[session.id] ?? NDISBillingContext()
            },
            set: { [weak self] newValue in
                self?.sessionContexts[session.id] = newValue
            }
        )
    }

    public func refreshAutomation() {
        guard let first = selectedSessions.first else {
            selectedSession = nil
            billingContext = NDISBillingContext()
            sessionContexts = [:]
            shouldAutoDetermine = false
            return
        }

        selectedSession = first
        let orchestrator = NDISBillingAutomationOrchestrator(modelContext: modelContext)

        Task {
            for session in selectedSessions {
                var context = sessionContexts[session.id] ?? billingContext
                _ = await orchestrator.executeAutomationFlow(for: session, context: &context)
                await MainActor.run {
                    self.sessionContexts[session.id] = context
                }
            }
            await MainActor.run {
                self.shouldAutoDetermine = true
            }
        }
    }

    public func generateInvoice() {
        guard !selectedSessions.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let client = selectedClient else {
                    await MainActor.run {
                        self.errorMessage = "No client selected"
                        self.isLoading = false
                    }
                    return
                }

                let invoice = try billingService.generateNDISInvoice(
                    for: selectedSessions,
                    client: client
                )

                await MainActor.run {
                    self.generatedInvoice = invoice
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
