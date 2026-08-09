import SwiftUI
import SwiftData
import Core
import PersistenceModels

extension NDISContainerViewModel {
    
    struct CatalogueProcessingContext: Sendable {
        let requestID: UUID
        let items: [NDISItemSnapshot]
        let querySpec: NDISCatalogueQuerySpec
        let selectedItemID: UUID?
        let preferredRegionIdentifier: String?
    }

    struct NDISCatalogueProjectionResult: Sendable {
        let requestID: UUID
        let state: ProcessedCatalogueState
    }

    struct CatalogueCaches: Sendable {
        let categories: [String]
        let features: [String]
        let registrationGroups: [String]
        let units: [String]
    }

    struct ProcessedCatalogueState: Sendable {
        let caches: CatalogueCaches
        let projection: NDISCatalogueProjection
    }

    public enum FilterType: Hashable, Sendable {
        case category
        case group
        case quote
        case feature(String)
        case unit(String)
    }

    public struct ActiveFilter: Identifiable, Hashable, Sendable {
        public let type: FilterType
        public let name: String
        public var id: String { name }
        
        public init(type: FilterType, name: String) {
            self.type = type
            self.name = name
        }
    }
}
