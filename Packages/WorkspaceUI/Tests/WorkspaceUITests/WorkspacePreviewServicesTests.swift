import Data
import Foundation
import Testing
@testable import WorkspaceUI

@MainActor
struct WorkspacePreviewServicesTests {
    @Test
    func previewServicesConstructWorkingGeocodingService() async {
        let service = WorkspacePreviewServices.makeSwiftDataGeocodingService()
        let result = await service.geocodeAddressString("   ")
        #expect(result == nil)
    }
}
