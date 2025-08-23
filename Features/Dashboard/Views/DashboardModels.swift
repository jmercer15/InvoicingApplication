//
//  DashboardModels.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import Foundation

public enum PerformanceFormat: CaseIterable {
    case percentage
    case currency
    case number
}

// MARK: - Dashboard Data Models

struct DashboardMetrics {
    let totalRevenue: String
    let monthlyRevenue: String
    let monthlyRevenueTrend: Double
    let collectionRate: Double
    let collectionRateTrend: Double
    let clientGrowthTrend: Double
    let avgInvoiceValueTrend: Double
    let outstandingAmount: String
    let outstandingInvoices: Int
    let overdueAmount: String
    let overdueInvoices: Int
    let paidThisMonth: String
    let paidInvoicesThisMonth: Int
    let activeClients: Int
    let averageInvoiceValue: String
    let sessionCompletionRate: Double
    let calculatedAt: Date
}

struct DashboardActivity: Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let date: Date
    let icon: String
    let color: Color
}

struct UrgentItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let dueDate: Date
    let priority: Priority
    
    enum Priority {
        case low
        case medium
        case high
        
        var color: Color {
            switch self {
            case .low:
                return Color.yellow
            case .medium:
                return Color.orange
            case .high:
                return Color.red
            }
        }
    }
}

// MARK: - Chart Data Models

struct ChartData {
    let label: String
    let value: Double
}

struct PaymentStatusData {
    let status: String
    let count: Int
    let color: Color
}

struct SessionCompletionData {
    let status: String
    let count: Int
    let color: Color
}

struct ClientActivityData {
    let month: String
    let count: Int
}

struct PaymentTimelineData {
    let id: UUID
    let clientName: String
    let amount: String
    let dueDate: Date
    let status: String
}