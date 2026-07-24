import Foundation
import SwiftData
import Core
import Data

extension NewSessionViewModel {

    func loadAvailableClients() async {
        // Yield to ensure UI layout finishes before database work
        try? await Task.sleep(for: .milliseconds(50))
        var descriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
        // Optimize payload
        descriptor.propertiesToFetch = [\.fullName, \.email, \.ndisNumber]
        if let clients = try? self.modelContext.fetch(descriptor) {
            self.availableClients = clients
        }
    }

    // MARK: - Client Selection

    func handleClientSelectionChange(from previousID: UUID?, to newID: UUID?) {
        lastSelectedClientID = newID
        clientLookupTask?.cancel()
        serviceLookupTask?.cancel()

        guard let newID else {
            selectedClient         = nil
            selectedClientService  = nil
            availableServices      = []
            servicesLoadedForClientID = nil
            return
        }

        if let previousID, previousID != newID {
            selectedClientService = nil
        }
        availableServices         = []
        servicesLoadedForClientID = nil

        let requestedClientID = newID
        clientLookupTask = Task { [weak self] in
            guard let self else { return }

            let localClient   = self.availableClients.first(where: { $0.id == requestedClientID })
            let localServices = self.localClientServices(for: requestedClientID)

            guard !Task.isCancelled else { return }
            guard self.formModel.selectedClientID == requestedClientID else { return }

            self.selectedClient = localClient
            if !localServices.isEmpty {
                self.availableServices      = localServices
                self.servicesLoadedForClientID = requestedClientID
                if let selectedServiceID = self.formModel.selectedClientServiceID {
                    self.selectedClientService = localServices.first(where: { $0.id == selectedServiceID })
                } else {
                    self.selectedClientService = nil
                }
                self.reconcilePickerSelections()
                return
            }

            let fetchedClient   = try? self.fetchClient(id: requestedClientID)
            let fetchedServices = (try? self.fetchClientServices(for: requestedClientID)) ?? []

            guard !Task.isCancelled else { return }
            guard self.formModel.selectedClientID == requestedClientID else { return }

            self.selectedClient        = fetchedClient ?? localClient
            self.availableServices     = fetchedServices
            self.servicesLoadedForClientID = requestedClientID

            if let selectedServiceID = self.formModel.selectedClientServiceID {
                self.selectedClientService = fetchedServices.first(where: { $0.id == selectedServiceID })
            } else {
                self.selectedClientService = nil
            }
            self.reconcilePickerSelections()
        }
    }

    func handleServiceSelectionChange(to newID: UUID?) {
        serviceLookupTask?.cancel()
        guard let newID else { selectedClientService = nil; return }

        if let localMatch = availableServices.first(where: { $0.id == newID }) {
            selectedClientService = localMatch
            return
        }

        guard let clientId = formModel.selectedClientID else { selectedClientService = nil; return }

        let requestedClientID  = clientId
        let requestedServiceID = newID
        serviceLookupTask = Task { [weak self] in
            guard let self else { return }

            let localServices = self.localClientServices(for: requestedClientID)
            if !localServices.isEmpty {
                guard !Task.isCancelled else { return }
                guard self.formModel.selectedClientID == requestedClientID,
                      self.formModel.selectedClientServiceID == requestedServiceID else { return }
                self.availableServices      = localServices
                self.servicesLoadedForClientID = requestedClientID
                self.selectedClientService  = localServices.first(where: { $0.id == requestedServiceID })
                self.reconcilePickerSelections()
                return
            }

            let services = (try? self.fetchClientServices(for: requestedClientID)) ?? []
            guard !Task.isCancelled else { return }
            guard self.formModel.selectedClientID == requestedClientID,
                  self.formModel.selectedClientServiceID == requestedServiceID else { return }
            self.availableServices      = services
            self.servicesLoadedForClientID = requestedClientID
            self.selectedClientService  = services.first(where: { $0.id == requestedServiceID })
            self.reconcilePickerSelections()
        }
    }

    func fetchClient(id: UUID) throws -> Client? {
        availableClients.first(where: { $0.id == id })
    }

    func fetchClientServices(for clientId: UUID) throws -> [ClientService] {
        localClientServices(for: clientId)
    }

    func localClientServices(for clientId: UUID) -> [ClientService] {
        guard let localClient = availableClients.first(where: { $0.id == clientId }),
              let services = localClient.clientServices else { return [] }
        return services.sorted {
            $0.serviceName.localizedCaseInsensitiveCompare($1.serviceName) == .orderedAscending
        }
    }

    func updateSelectedClientID(_ newID: UUID?) {
        var updated = formModel
        let previousID = updated.selectedClientID
        updated.selectedClientID = newID
        if previousID != newID {
            updated.selectedClientServiceID = nil
            servicesLoadedForClientID = nil
        }
        formModel = updated
    }

    func updateSelectedClientServiceID(_ newID: UUID?) {
        var updated = formModel
        updated.selectedClientServiceID = newID
        formModel = updated
    }

    func resolveClientService(for serviceID: UUID) -> ClientService? {
        if selectedClientService?.id == serviceID { return selectedClientService }
        return availableServices.first(where: { $0.id == serviceID })
    }

    func preloadSessionRelationships(sessionID: UUID) async -> PreloadedSessionData {
        await sessionPrefetcher.load(sessionID: sessionID)
    }

    func applyPreloadedSessionData(_ data: PreloadedSessionData) {
        if let resolvedClientID = data.clientID {
            selectedClient = availableClients.first(where: { $0.id == resolvedClientID })

            var updated = formModel
            if updated.selectedClientID != resolvedClientID { updated.selectedClientID = resolvedClientID }
            if let resolvedServiceID = data.clientServiceID {
                updated.selectedClientServiceID = resolvedServiceID
            }
            formModel = updated

            let services = localClientServices(for: resolvedClientID)
            availableServices      = services
            servicesLoadedForClientID = resolvedClientID

            if let resolvedServiceID = data.clientServiceID {
                selectedClientService = services.first(where: { $0.id == resolvedServiceID })
                if selectedClientService == nil {
                    let descriptor = FetchDescriptor<ClientService>()
                    if let allServices = try? modelContext.fetch(descriptor) {
                        selectedClientService = allServices.first(where: { $0.id == resolvedServiceID })
                        if let selectedClientService, !availableServices.contains(where: { $0.id == resolvedServiceID }) {
                            availableServices.insert(selectedClientService, at: 0)
                        }
                    }
                }
            }
        }

        if let supportLog = data.supportLog {
            var updated = formModel
            updated.supportLogDraft = supportLog
            formModel = updated
        }

        reconcilePickerSelections()
    }

    func reconcilePickerSelections() {
        let validServiceIDs = Set(availableServices.map(\.id) + (selectedClientService.map { [$0.id] } ?? []))

        var updated = formModel
        var changed = false

        if updated.selectedClientID == nil, updated.selectedClientServiceID != nil {
            updated.selectedClientServiceID = nil
            selectedClientService = nil
            changed = true
        }

        if let selectedServiceID = updated.selectedClientServiceID,
           let selectedClientID  = updated.selectedClientID,
           servicesLoadedForClientID == selectedClientID,
           !validServiceIDs.contains(selectedServiceID) {
            updated.selectedClientServiceID = nil
            selectedClientService = nil
            changed = true
        }

        if changed { formModel = updated }
    }
}
