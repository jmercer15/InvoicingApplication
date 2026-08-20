import os
import Foundation
import SwiftData
import Core
import PersistenceModels
import Data

extension ClientDetailViewModel {

    // MARK: - Service Agreement Lifecycle

    func prepareToAddServiceAgreement() {
        serviceAgreementValidationError = nil
        let agreement = ServiceAgreement(id: UUID())
        agreement.client                       = client
        agreement.effectiveFrom                = Date()
        agreement.effectiveTo                  = nil
        agreement.pricingDisclosureAcceptedAt  = nil
        agreement.cancellationPolicyType       = CancellationPolicyType.twoClearBusinessDays.rawValue
        agreement.allowsProviderTravel         = false
        agreement.allowsTelehealth             = false
        agreement.allowsNonFaceToFace          = false
        agreement.participantSignatoryName     = nil
        agreement.participantSignatoryRole     = nil
        agreement.signedAt                     = nil
        agreement.signatureMethod              = SignatureMethod.attestation.rawValue
        agreement.notes                        = nil
        agreement.isArchived                   = false
        serviceAgreementToEdit             = agreement
        isPresentingServiceAgreementSheet  = true
    }

    func prepareToEditServiceAgreement(_ agreement: ServiceAgreement) {
        serviceAgreementValidationError    = nil
        serviceAgreementToEdit             = agreement
        isPresentingServiceAgreementSheet  = true
    }

    func cancelServiceAgreementEdit() {
        serviceAgreementValidationError    = nil
        serviceAgreementToEdit             = nil
        isPresentingServiceAgreementSheet  = false
    }

    func saveServiceAgreement() {
        guard let agreement = serviceAgreementToEdit else { return }
        serviceAgreementValidationError = nil

        Task {
            do {
                let excludingId    = serviceAgreements.contains(where: { $0.id == agreement.id }) ? agreement.id : nil
                let activeAgreements = serviceAgreements
                    .filter { $0.isArchived == false }
                    .filter { excludingId == nil ? true : $0.id != excludingId }

                let hasOverlap = activeAgreements.contains { existing in
                    let lhsStart = existing.effectiveFrom
                    let lhsEnd   = existing.effectiveTo   ?? .distantFuture
                    let rhsStart = agreement.effectiveFrom
                    let rhsEnd   = agreement.effectiveTo  ?? .distantFuture
                    return lhsStart <= rhsEnd && rhsStart <= lhsEnd
                }
                if hasOverlap {
                    await MainActor.run {
                        self.serviceAgreementValidationError = "Agreement dates overlap with an existing active agreement."
                    }
                    return
                }

                if !serviceAgreements.contains(where: { $0.id == agreement.id }) {
                    modelContext.insert(agreement)
                }
                try modelContext.save()
                await MainActor.run {
                    self.serviceAgreementToEdit            = nil
                    self.isPresentingServiceAgreementSheet = false
                    self.serviceAgreementValidationError   = nil
                }
            } catch {
                await MainActor.run {
                    self.serviceAgreementValidationError = error.localizedDescription
                }
            }
        }
    }

    func archiveServiceAgreement(_ agreement: ServiceAgreement) {
        Task {
            do {
                agreement.isArchived = true
                try modelContext.save()
            } catch {
                Logger.clients.warning("❌ [ClientDetailViewModel] Error archiving agreement: \(error)")
            }
        }
    }

    // MARK: - Client Service Edit

    func prepareToEditClientService(_ service: ClientService) {
        clientServiceValidationError = nil
        clientServiceToEdit = service
        isPresentingClientServiceSheet = true
    }

    func cancelClientServiceEdit() {
        clientServiceValidationError = nil
        clientServiceToEdit = nil
        isPresentingClientServiceSheet = false
    }

    func saveClientService() {
        guard let service = clientServiceToEdit else { return }
        clientServiceValidationError = nil

        let trimmedName = service.serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            clientServiceValidationError = "Service name is required."
            return
        }
        service.serviceName = trimmedName
        if let months = service.consecutiveMonths {
            service.consecutiveMonths = min(max(months, 1), 24)
        }

        Task {
            do {
                try modelContext.save()
                await MainActor.run {
                    self.clientServiceToEdit = nil
                    self.isPresentingClientServiceSheet = false
                    self.clientServiceValidationError = nil
                    self.loadAllDetails()
                }
            } catch {
                await MainActor.run {
                    self.clientServiceValidationError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Bulk Service Creation

    func prepareForBulkServiceCreation(from ndisItems: [NDISItem]) {
        let existingIDs = Set(serviceTemplates.map { $0.sourceNdisItem.id })
        let newTemplates = ndisItems
            .filter { !existingIDs.contains($0.id) }
            .map { ClientServiceTemplate(from: $0) }
        serviceTemplates.append(contentsOf: newTemplates)
        isPresentingServiceBulkEditor = true
    }

    func commitServices(fromTemplates templates: [ClientServiceTemplate]) {
        Task {
            do {
                for template in templates {
                    let newService = ClientService(
                        id: UUID(),
                        serviceName: template.serviceName,
                        unit: template.unit,
                        rate: template.rate
                    )
                    newService.client    = client
                    newService.isActive  = true
                    newService.startDate = Date()
                    newService.endDate   = nil
                    newService.status    = nil
                    newService.ndisCode  = template.ndisCode
                    newService.ndisItem  = template.sourceNdisItem
                    newService.consecutiveMonths = template.consecutiveMonths
                    modelContext.insert(newService)
                }
                try modelContext.save()
            } catch {
                Logger.clients.warning("❌ [ClientDetailViewModel] Error committing services: \(error)")
                alertTitle   = "Save Error"
                alertMessage = "Could not save services: \(error.localizedDescription)"
                showAlert    = true
            }
        }
    }
}
