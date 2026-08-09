import SwiftUI

private struct ReferenceDataFetchingEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any ReferenceDataFetching)? = nil
}

public extension EnvironmentValues {
    var referenceDataFetching: (any ReferenceDataFetching)? {
        get { self[ReferenceDataFetchingEnvironmentKey.self] }
        set { self[ReferenceDataFetchingEnvironmentKey.self] = newValue }
    }
}
