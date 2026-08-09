import Foundation
import SwiftData
import Core
import PersistenceModels
import Data
import Observation

@Observable
@MainActor
class TravelChargeViewModel {
    var form: TravelChargeFormState
    var saveError: String?
    let modelContext: ModelContext
    private let persistence: TravelChargePersistence

    var onSave: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(
        modelContext: ModelContext,
        geocodingService: any Core.GeocodingServiceProtocol,
        mainSession: Session,
        daySessions: [DisplayableCalendarItem],
        onSave: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        form = TravelChargeFormState(
            geocodingService: geocodingService,
            mainSession: mainSession,
            daySessions: daySessions
        )
        self.modelContext = modelContext
        persistence = TravelChargePersistence(modelContext: modelContext)
        self.onSave = onSave
        self.onError = onError
    }

    func applyTravelChargeQuerySnapshot(
        clientServices: [ClientService],
        travelCharges: [TravelCharge]
    ) {
        form.applyTravelChargeQuerySnapshot(
            clientServices: clientServices,
            travelCharges: travelCharges
        )
    }
    
    func loadData() {
        let sessionID = form.mainSession.id
        let chargeDescriptor = FetchDescriptor<TravelCharge>(
            predicate: #Predicate<TravelCharge> { charge in charge.linkedSession?.id == sessionID },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let travelCharges = (try? modelContext.fetch(chargeDescriptor)) ?? []
        
        let clientServices: [ClientService]
        if let clientID = form.mainSession.clientId {
            let serviceDescriptor = FetchDescriptor<ClientService>(
                predicate: #Predicate<ClientService> { service in service.client?.id == clientID },
                sortBy: [SortDescriptor(\.serviceName)]
            )
            clientServices = (try? modelContext.fetch(serviceDescriptor)) ?? []
        } else {
            clientServices = []
        }
        
        applyTravelChargeQuerySnapshot(clientServices: clientServices, travelCharges: travelCharges)
    }

    func saveTravelCharges() {
        saveError = nil
        do {
            try persistence.saveTravelCharges(form: form)
            onSave?()
        } catch {
            saveError = error.localizedDescription
            onError?(error)
        }
    }
}
