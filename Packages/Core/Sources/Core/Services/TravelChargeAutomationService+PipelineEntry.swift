import Foundation
import os
import SwiftData

extension TravelChargeAutomationService {
    func automateTravelChargesAwaitable(for sessions: [SessionAutomationContext], dateRange: ClosedRange<Date>?) async {
        await automateTravelChargesAsync(for: sessions, dateRange: dateRange)
        if (try? modelContext.fetchCount(FetchDescriptor<Session>())) == nil {
            Logger.automation.error("Failed to confirm session availability after automated travel charge processing")
        }
    }
}

