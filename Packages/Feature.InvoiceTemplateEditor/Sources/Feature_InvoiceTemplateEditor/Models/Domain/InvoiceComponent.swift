import Foundation
import CoreGraphics
import CoreTransferable
import UniformTypeIdentifiers
import SwiftUI

public enum InvoiceComponentType: String, CaseIterable, Identifiable, Codable, Sendable {
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
    public var id: String { self.rawValue }
    public var isSection: Bool {
        switch self {
        case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .documentGrid, .totals, .paymentDetails:
            return true
        default:
            return false
        }
    }
}

public struct InvoiceComponent: Identifiable, Codable, Transferable, Equatable, Sendable {
    public var id: UUID
    public let type: InvoiceComponentType
    public var position: CGPoint
    public var size: CGSize
    public var idealSize: CGSize? // Unconstrained size for "Shrink to Fit" calculations
    public var style: ComponentStyle
    public var isResizing: Bool = false
    public var isVisible: Bool = true
    public var isLocked: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, type, position, size, idealSize, style, isResizing, isVisible, isLocked
    }
    
    public init(
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(InvoiceComponentType.self, forKey: .type)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        idealSize = try container.decodeIfPresent(CGSize.self, forKey: .idealSize)
        style = try container.decodeIfPresent(ComponentStyle.self, forKey: .style) ?? ComponentStyle.defaultStyle(for: type)
        isResizing = try container.decodeIfPresent(Bool.self, forKey: .isResizing) ?? false
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
        try container.encodeIfPresent(idealSize, forKey: .idealSize)
        try container.encode(style, forKey: .style)
        try container.encode(isResizing, forKey: .isResizing)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(isLocked, forKey: .isLocked)
    }
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .invoiceComponent)
    }
    public var frame: CGRect {
        CGRect(
            x: position.x - (size.width / 2),
            y: position.y - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }
    public var boundingRect: CGRect { frame }
    
    public var usesTableProperties: Bool {
        switch type {
        case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .documentGrid, .totals, .paymentDetails:
            return true
        default:
            return false
        }
    }
    
    var minIntrinsicWidth: CGFloat? {
        guard usesTableProperties else { return nil }
        
        // Calculate minimum width based on columns
        var minWidth: CGFloat = 0
        let configs: [ComponentStyle.ColumnConfiguration]
        
        if style.tableDirection == .horizontal {
            configs = Array(style.columnConfigurations.values)
        } else {
             // Row configurations mapped to columns
             configs = Array(style.rowConfigurations.values).map { row in
                ComponentStyle.ColumnConfiguration(
                    width: row.height,
                    isFlexible: row.isFlexible,
                    alignment: row.alignment,
                    verticalAlignment: row.verticalAlignment,
                    headerAlignment: row.headerAlignment,
                    headerVerticalAlignment: row.headerVerticalAlignment,
                    lineLimit: row.lineLimit
                )
            }
        }
        
        // If no configs, assume flexible default
        if configs.isEmpty {
            return 40 // Default min width
        }
        
        for config in configs {
            if config.isFlexible {
                // If any column is flexible, we can't determine a meaningful minimum width
                // that isn't "collapsed". It's better to fallback to the component's
                // current size (which might be manually set or default).
                return nil
            }
            
            if config.isAutoSized {
                minWidth += config.width // Use measured width (updated by view)
            } else {
                minWidth += config.width
            }
        }
        
        return minWidth > 0 ? minWidth : nil
    }
    
    var minIntrinsicHeight: CGFloat? {
        // Always return nil to allow the component's measured size (component.size.height)
        // to drive the layout. This ensures that auto-sizing works correctly and
        // parent splits utilize the actual reported height.
        return nil
    }
}

