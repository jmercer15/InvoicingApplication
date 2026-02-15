import SwiftUI

public struct OpenInvoiceKey: EnvironmentKey {
    public static let defaultValue: (@Sendable (UUID) -> Void)? = nil
}

public extension EnvironmentValues {
    var openInvoice: (@Sendable (UUID) -> Void)? {
        get { self[OpenInvoiceKey.self] }
        set { self[OpenInvoiceKey.self] = newValue }
    }
}
