import Foundation
import SwiftData

/// Helper for creating ModelContainer instances safely
public class ModelContainerHelper {
    public static func createModelContainerSafely() -> ModelContainer? {
        do {
            let schema = Schema([
                ClientEntity.self,
                BusinessEntity.self,
                AddressEntity.self,
                InvoiceEntity.self,
                InvoiceItemEntity.self,
                ClientServiceEntity.self,
                PayeeEntity.self,
                PlanManagerEntity.self,
                SessionEntity.self,
                TravelChargeEntity.self,
                TravelChargeAuditLog.self,
                TravelChargeReviewItem.self,
                CreditHistoryEntryEntity.self,
                NDISItemEntity.self,
                RegionalPriceEntity.self
            ])

            // Use consistent store name for persistent data
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            print("Created ModelContainer with persistent storage")
            return container
        } catch {
            print("Failed to create ModelContainer: \(error)")
            return nil
        }
    }
}
