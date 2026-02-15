import Foundation
import SwiftData
import Core

/// Factory methods for creating entities from dictionary data
struct AllDataFactories {
    
    static func createAddress(from dict: [String: Any]) throws -> AddressEntity {
        let address = AddressEntity()
        // Generate new UUID
        address.streetNumber = dict["streetNumber"] as? String ?? ""
        address.streetName = dict["streetName"] as? String ?? ""
        address.suburb = dict["suburb"] as? String ?? ""
        address.state = dict["state"] as? String ?? ""
        address.postcode = dict["postcode"] as? String ?? ""
        address.latitude = dict["latitude"] as? Double ?? 0.0
        address.longitude = dict["longitude"] as? Double ?? 0.0
        return address
    }
    
    static func createPayee(from dict: [String: Any], entityMapping: [String: Any]) throws -> PayeeEntity {
        let fullName = dict["fullName"] as? String ?? ""
        let email = dict["email"] as? String
        let relationToClient = dict["relationToClient"] as? String
        let status = dict["status"] as? String
        let phone = dict["phone"] as? String
        
        let payee = PayeeEntity(id: UUID(), fullName: fullName)
        payee.email = email
        payee.relationToClient = relationToClient
        payee.status = status
        payee.phone = phone
        
        if let addressUUID = dict["address"] as? String,
           let address = entityMapping[addressUUID] as? AddressEntity {
            payee.address = address
        } else if let addressId = dict["addressId"] as? String,
                  let address = entityMapping[addressId] as? AddressEntity {
            payee.address = address
        }
        
        if let clientUUIDs = dict["guardedClients"] as? [String] {
            var guardedClients: [ClientEntity] = []
            for uuid in clientUUIDs {
                if let client = entityMapping[uuid] as? ClientEntity {
                    guardedClients.append(client)
                }
            }
            payee.guardedClients = guardedClients
        }
        
        if let invoiceUUIDs = dict["invoices"] as? [String] {
            var invoices: [InvoiceEntity] = []
            for uuid in invoiceUUIDs {
                if let invoice = entityMapping[uuid] as? InvoiceEntity {
                    invoices.append(invoice)
                }
            }
            payee.invoices = invoices
        }
        
        return payee
    }
    
    static func createPlanManager(from dict: [String: Any], entityMapping: [String: Any]) throws -> PlanManagerEntity {
        let abn = dict["abn"] as? String ?? ""
        let businessName = dict["businessName"] as? String
        let email = dict["email"] as? String
        let phone = dict["phone"] as? String
        
        let planManager = PlanManagerEntity(id: UUID(), abn: abn)
        planManager.name = businessName
        planManager.email = email
        planManager.phone = phone
        
        if let addressUUID = dict["address"] as? String,
           let address = entityMapping[addressUUID] as? AddressEntity {
            planManager.address = address
        } else if let addressId = dict["addressId"] as? String,
                  let address = entityMapping[addressId] as? AddressEntity {
            planManager.address = address
        }
        
        if let clientUUIDs = dict["managedClients"] as? [String] {
            var managedClients: [ClientEntity] = []
            for uuid in clientUUIDs {
                if let client = entityMapping[uuid] as? ClientEntity {
                    managedClients.append(client)
                }
            }
            planManager.managedClients = managedClients
        }
        
        return planManager
    }

    static func createNDISItemEntity(from dict: [String: Any]) throws -> NDISItemEntity {
        let itemNumber = dict["itemNumber"] as? String ?? ""
        let name = dict["name"] as? String ?? ""
        let versionIdentifier = dict["versionIdentifier"] as? String ?? ""
        
        let ndisItem = NDISItemEntity(id: UUID(), itemNumber: itemNumber, name: name, versionIdentifier: versionIdentifier)
        
        // Set optional properties
        ndisItem.isCurrent = dict["isCurrent"] as? Bool ?? true
        ndisItem.category = dict["category"] as? String
        ndisItem.categoryNamePACE = dict["categoryNamePACE"] as? String
        ndisItem.categoryNumber = dict["categoryNumber"] as? String
        ndisItem.categoryNumberPACE = dict["categoryNumberPACE"] as? String
        ndisItem.features = dict["features"] as? String
        ndisItem.itemDescription = dict["itemDescription"] as? String
        ndisItem.ndiaRequestedReports = dict["ndiaRequestedReports"] as? Bool
        ndisItem.nonFaceToFaceProvision = dict["nonFaceToFaceProvision"] as? Bool
        ndisItem.providerTravel = dict["providerTravel"] as? Bool
        ndisItem.quoteRequired = dict["quoteRequired"] as? Bool
        ndisItem.registrationGroup = dict["registrationGroup"] as? String
        ndisItem.registrationGroupNumber = dict["registrationGroupNumber"] as? String
        ndisItem.shortNoticeCancellations = dict["shortNoticeCancellations"] as? Bool
        ndisItem.irregularSILSupports = dict["irregularSILSupports"] as? Bool
        ndisItem.status = dict["status"] as? String
        ndisItem.type = dict["type"] as? String
        ndisItem.unit = dict["unit"] as? String
        
        // Handle dates
        if let effectiveStartDateString = dict["effectiveStartDate"] as? String {
            ndisItem.effectiveStartDate = ISO8601DateFormatter().date(from: effectiveStartDateString)
        }
        if let effectiveEndDateString = dict["effectiveEndDate"] as? String {
            ndisItem.effectiveEndDate = ISO8601DateFormatter().date(from: effectiveEndDateString)
        }
        
        return ndisItem
    }
    
