import Foundation
import SwiftData
import Core
import PersistenceModels

/// Factory methods for creating entities from dictionary data.
extension AllDataFactories {

    // MARK: - People & Relationships

    static func createAddress(from dict: [String: Any]) throws -> Address {
        let address = Address()
        address.streetNumber = dict["streetNumber"] as? String ?? ""
        address.streetName   = dict["streetName"]   as? String ?? ""
        address.suburb       = dict["suburb"]       as? String ?? ""
        address.state        = dict["state"]        as? String ?? ""
        address.postcode     = dict["postcode"]     as? String ?? ""
        address.latitude     = dict["latitude"]     as? Double ?? 0.0
        address.longitude    = dict["longitude"]    as? Double ?? 0.0
        return address
    }

    static func createPayee(from dict: [String: Any], entityMapping: [String: Any]) throws -> Payee {
        let payee = Payee(id: UUID(), fullName: dict["fullName"] as? String ?? "")
        payee.email              = dict["email"]             as? String
        payee.relationToClient   = dict["relationToClient"]  as? String
        payee.status             = dict["status"]            as? String
        payee.phone              = dict["phone"]             as? String

        if let uuid = dict["address"] as? String, let addr = entityMapping[uuid] as? Address {
            payee.address = addr
        } else if let id = dict["addressId"] as? String, let addr = entityMapping[id] as? Address {
            payee.address = addr
        }

        if let uuids = dict["guardedClients"] as? [String] {
            payee.guardedClients = uuids.compactMap { entityMapping[$0] as? Client }
        }
        if let uuids = dict["invoices"] as? [String] {
            payee.invoices = uuids.compactMap { entityMapping[$0] as? Invoice }
        }

        return payee
    }

    static func createPlanManager(from dict: [String: Any], entityMapping: [String: Any]) throws -> PlanManager {
        let planManager = PlanManager(id: UUID(), abn: dict["abn"] as? String ?? "")
        planManager.name  = dict["businessName"] as? String
        planManager.email = dict["email"]        as? String
        planManager.phone = dict["phone"]        as? String

        if let uuid = dict["address"] as? String, let addr = entityMapping[uuid] as? Address {
            planManager.address = addr
        } else if let id = dict["addressId"] as? String, let addr = entityMapping[id] as? Address {
            planManager.address = addr
        }

        if let uuids = dict["managedClients"] as? [String] {
            planManager.managedClients = uuids.compactMap { entityMapping[$0] as? Client }
        }

        return planManager
    }

    static func createClient(from dict: [String: Any], entityMapping: [String: Any]) throws -> Client {
        let status = dict["status"] as? String ?? "Active"
        let client = Client(
            id: UUID(),
            ndisNumber:  dict["ndisNumber"]  as? String ?? "",
            fullName:    dict["fullName"]    as? String ?? "",
            status:      ClientStatus(rawValue: status) ?? .active
        )
        client.billingAuthority     = BillingAuthority(rawValue: dict["billingAuthority"] as? String ?? "Client")
        client.creditAmount         = MoneyDecimalImport.decimal(from: dict["creditAmount"] as? Double ?? 0.0)
        client.isMinor              = dict["isMinor"]              as? Bool   ?? false
        client.hasNdisPlan          = dict["hasNdisPlan"]          as? Bool   ?? false
        client.notes                = dict["notes"]                as? String
        client.phone                = dict["phone"]                as? String
        client.email                = dict["email"]                as? String
        client.planManagementType   = dict["planManagementType"]   as? String

        if let ref = dict["address"] as? [String: Any], let uri = ref["_objectURI"] as? String, let addr = entityMapping[uri] as? Address {
            client.address = addr
        } else if let id = dict["addressId"] as? String, let addr = entityMapping[id] as? Address {
            client.address = addr
        }

        if let uuid = dict["payee"] as? String, let payee = entityMapping[uuid] as? Payee {
            client.payee = payee
        } else if let id = dict["payeeId"] as? String, let payee = entityMapping[id] as? Payee {
            client.payee = payee
        } else {
            client.payee = nil
        }

        if let uuid = dict["planManager"] as? String, let pm = entityMapping[uuid] as? PlanManager {
            client.planManager = pm
        } else if let id = dict["planManagerId"] as? String, let pm = entityMapping[id] as? PlanManager {
            client.planManager = pm
        }

        if let uuids = dict["clientServices"] as? [String] {
            client.clientServices = uuids.compactMap { entityMapping[$0] as? ClientService }
        }
        if let uuids = dict["invoices"] as? [String] {
            client.invoices = uuids.compactMap { entityMapping[$0] as? Invoice }
        }
        if let uuids = dict["sessions"] as? [String] {
            client.sessions = uuids.compactMap { entityMapping[$0] as? Session }
        }
        if let uuids = dict["travelCharges"] as? [String] {
            client.travelCharges = uuids.compactMap { entityMapping[$0] as? TravelCharge }
        }
        if let uuids = dict["creditHistory"] as? [String] {
            client.creditHistory = uuids.compactMap { entityMapping[$0] as? CreditHistoryEntry }
        }

        return client
    }

