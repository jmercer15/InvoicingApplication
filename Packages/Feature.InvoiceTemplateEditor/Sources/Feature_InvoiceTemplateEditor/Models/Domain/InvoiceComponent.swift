import Foundation
import CoreGraphics
import CoreTransferable
import UniformTypeIdentifiers
import SwiftUI

enum InvoiceComponentType: String, CaseIterable, Identifiable, Codable {
    case invoiceNumberAndDates = "Invoice Number & Dates"
    case billTo = "Bill To"
    case participant = "Participant"
    case servicesTable = "Services Table"
        case documentGrid = "Document Grid"
    case totals = "Totals"
    case paymentDetails = "Payment Details"
    case paymentTerms = "Payment Terms"
    case invoiceTitle = "Invoice Title"
    case companyName = "Company Name"
    case companyABN = "Company ABN"
    case companyEmail = "Company Email"
    case companyLogo = "Company Logo"
    case notes = "Notes"
    case textBox = "Text Box"
    case rectangleShape = "Rectangle"
    case ellipseShape = "Ellipse"
    case lineShape = "Line"
    case triangleShape = "Triangle"
    case starShape = "Star"
    case imagePlaceholder = "Image Placeholder"
    var id: String { self.rawValue }
    var isSection: Bool {
        switch self {
        case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .documentGrid, .totals, .paymentDetails:
            return true
        default:
            return false
        }
    }
}

struct InvoiceComponent: Identifiable, Codable, Transferable {
    var id: UUID
    let type: InvoiceComponentType
    var position: CGPoint
    var size: CGSize
    var style: ComponentStyle
    var isResizing: Bool = false 
    var isVisible: Bool = true
    var isLocked: Bool = false
    enum CodingKeys: String, CodingKey {
        case id, type, position, size, style, isResizing, isVisible, isLocked
    }
    init(
        id: UUID = UUID(),
        type: InvoiceComponentType,
        position: CGPoint = .zero,
        size: CGSize,
        style: ComponentStyle? = nil,
        isVisible: Bool = true,
        isLocked: Bool = false
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.style = style ?? ComponentStyle.defaultStyle(for: type)
        self.isResizing = false
        self.isVisible = isVisible
        self.isLocked = isLocked
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(InvoiceComponentType.self, forKey: .type)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        style = try container.decodeIfPresent(ComponentStyle.self, forKey: .style) ?? ComponentStyle.defaultStyle(for: type)
        isResizing = try container.decodeIfPresent(Bool.self, forKey: .isResizing) ?? false
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
        try container.encode(style, forKey: .style)
        try container.encode(isResizing, forKey: .isResizing)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(isLocked, forKey: .isLocked)
    }
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .invoiceComponent)
    }
    var frame: CGRect {
        CGRect(
            x: position.x - (size.width / 2),
            y: position.y - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }
    var boundingRect: CGRect { frame }
}

