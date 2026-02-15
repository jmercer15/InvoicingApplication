import Foundation
import SwiftData
import Core

/// SwiftData implementation of BusinessRepository
public final class BusinessRepositorySwiftData: BusinessRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let mapper: BusinessMapper
    private let validGstCodes: Set<String> = ["P1", "P2", "P5"]
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.mapper = BusinessMapper()
    }
    
    public func fetch(by id: UUID) async throws -> Business? {
        let predicate = #Predicate<BusinessEntity> { business in
            business.id == id
        }
        let descriptor = FetchDescriptor<BusinessEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func fetchFirst() async throws -> Business? {
        let descriptor = FetchDescriptor<BusinessEntity>()
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }
    
    public func update(_ business: Business) async throws -> Business {
        let normalized = try validateAndNormalize(business)

        return try await MainActor.run {
            // Check if any business entity exists (since singleton concept mostly applies here)
            // or match by ID if strictly enforced
            let descriptor = FetchDescriptor<BusinessEntity>()
            if let entity = try modelContext.fetch(descriptor).first {
                var mutableEntity = entity
                mapper.updateEntity(&mutableEntity, from: normalized)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw RepositoryError.saveFailed
                }
                return mapper.mapToDomain(entity)
            } else {
                // Create if not exists (though fetchFirst implies lookup)
                var entity = BusinessEntity(id: normalized.id, abn: normalized.abn ?? "")
                mapper.updateEntity(&entity, from: normalized)
                modelContext.insert(entity)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw RepositoryError.saveFailed
                }
                return mapper.mapToDomain(entity)
            }
        }
    }

    private func validateAndNormalize(_ business: Business) throws -> Business {
        var normalized = business

        let gstCode = business.defaultGstCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard validGstCodes.contains(gstCode) else {
            throw RepositoryError.validationFailed(message: "Default GST code must be one of P1, P2, or P5.")
        }
        normalized.defaultGstCode = gstCode

        let trimmedOrgId = business.ndiaOrganisationID?.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.ndiaOrganisationID = (trimmedOrgId?.isEmpty == true) ? nil : trimmedOrgId

        if business.isRegisteredProvider {
            guard let orgId = normalized.ndiaOrganisationID,
                  (1...30).contains(orgId.count),
                  CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: orgId)) else {
                throw RepositoryError.validationFailed(message: "NDIA Organisation ID is required for registered providers and must be numeric (1-30 digits).")
            }
        }

        return normalized
    }
}
