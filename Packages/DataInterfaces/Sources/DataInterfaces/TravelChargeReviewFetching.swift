import Foundation

/// Reads travel-charge review queue rows for Settings review screens.
///
/// Implemented by `SwiftDataTravelChargeReviewMainContextPersistence` in the Data package.
@MainActor
public protocol TravelChargeReviewFetching: AnyObject, Sendable {
    func fetchAllReviewItems() throws -> [TravelChargeReviewRow]
}
