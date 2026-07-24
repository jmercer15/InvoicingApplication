import Foundation

enum InvoicePDFFileWriter {
    /// Reads source completely before atomically replacing destination. A source/read failure
    /// therefore cannot remove or truncate an existing exported invoice.
    static func write(source: URL, to destination: URL) throws {
        let data = try Data(contentsOf: source, options: .mappedIfSafe)
        try data.write(to: destination, options: .atomic)
    }
}
