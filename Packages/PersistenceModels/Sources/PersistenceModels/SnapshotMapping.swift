import Core
import Foundation

extension AddressSnapshot {
    public init(_ address: Address) {
        self.init(
            id: address.id,
            country: address.country,
            postcode: address.postcode,
            state: address.state,
            streetName: address.streetName,
            streetNumber: address.streetNumber,
            city: address.city,
            suburb: address.suburb,
            unitNumber: address.unitNumber,
            poBox: address.poBox,
            fullAddressText: address.fullAddressText,
            latitude: address.latitude,
            longitude: address.longitude
        )
    }
}

extension BillableDraftSnapshot {
    public init(_ draft: BillableDraft) {
        self.init(
            id: draft.id,
            sessionId: draft.sessionId,
            clientId: draft.clientId,
            clientPlanManagementType: draft.clientPlanManagementType,
            serviceId: draft.serviceId,
            computedAt: draft.computedAt,
            billingContextSnapshot: draft.billingContextSnapshot,
            draftStatus: draft.draftStatus,
            createdAt: draft.createdAt,
            updatedAt: draft.updatedAt
        )
    }
}

extension BulkClaimBatchSnapshot {
    public init(_ batch: BulkClaimBatch) {
        self.init(
            id: batch.id,
            createdAt: batch.createdAt,
            fromDate: batch.fromDate,
            toDate: batch.toDate,
            status: batch.status,
            includeTravel: batch.includeTravel,
            includeCancellations: batch.includeCancellations,
            claimReferenceStrategy: batch.claimReferenceStrategy,
            exportFileName: batch.exportFileName,
            exportedAt: batch.exportedAt,
            submittedAt: batch.submittedAt,
            rowCount: batch.rowCount,
            errorCount: batch.errorCount,
            checksumSHA256: batch.checksumSHA256,
            notes: batch.notes
        )
    }
}

extension BulkClaimLineSnapshot {
    public init(_ line: BulkClaimLine) {
        self.init(
            id: line.id,
            registrationNumber: line.registrationNumber,
            ndisNumber: line.ndisNumber,
            supportsDeliveredFrom: line.supportsDeliveredFrom,
            supportsDeliveredTo: line.supportsDeliveredTo,
            supportNumber: line.supportNumber,
            claimReference: line.claimReference,
            quantity: line.quantity,
            hours: line.hours,
            unitPrice: line.unitPrice,
            gstCode: line.gstCode,
            authorisedBy: line.authorisedBy,
            participantApproved: line.participantApproved,
            inKindFundingProgram: line.inKindFundingProgram,
            claimTypeCode: line.claimTypeCode,
            cancellationReason: line.cancellationReason,
            abnOfSupportProvider: line.abnOfSupportProvider,
            draftLineId: line.draftLineId,
            isValid: line.isValid,
            validationErrorSummary: line.validationErrorSummary,
            submissionStatus: line.submissionStatus,
            submissionRef: line.submissionRef,
            reconciliationNotes: line.reconciliationNotes,
            reconciledAt: line.reconciledAt,
            ndiaPaidAmount: line.ndiaPaidAmount,
            ndiaErrorCode: line.ndiaErrorCode,
            ndiaErrorMessage: line.ndiaErrorMessage,
            batchId: line.batch?.id,
            invoiceId: line.invoice?.id,
            invoiceItemId: line.invoiceItem?.id
        )
    }
}

extension BusinessSnapshot {
    public init(_ business: Business) {
        self.init(
            abn: business.abn,
            name: business.name,
            email: business.email,
            phone: business.phone,
            id: business.id,
            logo: business.logo,
            bankAccountName: business.bankAccountName,
            bankAccountNumber: business.bankAccountNumber,
            bankBSB: business.bankBSB,
            bankName: business.bankName,
            accountingMethod: business.accountingMethod,
            ndiaOrganisationID: business.ndiaOrganisationID,
            isRegisteredProvider: business.isRegisteredProvider,
            defaultGstCode: business.defaultGstCode,
            address: business.address.map(AddressSnapshot.init)
        )
    }
}

