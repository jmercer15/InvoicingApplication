import Foundation
import SwiftData
import Core
import PersistenceModels

extension AllDataFactories {

    // MARK: - Travel Charge

    static func createTravelCharge(from dict: [String: Any], entityMapping: [String: Any]) throws -> TravelCharge {
        let tc = TravelCharge(id: UUID())
        tc.title             = dict["title"]             as? String ?? ""
        tc.notes             = dict["notes"]             as? String
        tc.location          = dict["location"]          as? String
        tc.mmmZoneName       = dict["mmmZoneName"]       as? String
        tc.distanceKM        = dict["travelDistance"]    as? Double
        tc.durationMinutes   = dict["travelDuration"]    as? Double
        tc.vehicleType       = VehicleType(rawValue: dict["vehicleType"] as? String ?? "car")
        tc.parkingCost       = MoneyDecimalImport.decimal(from: dict["parkingCost"] as? Double)
        tc.tollCost          = MoneyDecimalImport.decimal(from: dict["tollCost"] as? Double)
        tc.participantCount  = dict["participantCount"]  as? Int16
        tc.splitCosts        = dict["splitCosts"]        as? Bool
        tc.chargeType        = TravelChargeType(rawValue: dict["chargeType"] as? String ?? "standard")
        tc.travelDirection   = TravelChargeDirection(rawValue: dict["travelDirection"] as? String ?? "toClient")

        if let s = dict["startTime"]        as? String { tc.startTime        = ISO8601DateFormatter().date(from: s) }
        if let s = dict["endTime"]          as? String { tc.endTime          = ISO8601DateFormatter().date(from: s) }
        if let s = dict["occurrenceDate"]   as? String { tc.occurrenceDate   = ISO8601DateFormatter().date(from: s) }
        if let s = dict["lastModifiedDate"] as? String { tc.lastModifiedDate = ISO8601DateFormatter().date(from: s) }
        if let s = dict["ekCreationDate"]   as? String { tc.ekCreationDate   = ISO8601DateFormatter().date(from: s) }

        if let id = dict["client"] as? String, let c = entityMapping[id] as? Client { tc.client = c }
        else if let id = dict["clientId"] as? String, let c = entityMapping[id] as? Client { tc.client = c }

        if let id = dict["service"] as? String, let cs = entityMapping[id] as? ClientService { tc.service = cs }
        else if let id = dict["serviceId"] as? String, let cs = entityMapping[id] as? ClientService { tc.service = cs }

        if let id = dict["linkedSession"] as? String, let sess = entityMapping[id] as? Session { tc.linkedSession = sess }
        else if let id = dict["linkedSessionId"] as? String, let sess = entityMapping[id] as? Session { tc.linkedSession = sess }

        return tc
    }

    static func createTravelChargeReviewItem(from dict: [String: Any], entityMapping: [String: Any]) throws -> TravelChargeReviewItem {
        let item = TravelChargeReviewItem(id: UUID())
        item.reason = dict["reason"] as? String
        if let s = dict["timestamp"] as? String { item.timestamp = ISO8601DateFormatter().date(from: s) }

        if let id = dict["session"] as? String, let sess = entityMapping[id] as? Session { item.session = sess }
        else if let id = dict["sessionId"] as? String, let sess = entityMapping[id] as? Session { item.session = sess }

        return item
    }

    static func createTravelChargeAuditLog(from dict: [String: Any], entityMapping: [String: Any]) throws -> TravelChargeAuditLog {
        let log = TravelChargeAuditLog(id: UUID())
        log.summary = dict["summary"] as? String
        if let s = dict["timestamp"] as? String { log.timestamp = ISO8601DateFormatter().date(from: s) }

        if let id = dict["charge"] as? String, let charge = entityMapping[id] as? TravelCharge { log.charge = charge }
        else if let id = dict["travelChargeId"] as? String, let charge = entityMapping[id] as? TravelCharge { log.charge = charge }

        return log
    }
}
