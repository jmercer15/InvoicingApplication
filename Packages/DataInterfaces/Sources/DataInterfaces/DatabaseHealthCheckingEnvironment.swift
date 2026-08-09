import SwiftUI

private struct DatabaseHealthCheckingEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any DatabaseHealthChecking)? = nil
}

public extension EnvironmentValues {
    var databaseHealthChecking: (any DatabaseHealthChecking)? {
        get { self[DatabaseHealthCheckingEnvironmentKey.self] }
        set { self[DatabaseHealthCheckingEnvironmentKey.self] = newValue }
    }
}