extension ClaimableLineSnapshot {
    public init(_ line: ClaimableLine) {
        self.init(
            id: line.id,
            claimType: line.claimType,
            supportItemNumber: line.supportItemNumber,
            serviceFrom: line.serviceFrom,
            serviceTo: line.serviceTo,
            quantity: line.quantity,
            hoursHHHMM: line.hoursHHHMM,
            unitPrice: line.unitPrice,
            gstCode: line.gstCode,
            cancellationReason: line.cancellationReason,
            travelKM: line.travelKM,
            travelMinutes: line.travelMinutes,
            metadata: line.metadata,
            claimReference: line.claimReference,
            draftId: line.draftId,
            bulkClaimLineId: line.bulkClaimLine?.id
        )
    }
}

extension ClientServiceSnapshot {
    public init(_ service: ClientService) {
        self.init(
            id: service.id,
            serviceName: service.serviceName,
            ndisCode: service.ndisCode,
            unit: service.unit,
            rate: service.rate,
            isActive: service.isActive,
            startDate: service.startDate,
            endDate: service.endDate,
            isDefault: service.isDefault,
            ndisItemNumber: service.ndisItemNumber,
            gstCode: service.gstCode,
            consecutiveMonths: service.consecutiveMonths,
            status: service.status,
            clientId: service.client?.id,
            ndisItemId: service.ndisItem?.id
        )
    }
}

extension ClientSnapshot {
    public init(_ client: Client) {
        self.init(
            id: client.id,
            ndisNumber: client.ndisNumber,
            fullName: client.fullName,
            effectiveStatus: client.effectiveStatus,
            email: client.email,
            notes: client.notes,
            phoneNumber: client.phoneNumber,
            dateOfBirth: client.dateOfBirth,
            supportStartDate: client.supportStartDate,
            latitude: client.latitude,
            longitude: client.longitude,
            creditAmount: client.creditAmount,
            isMinor: client.isMinor,
            hasNdisPlan: client.hasNdisPlan,
            planManagementType: client.planManagementType,
            billingAuthority: client.billingAuthority,
            address: client.address.map(AddressSnapshot.init),
            sendInvoicesToClient: client.sendInvoicesToClient,
            sendInvoicesToPayee: client.sendInvoicesToPayee,
            sendInvoicesToPlanManager: client.sendInvoicesToPlanManager
        )
    }
}

extension DraftIssueSnapshot {
    public init(_ issue: DraftIssue) {
        self.init(
            id: issue.id,
            draftId: issue.draftId,
            severity: issue.severity,
            code: issue.code,
            message: issue.message,
            resolutionKind: issue.resolutionKind,
            resolutionData: issue.resolutionData,
            createdAt: issue.createdAt
        )
    }
}

extension InvoiceItemSnapshot {
    public init(_ item: InvoiceItem) {
        self.init(
            id: item.id,
            itemDescription: item.itemDescription,
            position: item.position,
            quantity: item.quantity,
            rate: item.rate,
            serviceDate: item.serviceDate,
            unit: item.unit,
            gstCode: item.gstCode,
            taxRate: item.taxRate,
            ndisItemNumber: item.ndisItemNumber,
            claimType: item.claimType,
            ndisSupportCategory: item.ndisSupportCategory,
            ndisRegistrationGroup: item.ndisRegistrationGroup,
            ndisOutcomeDomain: item.ndisOutcomeDomain,
            ndisSupportPurpose: item.ndisSupportPurpose,
            isComplexBehaviour: item.isComplexBehaviour,
            isHighIntensity: item.isHighIntensity,
            geographicLoading: item.geographicLoading,
            timeModifier: item.timeModifier,
            groupModifier: item.groupModifier,
            finalRateLimit: item.finalRateLimit,
            invoiceId: item.invoice?.id,
            sessionId: item.session?.id,
            clientServiceId: item.clientService?.id
        )
    }
}

