import Core
import Foundation

extension TravelChargeAutomationService {
    public func getTestResults() -> (charges: [String], reviews: [String], detailedReviews: [DetailedReviewItem]) {
        (testTravelChargeSummaries, testReviewSummaries, testDetailedReviewItemsSnapshot())
    }
}

