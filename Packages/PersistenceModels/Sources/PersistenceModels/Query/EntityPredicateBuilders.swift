import Foundation
import SwiftData

/// Shared `#Predicate` builders for UUID-keyed entity lookups (SD-P3-6).
public enum EntityPredicateBuilders {
    public static func billableDraft(id: UUID) -> Predicate<BillableDraft> {
        #Predicate { $0.id == id }
    }

    public static func client(id: UUID) -> Predicate<Client> {
        #Predicate { $0.id == id }
    }

    public static func session(id: UUID) -> Predicate<Session> {
        #Predicate { $0.id == id }
    }

    public static func clientService(id: UUID) -> Predicate<ClientService> {
        #Predicate { $0.id == id }
    }

    public static func invoice(id: UUID) -> Predicate<Invoice> {
        #Predicate { $0.id == id }
    }

    public static func billableDrafts(
        statusRaw: String,
        rangeLower: Date,
        rangeUpper: Date,
        clientId: UUID,
        planType: String
    ) -> Predicate<BillableDraft> {
        #Predicate { draft in
            draft.draftStatus == statusRaw
                && draft.computedAt >= rangeLower
                && draft.computedAt <= rangeUpper
                && draft.clientId == clientId
                && draft.clientPlanManagementType == planType
        }
    }

    public static func billableDrafts(
        statusRaw: String,
        rangeLower: Date,
        rangeUpper: Date,
        clientId: UUID
    ) -> Predicate<BillableDraft> {
        #Predicate { draft in
            draft.draftStatus == statusRaw
                && draft.computedAt >= rangeLower
                && draft.computedAt <= rangeUpper
                && draft.clientId == clientId
        }
    }

    public static func billableDrafts(planType: String) -> Predicate<BillableDraft> {
        #Predicate { $0.clientPlanManagementType == planType }
    }

    public static func sessionsInBillableWindow(
        rangeFrom: Date,
        rangeTo: Date
    ) -> Predicate<Session> {
        #Predicate<Session> { session in
            if let start = session.startTime {
                start >= rangeFrom
                    && start <= rangeTo
                    && session.client != nil
                    && session.clientService != nil
            } else {
                false
            }
        }
    }
}
