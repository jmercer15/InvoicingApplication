import SwiftUI
import AppKit

enum PDFExporter {
    static func export(document: InvoiceDocument) {
        // Recreate the canvas off-screen using the current state
        let exportView = InvoiceCanvasView().environmentObject(document)

        // Bridge to AppKit
        let hosting = NSHostingView(rootView: exportView)
        hosting.frame = CGRect(origin: .zero, size: A4.size)

        // True vector PDF
        let pdfData = hosting.dataWithPDF(inside: hosting.bounds)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.title = "Save Invoice Template"
        panel.nameFieldStringValue = "InvoiceTemplate.pdf"

        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            do {
                try pdfData.write(to: url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
