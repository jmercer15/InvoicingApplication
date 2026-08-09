import Foundation

/// App-controlled temporary PDF workspace with restrictive file attributes.
enum InvoiceTemporaryPDFWorkspace {
    private static let rootFolderName = "com.invoicing.invoice-pdf"

    static func makeDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(rootFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try applyRestrictiveAttributes(to: root, isDirectory: true)

        let workspace = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try applyRestrictiveAttributes(to: workspace, isDirectory: true)
        return workspace
    }

    static func applyRestrictiveAttributes(to url: URL, isDirectory: Bool) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)
        try FileManager.default.setAttributes(
            [.posixPermissions: isDirectory ? NSNumber(value: Int16(0o700)) : NSNumber(value: Int16(0o600))],
            ofItemAtPath: url.path
        )
    }
}
