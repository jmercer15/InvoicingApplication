import Foundation
import CoreGraphics

// MARK: - Coordinate System Utilities

/// Utilities for converting between UI and PDF coordinate systems
/// This ensures consistent coordinate handling across the entire InvoiceTemplateEditor feature
struct CoordinateConverter {
    /// Converts UI coordinates (top-left origin, Y down) to PDF coordinates (bottom-left origin, Y up)
    /// - Parameters:
    ///   - uiPoint: Point in UI coordinate system
    ///   - pageHeight: Height of the page
    /// - Returns: Point in PDF coordinate system
    static func uiToPDF(_ uiPoint: CGPoint, pageHeight: CGFloat) -> CGPoint {
        return CGPoint(x: uiPoint.x, y: pageHeight - uiPoint.y)
    }
    
    /// Converts UI rectangle (top-left origin, Y down) to PDF rectangle (bottom-left origin, Y up)
    /// - Parameters:
    ///   - uiRect: Rectangle in UI coordinate system
    ///   - pageHeight: Height of the page
    /// - Returns: Rectangle in PDF coordinate system
    static func uiToPDF(_ uiRect: CGRect, pageHeight: CGFloat) -> CGRect {
        let pdfOrigin = uiToPDF(uiRect.origin, pageHeight: pageHeight)
        // For rectangles, we need to adjust the origin because the Y-axis is flipped
        let adjustedOrigin = CGPoint(x: pdfOrigin.x, y: pdfOrigin.y - uiRect.height)
        return CGRect(origin: adjustedOrigin, size: uiRect.size)
    }
    
}

// MARK: - Coordinate Calculation Utilities

/// Utilities for consistent coordinate calculations across the InvoiceTemplateEditor feature
struct CoordinateCalculator {
    /// Calculates the content area rectangle in UI coordinates based on page size and margins
    /// - Parameters:
    ///   - pageSize: The size of the page
    ///   - margins: The document margins
    /// - Returns: Content area rectangle in UI coordinates
    static func contentArea(pageSize: CGSize, margins: InvoiceDocument.DocumentMargins) -> CGRect {
        return CGRect(
            x: margins.left,
            y: margins.top,
            width: pageSize.width - margins.left - margins.right,
            height: pageSize.height - margins.top - margins.bottom
        )
    }
    
    /// Calculates component rectangle in UI coordinates
    /// - Parameters:
    ///   - component: The component to calculate rectangle for
    ///   - within: The bounds to position the component within
    /// - Returns: Component rectangle in UI coordinates
    static func componentRect(_ component: InvoiceComponent, within bounds: CGRect) -> CGRect {
        return CGRect(
            x: bounds.minX + component.position.x - component.size.width / 2,
            y: bounds.minY + component.position.y - component.size.height / 2,
            width: component.size.width,
            height: component.size.height
        )
    }
    
    /// Calculates page boundaries in UI coordinates
    /// - Parameters:
    ///   - pageSize: The size of the page
    ///   - margins: The document margins
    /// - Returns: Page boundaries (left, right, top, bottom, centerX, centerY)
    static func pageBoundaries(pageSize: CGSize, margins: InvoiceDocument.DocumentMargins) -> (
        left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat, centerX: CGFloat, centerY: CGFloat
    ) {
        let left = margins.left
        let right = pageSize.width - margins.right
        let top = margins.top
        let bottom = pageSize.height - margins.bottom
        let centerX = (left + right) / 2
        let centerY = (top + bottom) / 2
        
        return (left, right, top, bottom, centerX, centerY)
    }
    
    /// Calculates margin boundaries (outer page edges) in UI coordinates
    /// - Parameters:
    ///   - pageSize: The size of the page
    /// - Returns: Margin boundaries (left, right, top, bottom, centerX, centerY)
    static func marginBoundaries(pageSize: CGSize) -> (
        left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat, centerX: CGFloat, centerY: CGFloat
    ) {
        let left: CGFloat = 0
        let right = pageSize.width
        let top: CGFloat = 0
        let bottom = pageSize.height
        let centerX = (left + right) / 2
        let centerY = (top + bottom) / 2
        
        return (left, right, top, bottom, centerX, centerY)
    }
}