    static func createBusinessEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> BusinessEntity {
        let abn = dict["abn"] as? String ?? ""
        let name = dict["name"] as? String ?? ""
        let email = dict["email"] as? String ?? ""
        let phone = dict["phone"] as? String ?? ""
        let accountingMethod = dict["accountingMethod"] as? String ?? "Accrual"
        let bankAccountName = dict["bankAccountName"] as? String
        let bankAccountNumber = dict["bankAccountNumber"] as? String
        let bankBSB = dict["bankBSB"] as? String
        let bankName = dict["bankName"] as? String
        let ndiaOrganisationID = dict["ndiaOrganisationID"] as? String
        let isRegisteredProvider = dict["isRegisteredProvider"] as? Bool ?? false
        let defaultGstCode = dict["defaultGstCode"] as? String ?? GSTCode.p2.rawValue
        
        let business = BusinessEntity(id: UUID(), abn: abn)
        business.name = name
        business.email = email
        business.phone = phone
        business.accountingMethod = accountingMethod
        business.bankAccountName = bankAccountName
        business.bankAccountNumber = bankAccountNumber
        business.bankBSB = bankBSB
        business.bankName = bankName
        business.ndiaOrganisationID = ndiaOrganisationID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : ndiaOrganisationID
        business.isRegisteredProvider = isRegisteredProvider
        business.defaultGstCode = defaultGstCode
        
        if let addressRef = dict["address"] as? [String: Any],
           let addressURI = addressRef["_objectURI"] as? String,
           let address = entityMapping[addressURI] as? AddressEntity {
            business.address = address
        } else if let addressId = dict["addressId"] as? String,
                  let address = entityMapping[addressId] as? AddressEntity {
            business.address = address
        }
        
        if let invoiceUUIDs = dict["invoices"] as? [String] {
            var invoices: [InvoiceEntity] = []
            for uuid in invoiceUUIDs {
                if let invoice = entityMapping[uuid] as? InvoiceEntity {
                    invoices.append(invoice)
                }
            }
            business.invoices = invoices
        }
        
        return business
    }

