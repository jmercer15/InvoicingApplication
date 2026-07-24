import Core
import Foundation
import SwiftData

/// Backfills additional EventKit reconciliation metadata introduced after v1.
public enum BackfillEventKitSyncMetadata_v2 {
    public static let version = "1.0.0"

    public static func execute(modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<Session>()
        let sessions = try modelContext.fetch(descriptor)
        var rewrites = 0

        for session in sessions {
            var changed = false

            if session.eventKitConsecutiveWindowMisses < 0 {
                session.eventKitConsecutiveWindowMisses = 0
                changed = true
            }

            // Preserve existing stale links under the new two-pass policy.
            if session.isEventKitLinkStale, session.eventKitConsecutiveWindowMisses < 2 {
                session.eventKitConsecutiveWindowMisses = 2
                changed = true
            }

            if changed {
                rewrites += 1
            }
        }

        if rewrites > 0 {
            try modelContext.save()
        }
    }

    public static func rollback(modelContext _: ModelContext) throws {}
}
