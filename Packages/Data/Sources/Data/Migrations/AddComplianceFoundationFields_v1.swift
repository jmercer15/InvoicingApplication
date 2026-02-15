import Foundation
import SwiftData

public enum AddComplianceFoundationFields_v1 {
    public static let version = "1.0.0"

    public static func execute(modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<BusinessEntity>()
        let businesses = try modelContext.fetch(descriptor)

        var changed = false
        for business in businesses {
            if business.defaultGstCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                business.defaultGstCode = "P2"
                changed = true
            }

            if let orgID = business.ndiaOrganisationID?.trimmingCharacters(in: .whitespacesAndNewlines),
               orgID.isEmpty {
                business.ndiaOrganisationID = nil
                changed = true
            }
        }

        if changed {
            try modelContext.save()
        }
    }

    public static func rollback(modelContext: ModelContext) throws {
        _ = modelContext
        // Additive migration. Explicit rollback not supported.
    }
}
