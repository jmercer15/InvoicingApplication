import Foundation
import SwiftData
import Core
import Data

extension ClientDetailViewModel {

    // MARK: - Persistent Save

    func updateAndSaveClient() {
        guard !isCreatingNew else { return }
        Task { await saveClientUpdates() }
    }

    func saveClientUpdates() async {
        client.ndisNumber          = editableNdisNumber
        client.fullName            = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        client.status              = ClientStatus(rawValue: editableStatus.lowercased()) ?? client.status
        client.email               = emailValidator.isValid  ? emailValidator.email         : client.email
        client.notes               = editableNotes.isEmpty   ? nil                          : editableNotes
        client.phone               = phoneFormatter.isValid  ? phoneFormatter.phoneNumber   : client.phone
        client.creditAmount        = Double(editableCreditAmountString) ?? client.creditAmount
        client.isMinor             = editableIsMinor
        client.hasNdisPlan         = editableHasNdisPlan
        client.planManagementType  = editablePlanManagementType
        client.billingAuthority    = editableBillingAuthority
        client.planManager         = selectedPlanManager
        client.payee               = selectedPayee

        if isEditingAddress || !editableStreetName.isEmpty || !editableStreetNumber.isEmpty {
            let address = client.address ?? Address()
            if client.address == nil { modelContext.insert(address); client.address = address }
            applyEditableAddressFields(to: address)
        }

        do {
            try modelContext.save()
            selectedPlanManager = client.planManager
            selectedPayee       = client.payee
        } catch {
            let nsError = error as NSError
            alertTitle   = "Save Error"
            alertMessage = "Could not save changes: \(nsError.localizedDescription)"
            showAlert    = true
        }
    }

    func updateAndSaveClientToggle(
        sendInvoicesToClient: Bool?      = nil,
        sendInvoicesToPayee: Bool?       = nil,
        sendInvoicesToPlanManager: Bool? = nil
    ) {
        if let v = sendInvoicesToClient      { client.sendInvoicesToClient      = v }
        if let v = sendInvoicesToPayee       { client.sendInvoicesToPayee       = v }
        if let v = sendInvoicesToPlanManager { client.sendInvoicesToPlanManager = v }
        do { try modelContext.save() } catch {
            print("❌ [ClientDetailViewModel] Error updating client toggles: \(error)")
        }
    }

    // MARK: - Payee / Plan Manager Selection

    func updatePayee(by id: UUID?) {
        Task {
            selectedPayee = id.flatMap { uid in payeeCatalogue.first { $0.id == uid } }
            await saveClientUpdates()
        }
    }

    func updatePlanManager(by id: UUID?) {
        Task {
            selectedPlanManager = id.flatMap { uid in planManagerCatalogue.first { $0.id == uid } }
            await saveClientUpdates()
        }
    }

    // MARK: - Primary Save / Create

    func saveClientDetailsAndDismiss() {
        let trimmedName = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { fullNameError = "Full Name cannot be empty."; return }

        if !emailValidator.email.isEmpty && !emailValidator.isValid {
            alertTitle   = "Validation Error"
            alertMessage = "Invalid email address."
            showAlert    = true
            return
        }

        Task {
            if isCreatingNew { await createNewClient() } else { await saveClientUpdates() }
            if isCreatingNew { dismiss() }
        }
    }

    func createNewClient() async {
        client.ndisNumber          = editableNdisNumber
        client.fullName            = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        client.status              = ClientStatus(rawValue: editableStatus.lowercased()) ?? client.status
        client.email               = emailValidator.isValid ? emailValidator.email   : nil
        client.notes               = editableNotes.isEmpty  ? nil                    : editableNotes
        client.phone               = phoneFormatter.isValid ? phoneFormatter.phoneNumber : nil
        client.creditAmount        = Double(editableCreditAmountString) ?? 0.0
        client.isMinor             = editableIsMinor
        client.hasNdisPlan         = editableHasNdisPlan
        client.planManagementType  = editablePlanManagementType
        client.billingAuthority    = editableBillingAuthority
        client.planManager         = selectedPlanManager
        client.payee               = selectedPayee

        if !editableStreetName.isEmpty || !editableStreetNumber.isEmpty || !editableSuburb.isEmpty || !editableCity.isEmpty {
            let address = client.address ?? Address()
            if client.address == nil { modelContext.insert(address); client.address = address }
            applyEditableAddressFields(to: address)
        }

        modelContext.insert(client)
        do {
            try modelContext.save()
        } catch {
            let nsError = error as NSError
            alertTitle   = "Save Error"
            alertMessage = "Could not save client: \(nsError.localizedDescription)"
            showAlert    = true
        }
    }
}
