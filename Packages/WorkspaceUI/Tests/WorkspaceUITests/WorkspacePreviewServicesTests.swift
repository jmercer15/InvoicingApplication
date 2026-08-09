import Data
import Foundation
import Testing
@testable import WorkspaceUI

@MainActor
struct WorkspacePreviewServicesTests {
    @Test
    func previewServicesConstructGeocodingService() {
        let service = WorkspacePreviewServices.makeSwiftDataGeocodingService()
        #expect(service is SwiftDataGeocodingService)
    }
}
