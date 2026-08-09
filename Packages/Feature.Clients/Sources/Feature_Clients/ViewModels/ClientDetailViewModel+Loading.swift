import SwiftUI
import SwiftData
import Core
import PersistenceModels
import SharedUI

extension ClientDetailViewModel {

    // MARK: - Data Loading

    func loadAllDetails() {
        loadClientDetails()
        loadAddressDetails()
    }

    /// Fetches all relationship data for the client asynchronously to prevent UI blocks.
    func refreshProjectedData() async {
        // Drop stale live refs before fetch — CloudKit HistoryExpired invalidates them.
        clientServices = []
        relatedInvoices = []
        serviceAgreements = []

        let clientID = client.id
        let services = (try? modelContext.fetch(FetchDescriptor<ClientService>(
            predicate: #Predicate { $0.client?.id == clientID }
        ))) ?? []
        let invoices = (try? modelContext.fetch(FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.client?.id == clientID }
        ))) ?? []
        let agreements = (try? modelContext.fetch(FetchDescriptor<ServiceAgreement>(
            predicate: #Predicate { $0.client?.id == clientID }
        ))) ?? []
        
        await refreshProjectedData(
            clientServices: services,
            relatedInvoices: invoices,
            serviceAgreements: agreements
        )
    }

    func loadReferencePickers() async {
        // Resolve on main context
        let payees = (try? modelContext.fetch(FetchDescriptor<Payee>())) ?? []
        let planManagers = (try? modelContext.fetch(FetchDescriptor<PlanManager>())) ?? []
        
        self.payeeCatalogue = payees
        self.planManagerCatalogue = planManagers
        
        if let id = selectedPayee?.id {
            selectedPayee = payees.first { $0.id == id } ?? selectedPayee
        }
        if let id = selectedPlanManager?.id {
            selectedPlanManager = planManagers.first { $0.id == id } ?? selectedPlanManager
        }
    }

    func refreshProjectedData(
        clientServices: [ClientService],
        relatedInvoices: [Invoice],
        serviceAgreements: [ServiceAgreement]
    ) async {
        self.clientServices    = clientServices
        self.relatedInvoices   = relatedInvoices
        self.serviceAgreements = serviceAgreements
    }

    func loadClientDetails() {
        editableFullName             = client.fullName
        editableNdisNumber           = client.ndisNumber
        editableStatus               = client.status?.rawValue ?? "active"
        editableColor                = NSColor(ColorSystem.Client.color(for: client.id))
        editableIsMinor              = client.isMinor
        editableHasNdisPlan          = client.hasNdisPlan
        editablePlanManagementType   = client.planManagementType
        editableCreditAmountString   = CurrencyFormatting.editableAmount(client.creditAmount)
        if let authority = client.billingAuthority { editableBillingAuthority = authority }
        editableNotes                = client.notes ?? ""
        phoneFormatter.phoneNumber   = client.phone ?? ""
        emailValidator.email         = client.email ?? ""
    }

    func loadAddressDetails() {
        loadAddressFields(from: client.address)
    }

    var assignedNDISItems: [NDISItem] {
        clientServices.compactMap { $0.ndisItem }
    }

}
