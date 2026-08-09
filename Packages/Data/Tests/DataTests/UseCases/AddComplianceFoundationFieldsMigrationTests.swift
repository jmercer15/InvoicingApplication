import Foundation
import Testing
import SwiftData
@testable import Data
import Core
import PersistenceModels

@MainActor
@Suite struct AddComplianceFoundationFieldsMigrationTests {
    private let modelContext: ModelContext

    init() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        self.modelContext = context
    }

    @Test func MigrationSetsDefaultsAndNormalizesBlankOrgID() throws {
        let business = Business(id: UUID(), abn: "53004085616")
        business.defaultGstCode = ""
        business.ndiaOrganisationID = "   "
        modelContext.insert(business)
        try modelContext.save()

        try AddComplianceFoundationFields_v1.execute(modelContext: modelContext)

        let fetched = try modelContext.fetch(FetchDescriptor<Business>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.defaultGstCode == "P2")
        #expect(fetched.first?.ndiaOrganisationID == nil)
    }

    @Test func MigrationIsIdempotentAndPreservesConfiguredValues() throws {
        let business = Business(id: UUID(), abn: "53004085617")
        business.defaultGstCode = "P1"
        business.ndiaOrganisationID = "123456789"
        business.isRegisteredProvider = true
        modelContext.insert(business)
        try modelContext.save()

        try AddComplianceFoundationFields_v1.execute(modelContext: modelContext)
        try AddComplianceFoundationFields_v1.execute(modelContext: modelContext)

        let fetched = try modelContext.fetch(FetchDescriptor<Business>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.defaultGstCode == "P1")
        #expect(fetched.first?.ndiaOrganisationID == "123456789")
        #expect(fetched.first?.isRegisteredProvider == true)
    }
}