extension InvoiceSnapshot {
    public init(_ invoice: Invoice) {
        self.init(
            invoiceNumber: invoice.invoiceNumber,
            id: invoice.id,
            totalAmount: invoice.totalAmount,
            taxRate: invoice.taxRate,
            creditApplied: invoice.creditApplied,
            discount: invoice.discount,
            date: invoice.date,
            dueDate: invoice.dueDate,
            issueDate: invoice.issueDate,
            notes: invoice.notes,
            paidDate: invoice.paidDate,
            paymentTerms: invoice.paymentTerms,
            effectiveStatus: invoice.effectiveStatus,
            sentDate: invoice.sentDate,
            currencyCode: invoice.currencyCode,
            isNDIAUploaded: invoice.isNDIAUploaded,
            ndiaUploadDate: invoice.ndiaUploadDate,
            isBulkClaimed: invoice.isBulkClaimed,
            businessName: invoice.businessName,
            businessABN: invoice.businessABN,
            businessEmail: invoice.businessEmail,
            businessAddressSnapshot: invoice.businessAddressSnapshot,
            businessPhone: invoice.businessPhone,
            clientName: invoice.clientName,
            clientNDISNumber: invoice.clientNDISNumber,
            clientEmail: invoice.clientEmail,
            clientPhone: invoice.clientPhone,
            clientAddressSnapshot: invoice.clientAddressSnapshot,
            billingAuthority: invoice.billingAuthority,
            billToName: invoice.billToName,
            billToEmail: invoice.billToEmail,
            billToAddressSnapshot: invoice.billToAddressSnapshot,
            payeeName: invoice.payeeName,
            payeeEmail: invoice.payeeEmail,
            payeePhone: invoice.payeePhone,
            payeeAddressSnapshot: invoice.payeeAddressSnapshot,
            bankName: invoice.bankName,
            bankAccountName: invoice.bankAccountName,
            bankBSB: invoice.bankBSB,
            bankAccountNumber: invoice.bankAccountNumber,
            invoiceEditorStateData: invoice.invoiceEditorStateData,
            invoiceEditorRevision: invoice.invoiceEditorRevision,
            itemSnapshots: invoice.itemsArray.map(InvoiceItemSnapshot.init),
            clientId: invoice.client?.id,
            payeeId: invoice.payee?.id,
            businessId: invoice.business?.id,
            sessionIds: invoice.sessions?.map(\.id) ?? []
        )
    }
}

extension NDISItemSnapshot {
    public init(_ item: NDISItem) {
        self.init(
            itemNumber: item.itemNumber,
            name: item.name,
            versionIdentifier: item.versionIdentifier,
            id: item.id,
            isCurrent: item.isCurrent,
            category: item.category,
            categoryNamePACE: item.categoryNamePACE,
            categoryNumber: item.categoryNumber,
            categoryNumberPACE: item.categoryNumberPACE,
            effectiveStartDate: item.effectiveStartDate,
            effectiveEndDate: item.effectiveEndDate,
            features: item.features,
            itemDescription: item.itemDescription,
            ndiaRequestedReports: item.ndiaRequestedReports,
            nonFaceToFaceProvision: item.nonFaceToFaceProvision,
            providerTravel: item.providerTravel,
            quoteRequired: item.quoteRequired,
            registrationGroup: item.registrationGroup,
            registrationGroupNumber: item.registrationGroupNumber,
            shortNoticeCancellations: item.shortNoticeCancellations,
            irregularSILSupports: item.irregularSILSupports,
            status: item.status,
            type: item.type,
            unit: item.unit,
            regionalPrices: (item.regionalPrices ?? []).map(RegionalPriceSnapshot.init),
            price: item.price,
            effectiveDateRange: item.effectiveDateRange
        )
    }
}

extension RegionalPriceSnapshot {
    public init(_ price: RegionalPrice) {
        self.init(
            id: price.id,
            amount: price.amount,
            regionIdentifier: price.regionIdentifier
        )
    }
}

extension ServiceAgreementSnapshot {
    public init(_ agreement: ServiceAgreement) {
        self.init(
            id: agreement.id,
            effectiveFrom: agreement.effectiveFrom,
            effectiveTo: agreement.effectiveTo,
            pricingDisclosureAcceptedAt: agreement.pricingDisclosureAcceptedAt,
            cancellationPolicyType: agreement.cancellationPolicyType,
            allowsProviderTravel: agreement.allowsProviderTravel,
            allowsTelehealth: agreement.allowsTelehealth,
            allowsNonFaceToFace: agreement.allowsNonFaceToFace,
            participantSignatoryName: agreement.participantSignatoryName,
            participantSignatoryRole: agreement.participantSignatoryRole,
            signedAt: agreement.signedAt,
            signatureMethod: agreement.signatureMethod,
            notes: agreement.notes,
            isArchived: agreement.isArchived,
            clientId: agreement.client?.id
        )
    }
}

