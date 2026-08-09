
/// Minimal interface used by invoice editing to query invoice numbering state.
///
/// Implemented by Data-layer actors (e.g. `InvoiceDigestActor`) and consumed by feature modules
/// that must validate uniqueness without importing concrete persistence types.
public protocol InvoiceDigesting: Sendable {
    /// Returns every stored invoice number string.
    ///
    /// - Returns: All invoice numbers currently persisted in the store.
    /// - Throws: Persistence errors when the backing fetch fails.
    func allInvoiceNumbers() async throws -> [String]
}
