import Core
import Foundation
import PersistenceModels
import SwiftData
import os

extension TravelChargeAutomationService {
    // MARK: - Proactive validation / mapping

    /// Maps a primary service's NDIS item to a corresponding travel or transport NDIS item.
    private func mapToTravelNDISItemAsync(session: SessionAutomationContext, chargeType: String) async -> NDISItemSnapshot? {
        guard let mainNDISItem = session.ndisItem else {
            Logger.automation.debug("Session has no ndisItem")
            return nil
        }

        let mainItemNumber = mainNDISItem.itemNumber
        let codeComponents = mainItemNumber.split(separator: "_")
        guard codeComponents.count >= 5 else {
            Logger.automation.debug("Invalid NDIS item number format: \(mainItemNumber)")
            return nil
        }

        let supportCategory = codeComponents[0]
        let registrationGroup = codeComponents[2]
        let outcomeDomain = codeComponents[3]
        let supportPurpose = codeComponents[4]

        switch chargeType {
        case "labour":
            return mainNDISItem
        case "non-labour":
            let travelItemNumber = "\(supportCategory)_799_\(registrationGroup)_\(outcomeDomain)_\(supportPurpose)"
            return try? fetchNDISItem(byItemNumber: String(travelItemNumber))
        case "activity-based":
            let travelItemNumber = "\(supportCategory)_590_\(registrationGroup)_\(outcomeDomain)_\(supportPurpose)"
            return try? fetchNDISItem(byItemNumber: String(travelItemNumber))
        default:
            return nil
        }
    }

    /// Finds a travel service for the client based on the session's NDIS Item and charge type.
    func findTravelServiceSnapshotAsync(client: ClientSnapshot?, session: SessionAutomationContext, chargeType: String) async -> ClientServiceSnapshot? {
        guard let client else { return nil }

        if chargeType == "labour" {
            return session.service
        }

        if let travelNDISItem = await mapToTravelNDISItemAsync(session: session, chargeType: chargeType) {
            let services = (try? fetchClientServices(for: client.id)) ?? []
            return services.first(where: { $0.ndisItemId == travelNDISItem.id })
        }

        return nil
    }

    // MARK: - SwiftData persistence

    func fetchClient(by id: UUID) throws -> ClientSnapshot? {
        let predicate = #Predicate<Client> { $0.id == id }
        let descriptor = FetchDescriptor<Client>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return entity.snapshot()
    }

    func fetchClientService(by id: UUID) throws -> ClientServiceSnapshot? {
        let predicate = #Predicate<ClientService> { $0.id == id }
        let descriptor = FetchDescriptor<ClientService>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return entity.snapshot()
    }

    func fetchNDISItem(by id: UUID) throws -> NDISItemSnapshot? {
        let predicate = #Predicate<NDISItem> { $0.id == id }
        let descriptor = FetchDescriptor<NDISItem>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return entity.snapshot()
    }

    func fetchNDISItem(byItemNumber itemNumber: String) throws -> NDISItemSnapshot? {
        let predicate = #Predicate<NDISItem> { $0.itemNumber == itemNumber }
        let descriptor = FetchDescriptor<NDISItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.effectiveStartDate, order: .reverse)]
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return entity.snapshot()
    }

    func fetchFirstBusinessSnapshot() throws -> BusinessSnapshot? {
        let descriptor = FetchDescriptor<Business>()
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return entity.snapshot()
    }

    func fetchSession(byId id: UUID) throws -> SessionSnapshot? {
        let predicate = #Predicate<Session> { $0.id == id }
        let descriptor = FetchDescriptor<Session>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return entity.snapshot()
    }

    func fetchSessions(byClientId clientId: UUID) throws -> [SessionSnapshot] {
        let predicate = #Predicate<Session> { $0.client?.id == clientId }
        let descriptor = FetchDescriptor<Session>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.snapshot() }
    }

    func fetchClientServices(for clientId: UUID) throws -> [ClientServiceSnapshot] {
        let predicate = #Predicate<ClientService> { $0.client?.id == clientId }
        let descriptor = FetchDescriptor<ClientService>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.serviceName, order: .forward)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.snapshot() }
    }
}

