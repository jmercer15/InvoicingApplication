import Foundation
import SwiftUI
import UniformTypeIdentifiers

public struct SessionDragPayload: Codable, Transferable {
    public let sessionID: String
    public let originalInstanceDate: Date
    public let duration: TimeInterval
    
    public init(sessionID: String, originalInstanceDate: Date, duration: TimeInterval) {
        self.sessionID = sessionID
        self.originalInstanceDate = originalInstanceDate
        self.duration = duration
    }
    
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .calendarSessionDragType)
    }
}

public extension UTType {
    static let calendarSessionDragType = UTType(exportedAs: "com.jesse.InvoicingApplication.calendar-session-drag-type")
}
