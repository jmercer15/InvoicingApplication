//
//  BillingStatus.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import Foundation

/// Represents the billing status of a session or invoice in the billing workflow
enum BillingStatus: String, CaseIterable, Identifiable {
    case completed = "completed"
    case grouped = "grouped"
    case assignServices = "assignServices"
    case addTravel = "addTravel"
    case reviewDrafts = "reviewDrafts"
    case readyToSend = "readyToSend"
    case pending = "pending"
    case received = "received"
    
    var id: String { rawValue }
    
    /// The display name for the status
    var displayName: String {
        switch self {
        case .completed:
            return "Completed"
        case .grouped:
            return "Grouped"
        case .assignServices:
            return "Assign Services"
        case .addTravel:
            return "Add Travel"
        case .reviewDrafts:
            return "Review Drafts"
        case .readyToSend:
            return "Ready to Send"
        case .pending:
            return "Pending"
        case .received:
            return "Received"
        }
    }
    
    /// The system icon name for the status
    var iconName: String {
        switch self {
        case .completed:
            return "calendar.badge.checkmark"
        case .grouped:
            return "rectangle.on.rectangle.badge.gearshape"
        case .assignServices:
            return "questionmark.text.page.fill"
        case .addTravel:
            return "car.fill"
        case .reviewDrafts:
            return "doc.text.magnifyingglass"
        case .readyToSend:
            return "square.and.arrow.up.badge.clock"
        case .pending:
            return "clock.fill"
        case .received:
            return "checkmark.circle.fill"
        }
    }
    
    /// The column this status belongs to
    var column: BillingColumn {
        switch self {
        case .completed, .grouped:
            return .preparing
        case .assignServices, .addTravel, .reviewDrafts, .readyToSend:
            return .processing
        case .pending, .received:
            return .payment
        }
    }
    
    /// The color associated with this status
    var color: String {
        switch self {
        case .completed, .received:
            return "Green"
        case .grouped, .readyToSend:
            return "Blue"
        case .assignServices, .addTravel:
            return "Orange"
        case .reviewDrafts:
            return "Yellow"
        case .pending:
            return "Red"
        }
    }
}

/// Represents the three main columns in the billing workflow
enum BillingColumn: String, CaseIterable, Identifiable {
    case preparing = "preparing"
    case processing = "processing"
    case payment = "payment"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .preparing:
            return "Preparing Sessions"
        case .processing:
            return "Processing"
        case .payment:
            return "Payment"
        }
    }
    
    var widthPercentage: Double {
        switch self {
        case .preparing:
            return 0.25
        case .processing:
            return 0.50
        case .payment:
            return 0.25
        }
    }
    
    var statuses: [BillingStatus] {
        switch self {
        case .preparing:
            return [.completed, .grouped]
        case .processing:
            return [.assignServices, .addTravel, .reviewDrafts, .readyToSend]
        case .payment:
            return [.pending, .received]
        }
    }
}
