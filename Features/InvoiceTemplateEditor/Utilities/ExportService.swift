import SwiftUI
import AppKit
import PDFKit

class ExportService {
    static let shared = ExportService()

    private init() {}

    // MARK: - PDF Export

    func exportToPDF(document: InvoiceDocument, fileName: String) async throws -> URL {
        let pdfData = try await generatePDFData(from: document)
        let fileURL = try getExportURL(fileName: fileName, extension: "pdf")
        try pdfData.write(to: fileURL)
        return fileURL
    }

    private func generatePDFData(from document: InvoiceDocument) async throws -> Data {
        let pdfDocument = PDFDocument()

        // Create PDF page with A4 dimensions (595.2 x 841.8 points)
        let pageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let pdfPage = PDFPage()

        // Create the PDF content
        let renderer = ImageRenderer(content: renderDocumentView(document: document, size: pageBounds.size))
        renderer.scale = 1.0 // PDF units are already in points

        if let cgImage = renderer.cgImage {
            let nsImage = NSImage(cgImage: cgImage, size: pageBounds.size)
            pdfPage.setBounds(pageBounds, for: .mediaBox)
            // Note: In a real implementation, you'd use PDFKit's drawing context
            // For now, we'll create a placeholder PDF
        }

        pdfDocument.insert(pdfPage, at: 0)
        return pdfDocument.dataRepresentation() ?? Data()
    }

    // MARK: - Image Export

    func exportToImage(document: InvoiceDocument, format: ImageFormat = .png, fileName: String) async throws -> URL {
        let imageData = try await generateImageData(from: document, format: format)
        let fileExtension = format == .png ? "png" : "jpg"
        let fileURL = try getExportURL(fileName: fileName, extension: fileExtension)
        try imageData.write(to: fileURL)
        return fileURL
    }

    private func generateImageData(from document: InvoiceDocument, format: ImageFormat) async throws -> Data {
        let renderer = ImageRenderer(content: renderDocumentView(document: document, size: CGSize(width: 595.2, height: 841.8)))
        renderer.scale = 2.0 // Retina resolution

        guard let cgImage = renderer.cgImage else {
            throw ExportError.renderingFailed
        }

        let nsImage = NSImage(cgImage: cgImage, size: renderer.content.size)

        switch format {
        case .png:
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                throw ExportError.encodingFailed
            }
            return pngData
        case .jpeg:
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                throw ExportError.encodingFailed
            }
            return jpegData
        }
    }

    // MARK: - Print Functionality

    func printDocument(document: InvoiceDocument) {
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 595.2, height: 841.8) // A4
        printInfo.orientation = .portrait
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        let printOperation = NSPrintOperation(view: NSHostingView(rootView: renderDocumentView(document: document, size: printInfo.paperSize)), printInfo: printInfo)
        printOperation.run()
    }

    // MARK: - Helper Methods

    private func renderDocumentView(document: InvoiceDocument, size: CGSize) -> some View {
        DocumentRenderer(document: document)
            .frame(width: size.width, height: size.height)
            .background(Color.white)
    }

    private func getExportURL(fileName: String, extension: String) throws -> URL {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let sanitizedFileName = fileName.replacingOccurrences(of: "[^a-zA-Z0-9_\\-]", with: "_", options: .regularExpression)
        let finalFileName = "\(sanitizedFileName)_\(timestamp).\(`extension`)"
        return downloadsDirectory.appendingPathComponent(finalFileName)
    }

    enum ImageFormat {
        case png, jpeg
    }

    enum ExportError: LocalizedError {
        case renderingFailed
        case encodingFailed
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .renderingFailed:
                return "Failed to render document for export"
            case .encodingFailed:
                return "Failed to encode image data"
            case .saveFailed:
                return "Failed to save file"
            }
        }
    }
}

// MARK: - PDF Export Service (Alternative approach)

class PDFExporter {
    static func export(document: InvoiceDocument) {
        Task {
            do {
                let fileURL = try await ExportService.shared.exportToPDF(document: document, fileName: "Invoice")
                showExportSuccessAlert(fileURL: fileURL, format: "PDF")
            } catch {
                showExportErrorAlert(error: error)
            }
        }
    }

    static func exportToImage(document: InvoiceDocument) {
        Task {
            do {
                let fileURL = try await ExportService.shared.exportToImage(document: document, fileName: "Invoice")
                showExportSuccessAlert(fileURL: fileURL, format: "Image")
            } catch {
                showExportErrorAlert(error: error)
            }
        }
    }