    static func createClientService(from dict: [String: Any], entityMapping: [String: Any]) throws -> ClientService {
        let cs = ClientService(
            id: UUID(),
            serviceName: dict["serviceName"] as? String ?? "",
            unit:        dict["unit"]        as? String ?? "",
            rate:        MoneyDecimalImport.decimal(from: dict["rate"] as? Double ?? 0.0)
        )
        cs.status   = dict["status"]   as? String
        cs.ndisCode = dict["ndisCode"] as? String
        cs.isActive = dict["isActive"] as? Bool ?? true

        if let s = dict["startDate"] as? String { cs.startDate = ISO8601DateFormatter().date(from: s) }
        if let s = dict["endDate"]   as? String { cs.endDate   = ISO8601DateFormatter().date(from: s) }

        if let id = dict["client"] as? String, let c = entityMapping[id] as? Client {
            cs.client = c
        } else if let id = dict["clientId"] as? String, let c = entityMapping[id] as? Client {
            cs.client = c
        }

        if let id = dict["ndisItem"] as? String, let item = entityMapping[id] as? NDISItem {
            cs.ndisItem = item
        } else if let id = dict["ndisItemId"] as? String, let item = entityMapping[id] as? NDISItem {
            cs.ndisItem = item
        }

        return cs
    }

    static func createServiceAgreement(from dict: [String: Any], entityMapping: [String: Any]) throws -> ServiceAgreement {
        let agreement = ServiceAgreement(id: UUID())
        agreement.cancellationPolicyType          = dict["cancellationPolicyType"]     as? String ?? CancellationPolicyType.twoClearBusinessDays.rawValue
        agreement.allowsProviderTravel            = dict["allowsProviderTravel"]        as? Bool   ?? false
        agreement.allowsTelehealth                = dict["allowsTelehealth"]            as? Bool   ?? false
        agreement.allowsNonFaceToFace             = dict["allowsNonFaceToFace"]         as? Bool   ?? false
        agreement.participantSignatoryName        = dict["participantSignatoryName"]    as? String
        agreement.participantSignatoryRole        = dict["participantSignatoryRole"]    as? String
        agreement.signatureMethod                 = dict["signatureMethod"]             as? String
        agreement.notes                           = dict["notes"]                       as? String
        agreement.isArchived                      = dict["isArchived"]                  as? Bool   ?? false

        if let s = dict["effectiveFrom"]               as? String { agreement.effectiveFrom               = ISO8601DateFormatter().date(from: s) ?? Date() }
        if let s = dict["effectiveTo"]                 as? String { agreement.effectiveTo                 = ISO8601DateFormatter().date(from: s) }
        if let s = dict["pricingDisclosureAcceptedAt"] as? String { agreement.pricingDisclosureAcceptedAt = ISO8601DateFormatter().date(from: s) }
        if let s = dict["signedAt"]                    as? String { agreement.signedAt                    = ISO8601DateFormatter().date(from: s) }

        if let id = dict["client"] as? String, let c = entityMapping[id] as? Client {
            agreement.client = c
        } else if let id = dict["clientId"] as? String, let c = entityMapping[id] as? Client {
            agreement.client = c
        }

        return agreement
    }

