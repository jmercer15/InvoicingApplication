//
//  KanbanModels.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import Foundation
import SwiftUI

// Priority enum for NDIS billing workflow
enum Priority: String, CaseIterable, Identifiable {
    case low, medium, high
    
    var id: String { rawValue }
}

// Enhanced data model for NDIS billing workflow cards

// Data model for session-specific Kanban cards
struct SessionKanbanCardData: Identifiable, Equatable {
    var id: UUID { sessionId }
    let sessionId: UUID
    let title: String
    let clientName: String
    let serviceName: String
    let travelRate: Double?
    let travelRateUnit: String?
    let suggestedTravelDistanceKM: Double?
    let suggestedTravelTimeMinutes: Double?
    let priority: Priority
    let accentColor: Color
    let duration: String
    let date: String
    let hasIssues: Bool
    let workflowStatus: KanbanCardData.WorkflowStatus
    let columnType: KanbanCardData.BillingColumnType
    let startTime: Date?
    let endTime: Date?
    let groupID: UUID?

    static func == (lhs: SessionKanbanCardData, rhs: SessionKanbanCardData) -> Bool {
        lhs.id == rhs.id
    }
}

// Data model for invoice-specific Kanban cards
struct InvoiceKanbanCardData: Identifiable, Equatable {
    var id: UUID { invoiceId }
    let invoiceId: UUID
    let title: String
    let clientName: String
    let serviceName: String
    let priority: Priority
    let accentColor: Color
    let amount: String
    let date: String
    let workflowStatus: KanbanCardData.WorkflowStatus
    let columnType: KanbanCardData.BillingColumnType
    let isOverdue: Bool
    let daysOverdue: Int?
    let rawDate: Date?

    static func == (lhs: InvoiceKanbanCardData, rhs: InvoiceKanbanCardData) -> Bool {
        lhs.id == rhs.id
    }
}

enum KanbanCardData: Identifiable, Equatable {
    case session(SessionKanbanCardData)
    case invoice(InvoiceKanbanCardData)

    var id: UUID {
        switch self {
        case .session(let data): return data.id
        case .invoice(let data): return data.id
        }
    }

    var columnType: BillingColumnType {
        switch self {
        case .session(let data): return data.columnType
        case .invoice(let data): return data.columnType
        }
    }

    var currentWorkflowStatus: WorkflowStatus {
        switch self {
        case .session(let data): return data.workflowStatus
        case .invoice(let data): return data.workflowStatus
        }
    }

    enum WorkflowStatus: String, CaseIterable, Identifiable {
        case completed, grouped, readyToInvoice, draftReview, readyToSend, pendingPayment, paymentReceived
        
        var id: String { rawValue }
    }

    enum BillingColumnType: String, CaseIterable, Identifiable, Codable {
        case completed, grouped, addTravel, reviewDrafts, readyToSend, pending, received
        
        var id: String { rawValue }
    }

    static func == (lhs: KanbanCardData, rhs: KanbanCardData) -> Bool {
        lhs.id == rhs.id
    }

    /// Factory method for creating preview/test data only. Real data flows through BillingHubViewModel.
    /// - Note: This method is used exclusively by SwiftUI previews and unit tests.
    static func createSample(for column: BillingColumnType, index: Int) -> KanbanCardData {
        let clients = ["Sarah Johnson", "David Thompson", "Lisa Rodriguez", "James Anderson", "Emma Wilson"]
        let services = ["Personal Care", "Household Tasks", "Transport Support", "Community Access", "NDIS Plan Management"]
        let dates = ["Dec 15", "Dec 14", "Dec 13", "Dec 12", "Dec 11"]
        let durations = ["2.0h", "3.5h", "1.5h", "4.0h", "2.5h"]

        let client = clients[index % clients.count]
        let service = services[index % services.count]
        let date = dates[index % dates.count]
        let duration = durations[index % durations.count]

        let hasIssues = index % 4 == 0 // Every 4th item has issues
        let priority: Priority = hasIssues ? Priority.high : (index % 3 == 1 ? Priority.medium : Priority.low)
        
        // For sample data, we can just return a session type for now.
        // We can add invoice sample data later if needed.
        let sampleSessionData = SessionKanbanCardData(
            sessionId: UUID(),
            title: service,
            clientName: client,
            serviceName: service,
            travelRate: nil,
            travelRateUnit: nil,
            suggestedTravelDistanceKM: nil,
            suggestedTravelTimeMinutes: nil,
            priority: priority,
            accentColor: columnAccentColor(for: column),
            duration: duration,
            date: date,
            hasIssues: hasIssues,
            workflowStatus: workflowStatus(for: column),
            columnType: column,
            startTime: nil,
            endTime: nil,
            groupID: nil
        )
        return .session(sampleSessionData)
    }

    static func columnAccentColor(for column: BillingColumnType) -> Color {
        switch column {
        case .completed, .grouped:
            return BillingHubTheme.Columns.preparing
        case .addTravel, .reviewDrafts, .readyToSend:
            return BillingHubTheme.Columns.processing
        case .pending, .received:
            return BillingHubTheme.Columns.payment
        }
    }

    static func workflowStatus(for column: BillingColumnType) -> WorkflowStatus {
        switch column {
        case .completed: return .completed
        case .grouped: return .grouped
        case .addTravel: return .readyToInvoice
        case .reviewDrafts: return .draftReview
        case .readyToSend: return .readyToSend
        case .pending: return .pendingPayment
        case .received: return .paymentReceived
        }
    }
}