    static func createClient(from dict: [String: Any], entityMapping: [String: Any]) throws -> ClientEntity {
        let fullName = dict["fullName"] as? String ?? ""
        let status = dict["status"] as? String ?? "Active"
        let billingAuthority = dict["billingAuthority"] as? String
        let creditAmount = dict["creditAmount"] as? Double ?? 0.0
        let isMinor = dict["isMinor"] as? Bool ?? false
        let hasNdisPlan = dict["hasNdisPlan"] as? Bool ?? false
        let ndisNumber = dict["ndisNumber"] as? String ?? ""
        let notes = dict["notes"] as? String
        let phone = dict["phone"] as? String
        let email = dict["email"] as? String
        let planManagementType = dict["planManagementType"] as? String
        
        let client = ClientEntity(
            id: UUID(),
            ndisNumber: ndisNumber,
            fullName: fullName,
            status: ClientStatus(rawValue: status) ?? .active
        )
        client.billingAuthority = BillingAuthority(rawValue: billingAuthority ?? "Client")
        client.creditAmount = creditAmount
        client.isMinor = isMinor
        client.hasNdisPlan = hasNdisPlan
        client.notes = notes
        client.phone = phone
        client.email = email
        client.planManagementType = planManagementType
        
        if let addressRef = dict["address"] as? [String: Any],
           let addressURI = addressRef["_objectURI"] as? String,
           let address = entityMapping[addressURI] as? AddressEntity {
            client.address = address
        } else if let addressId = dict["addressId"] as? String,
                  let address = entityMapping[addressId] as? AddressEntity {
            client.address = address
        }
        
        if let payeeUUID = dict["payee"] as? String,
           let payee = entityMapping[payeeUUID] as? PayeeEntity {
            client.payee = payee
        } else if let payeeId = dict["payeeId"] as? String,
                  let payee = entityMapping[payeeId] as? PayeeEntity {
            client.payee = payee
        } else {
            client.payee = nil
        }
        
        if let planManagerUUID = dict["planManager"] as? String,
           let planManager = entityMapping[planManagerUUID] as? PlanManagerEntity {
            client.planManager = planManager
        } else if let planManagerId = dict["planManagerId"] as? String,
                  let planManager = entityMapping[planManagerId] as? PlanManagerEntity {
            client.planManager = planManager
        }
        
        if let clientServiceUUIDs = dict["clientServices"] as? [String] {
            var clientServices: [ClientServiceEntity] = []
            for uuid in clientServiceUUIDs {
                if let clientService = entityMapping[uuid] as? ClientServiceEntity {
                    clientServices.append(clientService)
                }
            }
            client.clientServices = clientServices
        }
        
        if let invoiceUUIDs = dict["invoices"] as? [String] {
            var invoices: [InvoiceEntity] = []
            for uuid in invoiceUUIDs {
                if let invoice = entityMapping[uuid] as? InvoiceEntity {
                    invoices.append(invoice)
                }
            }
            client.invoices = invoices
        }
        
        if let sessionUUIDs = dict["sessions"] as? [String] {
            var sessions: [SessionEntity] = []
            for uuid in sessionUUIDs {
                if let session = entityMapping[uuid] as? SessionEntity {
                    sessions.append(session)
                }
            }
            client.sessions = sessions
        }
        
        if let travelChargeUUIDs = dict["travelCharges"] as? [String] {
            var travelCharges: [TravelChargeEntity] = []
            for uuid in travelChargeUUIDs {
                if let travelCharge = entityMapping[uuid] as? TravelChargeEntity {
                    travelCharges.append(travelCharge)
                }
            }
            client.travelCharges = travelCharges
        }
        
        if let creditHistoryUUIDs = dict["creditHistory"] as? [String] {
            var creditHistory: [CreditHistoryEntryEntity] = []
            for uuid in creditHistoryUUIDs {
                if let creditHistoryEntry = entityMapping[uuid] as? CreditHistoryEntryEntity {
                    creditHistory.append(creditHistoryEntry)
                }
            }
            client.creditHistory = creditHistory
        }
        
        return client
    }
    
    static func createClientServiceEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> ClientServiceEntity {
        let serviceName = dict["serviceName"] as? String ?? ""
        let unit = dict["unit"] as? String ?? ""
        let rate = dict["rate"] as? Double ?? 0.0
        let status = dict["status"] as? String
        let ndisCode = dict["ndisCode"] as? String
        let isActive = dict["isActive"] as? Bool ?? true
        
        let clientService = ClientServiceEntity(id: UUID(), serviceName: serviceName, unit: unit, rate: rate)
        clientService.status = status
        clientService.ndisCode = ndisCode
        clientService.isActive = isActive
        
        if let startDateString = dict["startDate"] as? String {
            clientService.startDate = ISO8601DateFormatter().date(from: startDateString)
        }
        if let endDateString = dict["endDate"] as? String {
            clientService.endDate = ISO8601DateFormatter().date(from: endDateString)
        }
        
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            clientService.client = client
        } else if let clientId = dict["clientId"] as? String,
                  let client = entityMapping[clientId] as? ClientEntity {
            clientService.client = client
        }
        
        if let ndisItemId = dict["ndisItem"] as? String,
           let ndisItem = entityMapping[ndisItemId] as? NDISItemEntity {
            clientService.ndisItem = ndisItem
        } else if let ndisItemId = dict["ndisItemId"] as? String,
                  let ndisItem = entityMapping[ndisItemId] as? NDISItemEntity {
            clientService.ndisItem = ndisItem
        }
        