    static func createSupportLog(from dict: [String: Any], entityMapping: [String: Any]) throws -> SupportLog {
        let log = SupportLog(id: UUID())
        log.participantName       = dict["participantName"]       as? String ?? ""
        log.participantNdisNumber = dict["participantNdisNumber"] as? String ?? ""
        log.supportItemNumber     = dict["supportItemNumber"]     as? String ?? ""
        log.serviceDescription    = dict["serviceDescription"]    as? String ?? ""
        log.location              = dict["location"]              as? String ?? ""
        log.quantityHours         = dict["quantityHours"]         as? Double ?? 0.0
        log.deliveredBy           = dict["deliveredBy"]           as? String ?? ""
        log.attestedBy            = dict["attestedBy"]            as? String ?? ""
        log.signatureMethod       = dict["signatureMethod"]       as? String
        log.signedBy              = dict["signedBy"]              as? String
        log.cancellationReasonCode = dict["cancellationReasonCode"] as? String
        log.notes                 = dict["notes"]                 as? String

        if let s = dict["deliveredFrom"] as? String { log.deliveredFrom = ISO8601DateFormatter().date(from: s) ?? Date() }
        if let s = dict["deliveredTo"]   as? String { log.deliveredTo   = ISO8601DateFormatter().date(from: s) ?? log.deliveredFrom }
        if let s = dict["attestedAt"]    as? String { log.attestedAt    = ISO8601DateFormatter().date(from: s) ?? Date() }
        if let s = dict["signedAt"]      as? String { log.signedAt      = ISO8601DateFormatter().date(from: s) }

        if let id = dict["client"] as? String, let c = entityMapping[id] as? Client { log.client = c }
        else if let id = dict["clientId"] as? String, let c = entityMapping[id] as? Client { log.client = c }

        if let id = dict["session"] as? String, let s = entityMapping[id] as? Session { log.session = s }
        else if let id = dict["sessionId"] as? String, let s = entityMapping[id] as? Session { log.session = s }

        return log
    }

    static func createBusiness(from dict: [String: Any], entityMapping: [String: Any]) throws -> Business {
        let business = Business(id: UUID(), abn: dict["abn"] as? String ?? "")
        business.name                  = dict["name"]                  as? String ?? ""
        business.email                 = dict["email"]                 as? String ?? ""
        business.phone                 = dict["phone"]                 as? String ?? ""
        business.accountingMethod      = dict["accountingMethod"]      as? String ?? "Accrual"
        business.bankAccountName       = dict["bankAccountName"]       as? String
        business.bankAccountNumber     = dict["bankAccountNumber"]     as? String
        business.bankBSB               = dict["bankBSB"]               as? String
        business.bankName              = dict["bankName"]              as? String
        business.isRegisteredProvider  = dict["isRegisteredProvider"]  as? Bool   ?? false
        business.defaultGstCode        = dict["defaultGstCode"]        as? String ?? GSTCode.p2.rawValue
        let orgID                      = dict["ndiaOrganisationID"]    as? String
        business.ndiaOrganisationID    = orgID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : orgID

        if let ref = dict["address"] as? [String: Any], let uri = ref["_objectURI"] as? String, let addr = entityMapping[uri] as? Address {
            business.address = addr
        } else if let id = dict["addressId"] as? String, let addr = entityMapping[id] as? Address {
            business.address = addr
        }

        if let uuids = dict["invoices"] as? [String] {
            business.invoices = uuids.compactMap { entityMapping[$0] as? Invoice }
        }

        return business
    }

    static func createCreditHistoryEntry(from dict: [String: Any], entityMapping: [String: Any]) throws -> CreditHistoryEntry {
        let entry = CreditHistoryEntry(id: UUID())
        entry.amount = MoneyDecimalImport.decimal(from: dict["amount"] as? Double ?? 0.0)
        entry.type   = CreditHistoryType(rawValue: dict["type"] as? String ?? "Usage") ?? .credit
        entry.notes  = dict["description"] as? String ?? dict["reason"] as? String

        if let s = dict["date"] as? String { entry.date = ISO8601DateFormatter().date(from: s) ?? Date() }

        if let id = dict["client"] as? String, let c = entityMapping[id] as? Client { entry.client = c }
        else if let id = dict["clientId"] as? String, let c = entityMapping[id] as? Client { entry.client = c }

        return entry
    }
}