extension SessionSnapshot {
    public init(_ session: Session) {
        self.init(
            id: session.id,
            title: session.title,
            startTime: session.startTime,
            endTime: session.endTime,
            isAllDay: session.isAllDay,
            location: session.location,
            notes: session.notes,
            status: session.status ?? .scheduled,
            isTravel: session.isTravel,
            groupID: session.groupID,
            groupedPosition: session.groupedPosition,
            sessionLatitude: session.sessionLatitude,
            sessionLongitude: session.sessionLongitude,
            travelDistanceKM: session.travelDistanceKM,
            travelTimeMinutes: session.travelTimeMinutes,
            travelTollsAmount: session.travelTollsAmount,
            recurrenceRuleData: session.recurrenceRuleData,
            clientId: session.client?.id,
            clientServiceId: session.clientService?.id,
            addressId: session.address?.id,
            ndisItemNumber: session.clientService?.ndisItemNumber,
            claimType: nil,
            attendeesCount: session.attendeesCount,
            travelCharges: (session.travelCharges ?? []).map(TravelChargeSnapshot.init)
        )
    }
}

extension SupportLogSnapshot {
    public init(_ log: SupportLog) {
        self.init(
            id: log.id,
            participantName: log.participantName,
            participantNdisNumber: log.participantNdisNumber,
            supportItemNumber: log.supportItemNumber,
            serviceDescription: log.serviceDescription,
            location: log.location,
            deliveredFrom: log.deliveredFrom,
            deliveredTo: log.deliveredTo,
            quantityHours: log.quantityHours,
            deliveredBy: log.deliveredBy,
            attestedBy: log.attestedBy,
            attestedAt: log.attestedAt,
            signatureMethod: log.signatureMethod,
            signedBy: log.signedBy,
            signedAt: log.signedAt,
            cancellationReasonCode: log.cancellationReasonCode,
            notes: log.notes,
            clientId: log.client?.id,
            sessionId: log.session?.id
        )
    }
}

extension TravelChargeAuditLogSnapshot {
    public init(_ log: TravelChargeAuditLog) {
        self.init(
            id: log.id,
            timestamp: log.timestamp,
            summary: log.summary,
            action: log.action,
            details: log.details,
            travelChargeId: log.charge?.id
        )
    }
}

extension TravelChargeReviewSnapshot {
    public init(_ item: TravelChargeReviewItem) {
        self.init(
            id: item.id,
            reason: item.reason,
            timestamp: item.timestamp,
            status: item.status,
            overrideReason: item.overrideReason,
            overrideType: item.overrideType,
            resolutionNotes: item.resolutionNotes,
            sessionID: item.sessionID,
            sessionTitle: item.sessionTitle,
            clientName: item.clientName,
            violations: item.violations,
            violationDetails: item.violationDetails,
            suggestedActions: item.suggestedActions,
            overrideOptions: item.overrideOptions,
            sessionId: item.session?.id
        )
    }
}

extension TravelChargeSnapshot {
    public init(_ charge: TravelCharge) {
        self.init(
            id: charge.id,
            chargeAmount: charge.chargeAmount,
            distanceKM: charge.distanceKM,
            durationMinutes: charge.durationMinutes,
            location: charge.location,
            effectiveStatus: charge.effectiveStatus,
            travelType: charge.travelType,
            travelDirection: charge.travelDirection,
            vehicleType: charge.vehicleType,
            participantCount: charge.participantCount,
            splitCosts: charge.splitCosts,
            parkingCost: charge.parkingCost,
            tollCost: charge.tollCost,
            notes: charge.notes,
            startTime: charge.startTime,
            endTime: charge.endTime,
            title: charge.title,
            ekEventID: charge.ekEventID,
            ekCalendarID: charge.ekCalendarID,
            ekCreationDate: charge.ekCreationDate,
            ekLastModifiedDate: charge.ekLastModifiedDate,
            latitude: charge.latitude,
            longitude: charge.longitude,
            mmmZoneName: charge.mmmZoneName,
            sessionId: charge.linkedSession?.id,
            clientId: charge.client?.id,
            serviceId: charge.service?.id
        )
    }
}
