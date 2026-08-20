import Foundation
import Testing
import CoreTesting
@testable import InvoiceTableLayoutEditor

@Suite(.tags(.integration))
struct InvoiceTemporaryPDFWorkspaceTests {
    @Test func workspaceUsesAppControlledSubdirectory() throws {
        let workspace = try InvoiceTemporaryPDFWorkspace.makeDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }

        #expect(workspace.path.contains("com.invoicing.invoice-pdf"))
        let url = workspace
        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)

        let attributes = try FileManager.default.attributesOfItem(atPath: workspace.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        #expect(permissions == 0o700)
    }

    @Test func fileAttributesRestrictPermissions() throws {
        let workspace = try InvoiceTemporaryPDFWorkspace.makeDirectory()
        defer { try? FileManager.default.removeItem(at: workspace) }

        let fileURL = workspace.appendingPathComponent("sample.pdf")
        try Data("pdf".utf8).write(to: fileURL)
        try InvoiceTemporaryPDFWorkspace.applyRestrictiveAttributes(to: fileURL, isDirectory: false)

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        #expect(permissions == 0o600)
    }

    @Test func secureDeleteOverwritesFileContentsBeforeRemoval() throws {
        let workspace = try InvoiceTemporaryPDFWorkspace.makeDirectory()
        let fileURL = workspace.appendingPathComponent("sample.pdf")
        let secret = Data("participant-ndis-payload".utf8)
        try secret.write(to: fileURL)

        InvoiceTemporaryPDFWorkspace.securelyDeleteWorkspace(at: workspace)

        #expect(FileManager.default.fileExists(atPath: workspace.path) == false)
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
    }
}
