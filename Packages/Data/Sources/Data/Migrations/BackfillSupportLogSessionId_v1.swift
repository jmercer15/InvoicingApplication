import PersistenceModels
import Foundation
import SwiftData

/// Backfills `SupportLog.sessionId` from the session relationship for predicate-friendly bulk fetches.
public enum BackfillSupportLogSessionId_v1 {
    public static let version = "1.0.0"

    public static func execute(modelContext: ModelContext) throws {
        let logs = try modelContext.fetch(FetchDescriptor<SupportLog>())
        var rewrites = 0

        for log in logs {
            let resolved = log.session?.id
            guard log.sessionId != resolved else { continue }
            log.sessionId = resolved
            rewrites += 1
        }

        if rewrites > 0 {
            try modelContext.save()
        }
        print("BackfillSupportLogSessionId_v1 updated \(rewrites) support logs")
    }

    public static func rollback(modelContext: ModelContext) throws {
        _ = modelContext
    }
}