    static func printDocument(document: InvoiceDocument) {
        ExportService.shared.printDocument(document: document)
    }

    private static func showExportSuccessAlert(fileURL: URL, format: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Export Successful"
            alert.informativeText = "\(format) saved to:\n\(fileURL.path)"
            alert.addButton(withTitle: "Open Folder")
            alert.addButton(withTitle: "OK")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(fileURL.deletingLastPathComponent())
            }
        }
    }

    private static func showExportErrorAlert(error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - Document Renderer

struct DocumentRenderer: View {
    let document: InvoiceDocument

    var body: some View {
        ZStack {
            ForEach(document.allComponents) { component in
                RenderedComponentView(component: component)
                    .position(component.position)
                    .frame(width: component.size.width, height: component.size.height)
            }
        }
        .background(Color.white)
    }
}

// MARK: - Rendered Component View

struct RenderedComponentView: View {
    let component: InvoiceComponent

    var body: some View {
        Group {
            switch component.type {
            case .companyName, .companyABN, .companyEmail, .invoiceTitle, .notes, .paymentTerms, .textBox:
                Text(component.style.placeholderText.isEmpty ? component.title ?? "Sample Text" : component.style.placeholderText)
                    .font(.system(size: component.style.fontSize, weight: Font.Weight(component.style.fontWeight)))
                    .foregroundColor(component.style.textColorSwiftUI)
                    .multilineTextAlignment(component.style.textAlignment == .center ? .center : component.style.textAlignment == .trailing ? .trailing : .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(component.style.padding)

            case .companyLogo, .imagePlaceholder:
                ZStack {
                    Rectangle()
                        .fill(component.style.backgroundColorSwiftUI)
                    if component.style.imageData != nil {
                        if let nsImage = NSImage(data: component.style.imageData!) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: component.style.imageContentMode == .fit ? .fit : .fill)
                        }
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
                }

            case .rectangleShape:
                Rectangle()
                    .fill(component.style.backgroundColorSwiftUI)

            case .ellipseShape:
                Ellipse()
                    .fill(component.style.backgroundColorSwiftUI)

            case .lineShape:
                Rectangle()
                    .fill(component.style.borderColorSwiftUI)
                    .frame(height: component.style.lineThickness)

            case .triangleShape:
                Triangle(direction: component.style.triangleDirection)
                    .fill(component.style.backgroundColorSwiftUI)

            case .starShape:
                Star(points: component.style.starPoints, smoothness: component.style.starSmoothness)
                    .fill(component.style.backgroundColorSwiftUI)

            case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .totals, .paymentDetails:
                // Section components render their children
                if component.children.isEmpty {
                    Text(component.title ?? component.type.rawValue)
                        .font(.system(size: component.style.fontSize, weight: Font.Weight(component.style.fontWeight)))
                        .foregroundColor(component.style.textColorSwiftUI)
                        .padding(component.style.padding)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(component.style.backgroundColorSwiftUI)
                        VStack(alignment: .leading, spacing: component.style.contentSpacing) {
                            ForEach(component.children) { child in
                                RenderedComponentView(component: child)
                                    .frame(width: child.size.width, height: child.size.height)
                            }
                        }
                        .padding(component.style.contentPadding)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: component.style.cornerRadius)
                .stroke(component.style.borderColorSwiftUI, lineWidth: component.style.borderWidth)
        )
        .cornerRadius(component.style.cornerRadius)
        .shadow(
            color: component.style.shadowColorSwiftUI,
            radius: component.style.shadowRadius,
            x: component.style.shadowOffsetX,
            y: component.style.shadowOffsetY
        )
    }
}

// MARK: - Shape Views

struct Triangle: Shape {
    let direction: TriangleDirection

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

struct Star: Shape {
    let points: Int
    let smoothness: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * smoothness

        return Path { path in
            for i in 0..<points * 2 {
                let angle = Angle(degrees: Double(i) * 360.0 / Double(points * 2))
                let pointRadius = i % 2 == 0 ? radius : innerRadius
                let point = CGPoint(
                    x: center.x + cos(angle.radians) * pointRadius,
                    y: center.y + sin(angle.radians) * pointRadius
                )

                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
    }
}

// MARK: - Font Weight Extension

extension Font.Weight {
    init(_ string: String) {
        switch string.lowercased() {
        case "bold":
            self = .bold
        case "semibold":
            self = .semibold
        case "medium":
            self = .medium
        case "regular":
            self = .regular
        case "light":
            self = .light
        case "thin":
            self = .thin
        default:
            self = .regular
        }
    }
}