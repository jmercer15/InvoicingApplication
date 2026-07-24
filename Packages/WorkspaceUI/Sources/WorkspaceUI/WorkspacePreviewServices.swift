import SwiftUI
import Data

/// Shared construction helpers for SwiftUI previews and tests so feature modules do not
/// allocate `SwiftDataGeocodingService` (and related NDIS wiring) in ad-hoc ways.
public enum WorkspacePreviewServices {
    /// Stateless service; each preview may use its own instance tied to the preview’s `ModelContext`.
    @MainActor
    public static func makeSwiftDataGeocodingService() -> SwiftDataGeocodingService {
        SwiftDataGeocodingService()
    }
}
