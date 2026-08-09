import SwiftUI

private struct ClaimBatchPersistingEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any ClaimBatchPersisting)? = nil
}

private struct BusinessPersistingEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any BusinessPersisting)? = nil
}

private struct TravelChargeReviewFetchingEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any TravelChargeReviewFetching)? = nil
}

public extension EnvironmentValues {
    var claimBatchPersisting: (any ClaimBatchPersisting)? {
        get { self[ClaimBatchPersistingEnvironmentKey.self] }
        set { self[ClaimBatchPersistingEnvironmentKey.self] = newValue }
    }

    var businessPersisting: (any BusinessPersisting)? {
        get { self[BusinessPersistingEnvironmentKey.self] }
        set { self[BusinessPersistingEnvironmentKey.self] = newValue }
    }

    var travelChargeReviewFetching: (any TravelChargeReviewFetching)? {
        get { self[TravelChargeReviewFetchingEnvironmentKey.self] }
        set { self[TravelChargeReviewFetchingEnvironmentKey.self] = newValue }
    }
}
