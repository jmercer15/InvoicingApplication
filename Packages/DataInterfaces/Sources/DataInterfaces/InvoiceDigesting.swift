import Core

/// Minimal interface used by invoice editing to query invoice numbering state.
///
/// Implemented by Data-layer actors (e.g. `InvoiceDigestActor`) but depended on by feature modules.
public protocol InvoiceDigesting: Sendable {
    func allInvoiceNumbers() async throws -> [String]
}