        return clientService
    }
    
    static func createInvoiceEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> InvoiceEntity {
        let invoiceNumber = dict["invoiceNumber"] as? String ?? ""
        let totalAmount = dict["totalAmount"] as? Double ?? 0.0
        let taxRate = dict["taxRate"] as? Double ?? 0.0
        let creditApplied = dict["creditApplied"] as? Double ?? 0.0
        let discount = dict["discount"] as? Double ?? 0.0
        let notes = dict["notes"] as? String
        let paymentTerms = dict["paymentTerms"] as? String
        let status = dict["status"] as? String
        
        let invoice = InvoiceEntity(id: UUID(), invoiceNumber: invoiceNumber)
        invoice.totalAmount = totalAmount
        invoice.taxRate = taxRate
        invoice.creditApplied = creditApplied
        invoice.discount = discount
        invoice.notes = notes
        invoice.paymentTerms = paymentTerms
        if let token = canonicalInvoiceStatusToken(status) {
            guard let parsedStatus = InvoiceStatus(rawValue: token) else {
                throw NSError(
                    domain: "ImportError",
                    code: 1003,
                    userInfo: [NSLocalizedDescriptionKey: "Unsupported invoice status '\(status ?? "")'."]
                )
            }
            invoice.status = parsedStatus
        } else {
            invoice.status = .reviewDraft
        }
        
        if let dateString = dict["date"] as? String {
            invoice.date = ISO8601DateFormatter().date(from: dateString) ?? Date()
        }
        if let dueDateString = dict["dueDate"] as? String {
            invoice.dueDate = ISO8601DateFormatter().date(from: dueDateString)
        }
        if let issueDateString = dict["issueDate"] as? String {
            invoice.issueDate = ISO8601DateFormatter().date(from: issueDateString) ?? Date()
        }
        if let paidDateString = dict["paidDate"] as? String {
            invoice.paidDate = ISO8601DateFormatter().date(from: paidDateString)
        }
        
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            invoice.client = client
        } else if let clientId = dict["clientId"] as? String,
                  let client = entityMapping[clientId] as? ClientEntity {
            invoice.client = client
        
            if client.billingAuthority == .parentGuardian, let clientPayee = client.payee {
                invoice.payee = clientPayee
            } else {
                if let payeeId = dict["payee"] as? String,
                   let payee = entityMapping[payeeId] as? PayeeEntity {
                    invoice.payee = payee
                } else {
                    invoice.payee = nil
                }
            }
        } else {
            if let payeeId = dict["payee"] as? String,
               let payee = entityMapping[payeeId] as? PayeeEntity {
                invoice.payee = payee
            } else {
                invoice.payee = nil
            }
            invoice.client = nil
        }
        
        if let businessId = dict["businessId"] as? String,
           let business = entityMapping[businessId] as? BusinessEntity {
            invoice.business = business
        }
        
        invoice.snapshotRelatedData()
        
        if let invoiceItemUUIDs = dict["invoiceItems"] as? [String] {
            var invoiceItems: [InvoiceItemEntity] = []
            for uuid in invoiceItemUUIDs {
                if let invoiceItem = entityMapping[uuid] as? InvoiceItemEntity {
                    invoiceItems.append(invoiceItem)
                }
            }
            invoice.items = invoiceItems
        }
        
        return invoice
    }
    
    static func createInvoiceItemEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> InvoiceItemEntity {
        let itemDescription = dict["itemDescription"] as? String ?? (dict["description"] as? String ?? "")
        let position = dict["position"] as? Int32 ?? 0
        let quantity = dict["quantity"] as? Double ?? 0.0
        let rate = dict["rate"] as? Double ?? (dict["unitPrice"] as? Double ?? 0.0)
        let unit = dict["unit"] as? String
        let taxRate = dict["taxRate"] as? Double ?? 0.0
        let gstCode = dict["gstCode"] as? String
        
        let invoiceItem = InvoiceItemEntity(id: UUID(), itemDescription: itemDescription)
        invoiceItem.position = position
        invoiceItem.quantity = quantity
        invoiceItem.rate = rate
        invoiceItem.unit = unit
        invoiceItem.taxRate = taxRate
        invoiceItem.gstCode = gstCode
        
        if let dateString = dict["date"] as? String {
            invoiceItem.serviceDate = ISO8601DateFormatter().date(from: dateString) ?? Date()
        }
        
        if let invoiceId = dict["invoice"] as? String,
           let invoice = entityMapping[invoiceId] as? InvoiceEntity {
            invoiceItem.invoice = invoice
        } else if let invoiceId = dict["invoiceId"] as? String,
                  let invoice = entityMapping[invoiceId] as? InvoiceEntity {
            invoiceItem.invoice = invoice
        }
        
        if let sessionId = dict["session"] as? String,
           let session = entityMapping[sessionId] as? SessionEntity {
            invoiceItem.session = session
        } else if let sessionId = dict["sessionId"] as? String,
                  let session = entityMapping[sessionId] as? SessionEntity {
            invoiceItem.session = session
        }
        
        if let clientServiceId = dict["clientService"] as? String,
           let clientService = entityMapping[clientServiceId] as? ClientServiceEntity {
            invoiceItem.clientService = clientService
        } else if let clientServiceId = dict["clientServiceId"] as? String,
                  let clientService = entityMapping[clientServiceId] as? ClientServiceEntity {
            invoiceItem.clientService = clientService
        }
        
        return invoiceItem
    }
    
    static func createSessionEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> SessionEntity {
        let title = dict["title"] as? String ?? ""
        let notes = dict["notes"] as? String
        let status = dict["status"] as? String
        let location = dict["location"] as? String
        let attendeesCount = dict["attendeesCount"] as? Int32 ?? 0
        let isTravel = dict["isTravel"] as? Bool ?? false
        let sessionLatitude = dict["sessionLatitude"] as? Double ?? 0.0
        let sessionLongitude = dict["sessionLongitude"] as? Double ?? 0.0
        
        let session = SessionEntity(id: UUID())
        session.title = title
        session.notes = notes
        let sessionToken = canonicalSessionStatusToken(status) ?? SessionStatus.scheduled.rawValue
        session.status = SessionStatus(normalized: sessionToken) ?? .scheduled
        session.location = location
        session.attendeesCount = attendeesCount
        session.isTravel = isTravel
        session.sessionLatitude = sessionLatitude
        session.sessionLongitude = sessionLongitude
        
        if let startTimeString = dict["startTime"] as? String {
            session.startTime = ISO8601DateFormatter().date(from: startTimeString)
        }
        if let endTimeString = dict["endTime"] as? String {
            session.endTime = ISO8601DateFormatter().date(from: endTimeString)
        }
        if let occurrenceDateString = dict["occurrenceDate"] as? String {
            session.occurrenceDate = ISO8601DateFormatter().date(from: occurrenceDateString)
        }
        if let lastModifiedDateString = dict["lastModifiedDate"] as? String {
            session.lastModifiedDate = ISO8601DateFormatter().date(from: lastModifiedDateString)
        }
        if let ekCreationDateString = dict["ekCreationDate"] as? String {
            session.ekCreationDate = ISO8601DateFormatter().date(from: ekCreationDateString)
        }
        
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            session.client = client
        } else if let clientId = dict["clientId"] as? String,
                  let client = entityMapping[clientId] as? ClientEntity {
            session.client = client
        }
        
        if let clientServiceId = dict["clientService"] as? String,
           let clientService = entityMapping[clientServiceId] as? ClientServiceEntity {
            session.clientService = clientService
        } else if let clientServiceId = dict["clientServiceId"] as? String,
                  let clientService = entityMapping[clientServiceId] as? ClientServiceEntity {
            session.clientService = clientService
        }
        
        if let invoiceId = dict["invoiceId"] as? String,
           let invoice = entityMapping[invoiceId] as? InvoiceEntity {
            session.invoice = invoice
        }
        
        if let addressUUID = dict["address"] as? String,
           let address = entityMapping[addressUUID] as? AddressEntity {
            session.address = address
        } else if let addressId = dict["addressId"] as? String,
                  let address = entityMapping[addressId] as? AddressEntity {
            session.address = address
        }
        
        if let invoiceItemUUIDs = dict["invoiceItems"] as? [String] {
            var invoiceItems: [InvoiceItemEntity] = []
            for uuid in invoiceItemUUIDs {
                if let invoiceItem = entityMapping[uuid] as? InvoiceItemEntity {
                    invoiceItems.append(invoiceItem)
                }
            }
            session.invoiceItems = invoiceItems
        }
        
        return session
    }

    static func createServiceAgreementEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> ServiceAgreementEntity {
        let agreement = ServiceAgreementEntity(id: UUID())
        agreement.cancellationPolicyType = dict["cancellationPolicyType"] as? String ?? CancellationPolicyType.twoClearBusinessDays.rawValue
        agreement.allowsProviderTravel = dict["allowsProviderTravel"] as? Bool ?? false
        agreement.allowsTelehealth = dict["allowsTelehealth"] as? Bool ?? false
        agreement.allowsNonFaceToFace = dict["allowsNonFaceToFace"] as? Bool ?? false
        agreement.participantSignatoryName = dict["participantSignatoryName"] as? String
        agreement.participantSignatoryRole = dict["participantSignatoryRole"] as? String
        agreement.signatureMethod = dict["signatureMethod"] as? String
        agreement.notes = dict["notes"] as? String
        agreement.isArchived = dict["isArchived"] as? Bool ?? false

        if let effectiveFromString = dict["effectiveFrom"] as? String {
            agreement.effectiveFrom = ISO8601DateFormatter().date(from: effectiveFromString) ?? Date()
        }
        if let effectiveToString = dict["effectiveTo"] as? String {
            agreement.effectiveTo = ISO8601DateFormatter().date(from: effectiveToString)
        }
        if let acceptedString = dict["pricingDisclosureAcceptedAt"] as? String {
            agreement.pricingDisclosureAcceptedAt = ISO8601DateFormatter().date(from: acceptedString)
        }
        if let signedAtString = dict["signedAt"] as? String {
            agreement.signedAt = ISO8601DateFormatter().date(from: signedAtString)
        }

        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            agreement.client = client
        } else if let clientId = dict["clientId"] as? String,
                  let client = entityMapping[clientId] as? ClientEntity {
            agreement.client = client
        }

        return agreement
    }

    static func createSupportLogEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> SupportLogEntity {
        let log = SupportLogEntity(id: UUID())
        log.participantName = dict["participantName"] as? String ?? ""
        log.participantNdisNumber = dict["participantNdisNumber"] as? String ?? ""
        log.supportItemNumber = dict["supportItemNumber"] as? String ?? ""
        log.serviceDescription = dict["serviceDescription"] as? String ?? ""
        log.location = dict["location"] as? String ?? ""
        log.quantityHours = dict["quantityHours"] as? Double ?? 0.0
        log.deliveredBy = dict["deliveredBy"] as? String ?? ""
        log.attestedBy = dict["attestedBy"] as? String ?? ""
        log.signatureMethod = dict["signatureMethod"] as? String
        log.signedBy = dict["signedBy"] as? String
        log.cancellationReasonCode = dict["cancellationReasonCode"] as? String
        log.notes = dict["notes"] as? String

        if let deliveredFromString = dict["deliveredFrom"] as? String {
            log.deliveredFrom = ISO8601DateFormatter().date(from: deliveredFromString) ?? Date()
        }
        if let deliveredToString = dict["deliveredTo"] as? String {
            log.deliveredTo = ISO8601DateFormatter().date(from: deliveredToString) ?? log.deliveredFrom
        }
        if let attestedAtString = dict["attestedAt"] as? String {
            log.attestedAt = ISO8601DateFormatter().date(from: attestedAtString) ?? Date()
        }
        if let signedAtString = dict["signedAt"] as? String {
            log.signedAt = ISO8601DateFormatter().date(from: signedAtString)
        }

        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            log.client = client
        } else if let clientId = dict["clientId"] as? String,
                  let client = entityMapping[clientId] as? ClientEntity {
            log.client = client
        }

        if let sessionId = dict["session"] as? String,
           let session = entityMapping[sessionId] as? SessionEntity {
            log.session = session
        } else if let sessionId = dict["sessionId"] as? String,
                  let session = entityMapping[sessionId] as? SessionEntity {
            log.session = session
        }

        return log
    }

    static func createBulkClaimBatchEntity(from dict: [String: Any]) throws -> BulkClaimBatchEntity {
        let batch = BulkClaimBatchEntity(id: UUID())
        batch.status = dict["status"] as? String ?? BulkClaimBatchStatus.draft.rawValue
        batch.includeTravel = dict["includeTravel"] as? Bool ?? true
        batch.includeCancellations = dict["includeCancellations"] as? Bool ?? true
        batch.claimReferenceStrategy = dict["claimReferenceStrategy"] as? String ?? "invoice_number"
        batch.exportFileName = dict["exportFileName"] as? String
        batch.rowCount = Int32(dict["rowCount"] as? Int ?? 0)
        batch.errorCount = Int32(dict["errorCount"] as? Int ?? 0)
        batch.checksumSHA256 = dict["checksumSHA256"] as? String
        batch.notes = dict["notes"] as? String

        if let createdAtString = dict["createdAt"] as? String {
            batch.createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        }
        if let fromDateString = dict["fromDate"] as? String {
            batch.fromDate = ISO8601DateFormatter().date(from: fromDateString) ?? Date()
        }
        if let toDateString = dict["toDate"] as? String {
            batch.toDate = ISO8601DateFormatter().date(from: toDateString) ?? Date()
        }
        if let exportedAtString = dict["exportedAt"] as? String {
            batch.exportedAt = ISO8601DateFormatter().date(from: exportedAtString)
        }

        return batch
    }

    static func createBulkClaimLineEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> BulkClaimLineEntity {
        let line = BulkClaimLineEntity(id: UUID())
        line.registrationNumber = dict["registrationNumber"] as? String ?? ""
        line.ndisNumber = dict["ndisNumber"] as? String ?? ""
        line.supportNumber = dict["supportNumber"] as? String ?? ""
        line.claimReference = dict["claimReference"] as? String
        line.quantity = dict["quantity"] as? Double
        line.hours = dict["hours"] as? String
        line.unitPrice = dict["unitPrice"] as? Double ?? 0.0
        line.gstCode = dict["gstCode"] as? String ?? GSTCode.p2.rawValue
        line.authorisedBy = dict["authorisedBy"] as? String
        line.participantApproved = dict["participantApproved"] as? String
        line.inKindFundingProgram = dict["inKindFundingProgram"] as? String
        line.claimTypeCode = dict["claimTypeCode"] as? String
        line.cancellationReason = dict["cancellationReason"] as? String
        line.abnOfSupportProvider = dict["abnOfSupportProvider"] as? String
        line.isValid = dict["isValid"] as? Bool ?? true
        line.validationErrorSummary = dict["validationErrorSummary"] as? String
        line.submissionStatus = dict["submissionStatus"] as? String
        line.submissionRef = dict["submissionRef"] as? String
        line.reconciliationNotes = dict["reconciliationNotes"] as? String

        if let deliveredFromString = dict["supportsDeliveredFrom"] as? String {
            line.supportsDeliveredFrom = ISO8601DateFormatter().date(from: deliveredFromString) ?? Date()
        }
        if let deliveredToString = dict["supportsDeliveredTo"] as? String {
            line.supportsDeliveredTo = ISO8601DateFormatter().date(from: deliveredToString) ?? line.supportsDeliveredFrom
        }
        if let reconciledAtString = dict["reconciledAt"] as? String {
            line.reconciledAt = ISO8601DateFormatter().date(from: reconciledAtString)
        }

        if let batchId = dict["batchId"] as? String,
           let batch = entityMapping[batchId] as? BulkClaimBatchEntity {
            line.batch = batch
        }

        if let invoiceId = dict["invoiceId"] as? String,
           let invoice = entityMapping[invoiceId] as? InvoiceEntity {
            line.invoice = invoice
        }

        if let invoiceItemId = dict["invoiceItemId"] as? String,
           let invoiceItem = entityMapping[invoiceItemId] as? InvoiceItemEntity {
            line.invoiceItem = invoiceItem
        }

        return line
    }

    private static func canonicalInvoiceStatusToken(_ rawStatus: String?) -> String? {
        guard let rawStatus else { return nil }
        let normalized = rawStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "draft", "reviewdraft", "review_draft", "review_drafts":
            return InvoiceStatus.reviewDraft.rawValue
        case "readytosend", "ready_to_send":
            return InvoiceStatus.readyToSend.rawValue
        case "sent":
            return InvoiceStatus.pending.rawValue
        case "paid", "completed", "payment_received":
            return InvoiceStatus.received.rawValue
        case "pending":
            return InvoiceStatus.pending.rawValue
        case "received":
            return InvoiceStatus.received.rawValue
        case "overdue":
            return InvoiceStatus.overdue.rawValue
        case "cancelled", "canceled":
            return InvoiceStatus.cancelled.rawValue
        case "void", "voided":
            return InvoiceStatus.voided.rawValue
        default:
            return normalized
        }
    }

    private static func canonicalSessionStatusToken(_ rawStatus: String?) -> String? {
        guard let rawStatus else { return nil }
        let normalized = rawStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "needs_services", "needsservice", "needstravel", "needs_travel", "add_travel":
            return SessionStatus.needsTravel.rawValue
        case "reviewdraft", "review_draft", "review_drafts":
            return SessionStatus.reviewDraft.rawValue
        case "readytosend", "ready_to_send":
            return SessionStatus.readyToSend.rawValue
        case "noshow", "no_show":
            return SessionStatus.noShow.rawValue
        case "rescheduled":
            return SessionStatus.rescheduled.rawValue
        case "scheduled":
            return SessionStatus.scheduled.rawValue
        case "completed":
            return SessionStatus.completed.rawValue
        case "grouped":
            return SessionStatus.grouped.rawValue
        case "pending":
            return SessionStatus.pending.rawValue
        case "received", "paid":
            return SessionStatus.received.rawValue
        case "cancelled", "canceled":
            return SessionStatus.cancelled.rawValue
        default:
            return normalized
        }
    }
    
    static func createTravelChargeEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> TravelChargeEntity {
        let title = dict["title"] as? String ?? ""
        let notes = dict["notes"] as? String
        let location = dict["location"] as? String
        let mmmZoneName = dict["mmmZoneName"] as? String
        let travelDistance = dict["travelDistance"] as? Double
        let travelDuration = dict["travelDuration"] as? Double
        let vehicleType = dict["vehicleType"] as? String
        let parkingCost = dict["parkingCost"] as? Double
        let tollCost = dict["tollCost"] as? Double
        let participantCount = dict["participantCount"] as? Int16
        let splitCosts = dict["splitCosts"] as? Bool
        let chargeType = dict["chargeType"] as? String
        let travelDirection = dict["travelDirection"] as? String
        
        let travelCharge = TravelChargeEntity(id: UUID())
        travelCharge.title = title
        travelCharge.notes = notes
        travelCharge.location = location
        travelCharge.mmmZoneName = mmmZoneName
        travelCharge.travelDistance = travelDistance
        travelCharge.travelDuration = travelDuration
        travelCharge.vehicleType = VehicleType(rawValue: vehicleType ?? "car")
        travelCharge.parkingCost = parkingCost
        travelCharge.tollCost = tollCost
        travelCharge.participantCount = participantCount
        travelCharge.splitCosts = splitCosts
        travelCharge.chargeType = TravelChargeType(rawValue: chargeType ?? "standard")
        travelCharge.travelDirection = TravelChargeDirection(rawValue: travelDirection ?? "toClient")
        
        if let startTimeString = dict["startTime"] as? String {
            travelCharge.startTime = ISO8601DateFormatter().date(from: startTimeString)
        }
        if let endTimeString = dict["endTime"] as? String {
            travelCharge.endTime = ISO8601DateFormatter().date(from: endTimeString)
        }
        if let occurrenceDateString = dict["occurrenceDate"] as? String {
            travelCharge.occurrenceDate = ISO8601DateFormatter().date(from: occurrenceDateString)
        }
        if let lastModifiedDateString = dict["lastModifiedDate"] as? String {
            travelCharge.lastModifiedDate = ISO8601DateFormatter().date(from: lastModifiedDateString)
        }
        if let ekCreationDateString = dict["ekCreationDate"] as? String {
            travelCharge.ekCreationDate = ISO8601DateFormatter().date(from: ekCreationDateString)
        }
        
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            travelCharge.client = client
        } else if let clientId = dict["clientId"] as? String,
                  let client = entityMapping[clientId] as? ClientEntity {
            travelCharge.client = client
        }
        
        if let serviceId = dict["service"] as? String,
           let service = entityMapping[serviceId] as? ClientServiceEntity {
            travelCharge.service = service
        } else if let serviceId = dict["serviceId"] as? String,
                  let service = entityMapping[serviceId] as? ClientServiceEntity {
            travelCharge.service = service
        }
        
        if let linkedSessionId = dict["linkedSession"] as? String,
           let linkedSession = entityMapping[linkedSessionId] as? SessionEntity {
            travelCharge.linkedSession = linkedSession
        } else if let linkedSessionId = dict["linkedSessionId"] as? String,
                  let linkedSession = entityMapping[linkedSessionId] as? SessionEntity {
            travelCharge.linkedSession = linkedSession
        }
        
        return travelCharge
    }
    
    static func createTravelChargeReviewItem(from dict: [String: Any], entityMapping: [String: Any]) throws -> TravelChargeReviewItemEntity {
        let reason = dict["reason"] as? String
        
        let reviewItem = TravelChargeReviewItemEntity(id: UUID())
        reviewItem.reason = reason
        
        if let timestampString = dict["timestamp"] as? String {
            reviewItem.timestamp = ISO8601DateFormatter().date(from: timestampString)
        }
        
        if let sessionId = dict["session"] as? String,
           let session = entityMapping[sessionId] as? SessionEntity {
            reviewItem.session = session
        } else if let sessionId = dict["sessionId"] as? String,
                  let session = entityMapping[sessionId] as? SessionEntity {
            reviewItem.session = session
        }
        
        return reviewItem
    }
    
    static func createTravelChargeAuditLog(from dict: [String: Any], entityMapping: [String: Any]) throws -> TravelChargeAuditLog {
        let summary = dict["summary"] as? String
        
        let auditLog = TravelChargeAuditLog(id: UUID())
        auditLog.summary = summary
        
        if let timestampString = dict["timestamp"] as? String {
            auditLog.timestamp = ISO8601DateFormatter().date(from: timestampString)
        }
        
        if let chargeId = dict["charge"] as? String,
           let charge = entityMapping[chargeId] as? TravelChargeEntity {
            auditLog.charge = charge
        } else if let chargeId = dict["travelChargeId"] as? String,
                  let charge = entityMapping[chargeId] as? TravelChargeEntity {
            auditLog.charge = charge
        }
        
        return auditLog
    }
    
    static func createRegionalPriceEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> RegionalPriceEntity {
        let amount = dict["amount"] as? Double ?? 0.0
        let regionIdentifier = dict["regionIdentifier"] as? String ?? ""
        
        let regionalPrice = RegionalPriceEntity(id: UUID())
        regionalPrice.amount = amount
        regionalPrice.regionIdentifier = regionIdentifier
        
        if let ndisItemID = dict["ndisItem"] as? String,
           let ndisItem = entityMapping[ndisItemID] as? NDISItemEntity {
            regionalPrice.ndisItem = ndisItem
        } else if let ndisItemID = dict["ndisItemId"] as? String,
                  let ndisItem = entityMapping[ndisItemID] as? NDISItemEntity {
            regionalPrice.ndisItem = ndisItem
        }
        
        return regionalPrice
    }
    
    static func createCreditHistoryEntryEntity(from dict: [String: Any], entityMapping: [String: Any]) throws -> CreditHistoryEntryEntity {
        let amount = dict["amount"] as? Double ?? 0.0
        let type = dict["type"] as? String ?? "Usage"
        let description = dict["description"] as? String ?? (dict["reason"] as? String)
        
        let creditHistory = CreditHistoryEntryEntity(id: UUID())
        creditHistory.amount = amount
        creditHistory.type = CreditHistoryType(rawValue: type) ?? .credit
        creditHistory.notes = description
        
        if let dateString = dict["date"] as? String {
            creditHistory.date = ISO8601DateFormatter().date(from: dateString) ?? Date()
        }
        
        if let clientId = dict["client"] as? String,
           let client = entityMapping[clientId] as? ClientEntity {
            creditHistory.client = client
        } else if let clientId = dict["clientId"] as? String,
                  let client = entityMapping[clientId] as? ClientEntity {
            creditHistory.client = client
        }
        
        return creditHistory
    }
}
