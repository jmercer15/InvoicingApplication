import Foundation
import Core

/// Maps between the `Business` domain model and `BusinessEntity` persistence model.
public struct BusinessMapper: ModelMapper {
    public typealias DomainModel = Business
    public typealias PersistenceEntity = BusinessEntity
    
    private let addressMapper = AddressMapper()
    
    public init() {}
    
    public func mapToDomain(_ entity: BusinessEntity) -> Business {
        let bankDetails: BankDetails? = {
            guard let accountName = entity.bankAccountName,
                  let accountNumber = entity.bankAccountNumber,
                  let bsb = entity.bankBSB,
                  let bankName = entity.bankName else {
                return nil
            }
            return BankDetails(
                accountName: accountName,
                accountNumber: accountNumber,
                bsb: bsb,
                bankName: bankName
            )
        }()
        
        return Business(
            id: entity.id,
            name: entity.name,
            abn: entity.abn,
            email: entity.email.isEmpty ? nil : entity.email,
            phone: entity.phone.isEmpty ? nil : entity.phone,
            address: entity.address.map { addressMapper.mapToDomain($0) },
            logo: entity.logo,
            bankDetails: bankDetails,
            accountingMethod: entity.accountingMethod,
            ndiaOrganisationID: entity.ndiaOrganisationID,
            isRegisteredProvider: entity.isRegisteredProvider,
            defaultGstCode: entity.defaultGstCode
        )
    }
    
    public func mapToEntity(_ domain: Business) -> BusinessEntity {
        let entity = BusinessEntity(id: domain.id, abn: domain.abn ?? "")
        updateEntityProperties(entity, from: domain)
        return entity
    }
    
    public func updateEntity(_ entity: inout BusinessEntity, from domain: Business) {
        updateEntityProperties(entity, from: domain)
    }
    
    private func updateEntityProperties(_ entity: BusinessEntity, from domain: Business) {
        entity.name = domain.name
        entity.email = domain.email ?? ""
        entity.phone = domain.phone ?? ""
        entity.logo = domain.logo
        entity.accountingMethod = domain.accountingMethod
        entity.bankAccountName = domain.bankDetails?.accountName
        entity.bankAccountNumber = domain.bankDetails?.accountNumber
        entity.bankBSB = domain.bankDetails?.bsb
        entity.bankName = domain.bankDetails?.bankName
        entity.ndiaOrganisationID = domain.ndiaOrganisationID
        entity.isRegisteredProvider = domain.isRegisteredProvider
        entity.defaultGstCode = domain.defaultGstCode
        // Note: Address relationship handled separately via repository
    }
}
