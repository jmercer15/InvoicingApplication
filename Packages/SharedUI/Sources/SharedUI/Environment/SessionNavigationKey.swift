import SwiftUI

public struct OpenSessionKey: EnvironmentKey {
    public static let defaultValue: (@Sendable (UUID) -> Void)? = nil
}

public extension EnvironmentValues {
    public var openSession: (@Sendable (UUID) -> Void)? {
        get { self[OpenSessionKey.self] }
        set { self[OpenSessionKey.self] = newValue }
    }
}
