//
//  DashboardMetrics.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import Foundation
import SwiftData // Import SwiftData

// MARK: - Dashboard Metrics Calculator

class DashboardMetricsCalculator: ObservableObject {
    
    // MARK: - Performance Optimization Cache
    private var resultCache: [String: Any] = [:]
    
    // MARK: - Metrics Calculation
    func calculateMetrics(
        invoices: [InvoiceEntity], // Change from FetchedResults
        clients: [ClientEntity], // Change from FetchedResults
        upcomingSessions: [SessionEntity], // Change from FetchedResults
        completedSessions: [SessionEntity] // Change from FetchedResults
    ) -> DashboardMetrics {
        let now = Date()
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
        
        // Use structs for better performance than multiple variables
        struct MetricsAccumulator {
            var totalRev = 0.0
            var monthlyRev = 0.0
            var outstandingAmt = 0.0
            var overdueAmt = 0.0
            var paidThisMonthAmt = 0.0
            var paidCount = 0
            var outstandingCount = 0
            var overdueCount = 0
            var paidThisMonthCount = 0
            var totalInvoiceCount = 0
        }
        
        // Single pass through invoices with optimized logic
        let metrics = invoices.reduce(into: MetricsAccumulator()) { acc, invoice in
            acc.totalInvoiceCount += 1
            let amount = invoice.totalAmount
            let status = invoice.status?.lowercased()
            
            switch status {
            case "paid":
                acc.paidCount += 1
                acc.totalRev += amount
                
                if invoice.issueDate >= startOfMonth {
                    acc.monthlyRev += amount
                }
                
                if let paidDate = invoice.paidDate, paidDate >= startOfMonth {
                    acc.paidThisMonthAmt += amount
                    acc.paidThisMonthCount += 1
                } else if invoice.issueDate >= startOfMonth {
                    acc.paidThisMonthAmt += amount
                    acc.paidThisMonthCount += 1
                }
                
            case "outstanding":
                acc.outstandingCount += 1
                acc.outstandingAmt += amount
                
            default:
                if let dueDate = invoice.dueDate, dueDate < now, status != "paid" {
                    acc.overdueCount += 1
                    acc.overdueAmt += amount
                }
            }
        }
        
        // Optimize calculations
        let collectionRate = metrics.totalInvoiceCount > 0 ? Double(metrics.paidCount) / Double(metrics.totalInvoiceCount) : 0
        let avgInvoiceValue = metrics.paidCount > 0 ? metrics.totalRev / Double(metrics.paidCount) : 0
        let completionRate = calculateSessionCompletionRate(upcomingSessions: upcomingSessions, completedSessions: completedSessions)
        
        // Use cached formatters for better performance
        let currencyFormatter = NumberFormatter.currency
        
        // Calculate actual trends
        let monthlyRevenueTrend = calculateMonthlyRevenueTrend(invoices: invoices, currentMonthRevenue: metrics.monthlyRev)
        let collectionRateTrend = calculateCollectionRateTrend(invoices: invoices, currentRate: collectionRate)
        let clientGrowthTrend = calculateClientGrowthTrend(clients: clients)
        let avgInvoiceValueTrend = calculateAverageInvoiceValueTrend(invoices: invoices, currentAvg: avgInvoiceValue)
        
        return DashboardMetrics(
            totalRevenue: currencyFormatter.string(from: NSNumber(value: metrics.totalRev)) ?? "$0",
            monthlyRevenue: currencyFormatter.string(from: NSNumber(value: metrics.monthlyRev)) ?? "$0",
            monthlyRevenueTrend: monthlyRevenueTrend,
            collectionRate: collectionRate,
            collectionRateTrend: collectionRateTrend,
            clientGrowthTrend: clientGrowthTrend,
            avgInvoiceValueTrend: avgInvoiceValueTrend,
            outstandingAmount: currencyFormatter.string(from: NSNumber(value: metrics.outstandingAmt)) ?? "$0",
            outstandingInvoices: metrics.outstandingCount,
            overdueAmount: currencyFormatter.string(from: NSNumber(value: metrics.overdueAmt)) ?? "$0",
            overdueInvoices: metrics.overdueCount,
            paidThisMonth: currencyFormatter.string(from: NSNumber(value: metrics.paidThisMonthAmt)) ?? "$0",
            paidInvoicesThisMonth: metrics.paidThisMonthCount,
            activeClients: clients.count,
            averageInvoiceValue: currencyFormatter.string(from: NSNumber(value: avgInvoiceValue)) ?? "$0",
            sessionCompletionRate: completionRate,
            calculatedAt: now
        )
    }
    
    private func calculateSessionCompletionRate(
        upcomingSessions: [SessionEntity],
        completedSessions: [SessionEntity]
    ) -> Double {
        let totalSessions = upcomingSessions.count + completedSessions.count
        guard totalSessions > 0 else { return 0 }
        
        return Double(completedSessions.count) / Double(totalSessions)
    }
    
    // MARK: - Optimized Data Processing
    func generateUrgentItems(
        invoices: [InvoiceEntity],
        upcomingSessions: [SessionEntity]
    ) -> [UrgentItem] {
        var items: [UrgentItem] = []
        items.reserveCapacity(5) // Pre-allocate
        
        let now = Date()
        
        // Optimized overdue invoices processing
        let overdueInvoices = invoices.lazy
            .filter { invoice in
                guard let dueDate = invoice.dueDate else { return false }
                return dueDate < now && invoice.status?.lowercased() != "paid"
            }
            .prefix(3)
        
        for invoice in overdueInvoices {
            if let client = invoice.client, let dueDate = invoice.dueDate {
                items.append(UrgentItem(
                    title: "Overdue Invoice",
                    subtitle: "Invoice for \(client.fullName)",
                    dueDate: dueDate,
                    priority: UrgentItem.Priority.high
                ))
            }
        }
        
        // Optimized today's sessions processing
        let todayStart = Calendar.current.startOfDay(for: now)
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? now
        
        let todayUrgentSessions = upcomingSessions.lazy
            .filter { session in
                guard let startTime = session.startTime else { return false }
                return startTime >= todayStart && startTime < todayEnd
            }
            .prefix(2)
        
        for session in todayUrgentSessions {
            if let client = session.client, let startTime = session.startTime {
                items.append(UrgentItem(
                    title: "Today's Session",
                    subtitle: "Session with \(client.fullName)",
                    dueDate: startTime,
                    priority: UrgentItem.Priority.medium
                ))
            }
        }
        
        return items.sorted { $0.dueDate < $1.dueDate }
    }
    
    func generateRecentActivities(
        invoices: [InvoiceEntity],
        upcomingSessions: [SessionEntity]
    ) -> [DashboardActivity] {
        var activities: [DashboardActivity] = []
        
        // Optimized: Use lazy evaluation and limit processing
        let recentPayments = invoices.lazy
            .filter { $0.status?.lowercased() == "paid" }
            .sorted { 
                let date0 = $0.paidDate ?? $0.issueDate
                let date1 = $1.paidDate ?? $1.issueDate
                return date0 > date1
            }
            .prefix(3)
        
        activities.reserveCapacity(5) // Pre-allocate capacity
        
        for payment in recentPayments {
            activities.append(DashboardActivity(
                id: payment.id, // Use SwiftData UUID
                title: "Payment Received",
                description: "From \(payment.client?.fullName ?? "Unknown Client")",
                date: payment.paidDate ?? payment.issueDate,
                icon: "dollarsign.circle.fill",
                color: .green
            ))
        }
        
        // Optimized session processing
        let recentSessions = upcomingSessions.lazy
            .filter { $0.status?.lowercased() == "completed" }
            .sorted { ($0.startTime ?? Date.distantPast) > ($1.startTime ?? Date.distantPast) }
            .prefix(2)
        
        for session in recentSessions {
            activities.append(DashboardActivity(
                id: session.id, // Use SwiftData UUID
                title: "Session Completed",
                description: "With \(session.client?.fullName ?? "Unknown Client")",
                date: session.startTime ?? Date(),
                icon: "checkmark.circle.fill",
                color: .blue
            ))
        }
        
        return activities.sorted { $0.date > $1.date }
    }
    
    func getFilteredInvoices(
        invoices: [InvoiceEntity],
        selectedPeriod: String
    ) -> [InvoiceEntity] {
        let calendar = Calendar.current
        let now = Date()
        
        return invoices.filter { invoice in
            let issueDate = invoice.issueDate
            
            switch selectedPeriod {
            case "This Week":
                return calendar.isDate(issueDate, equalTo: now, toGranularity: .weekOfYear)
            case "This Quarter":
                let quarterStart = calendar.dateInterval(of: .quarter, for: now)?.start ?? now
                return issueDate >= quarterStart
            case "This Year":
                return calendar.isDate(issueDate, equalTo: now, toGranularity: .year)
            default: // "This Month"
                return calendar.isDate(issueDate, equalTo: now, toGranularity: .month)
            }
        }
    }
    
    func getTodaySessions(upcomingSessions: [SessionEntity]) -> [SessionEntity] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return upcomingSessions.filter { session in
            guard let startTime = session.startTime else { return false }
            return startTime >= today && startTime < tomorrow
        }
    }
    
    func getThisWeekSessions(upcomingSessions: [SessionEntity]) -> [SessionEntity] {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? Date()
        
        return upcomingSessions.filter { session in
            guard let startTime = session.startTime else { return false }
            return startTime >= weekStart && startTime < weekEnd
        }
    }
    
    // MARK: - Cache Management
    func getCachedResult(key: String) -> Any? {
        return resultCache[key]
    }
    
    func setCachedResult(key: String, value: Any) {
        resultCache[key] = value
    }
    
    func clearCache() {
        resultCache.removeAll()
    }
    

    
    // MARK: - Trend Calculations
    
    private func calculateMonthlyRevenueTrend(invoices: [InvoiceEntity], currentMonthRevenue: Double) -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current month start
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else { return 0 }
        
        // Get previous month start
        guard let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) else { return 0 }
        
        // Calculate previous month revenue
        let previousMonthRevenue = invoices
            .filter { invoice in
                guard let paidDate = invoice.paidDate else { return false }
                return paidDate >= previousMonthStart && paidDate < currentMonthStart
            }
            .reduce(0.0) { $0 + $1.totalAmount }
        
        // Calculate trend percentage
        guard previousMonthRevenue > 0 else { return 0 }
        return ((currentMonthRevenue - previousMonthRevenue) / previousMonthRevenue) * 100
    }
    
    private func calculateCollectionRateTrend(invoices: [InvoiceEntity], currentRate: Double) -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current month start
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else { return 0 }
        
        // Get previous month start
        guard let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) else { return 0 }
        
        // Get invoices from previous month
        let previousMonthInvoices = invoices.filter { invoice in
            let issueDate = invoice.issueDate
            return issueDate >= previousMonthStart && issueDate < currentMonthStart
        }
        
        // Calculate previous month collection rate
        let previousMonthPaid = previousMonthInvoices.filter { $0.status?.lowercased() == "paid" }.count
        let previousMonthTotal = previousMonthInvoices.count
        
        guard previousMonthTotal > 0 else { return 0 }
        let previousRate = Double(previousMonthPaid) / Double(previousMonthTotal)
        
        // Calculate trend percentage
        return ((currentRate - previousRate) / previousRate) * 100
    }
    
    private func calculateClientGrowthTrend(clients: [ClientEntity]) -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current month start
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else { return 0 }
        
        // Get previous month start
        guard let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) else { return 0 }
        
        // Count clients with invoices in current month (using first invoice date as proxy)
        let currentMonthClients = clients.filter { client in
            // Use the earliest invoice date as a proxy for client activity
            let earliestInvoiceDate = client.invoices?.compactMap { $0.issueDate }.min() ?? now
            return earliestInvoiceDate >= currentMonthStart
        }.count
        
        // Count clients with invoices in previous month
        let previousMonthClients = clients.filter { client in
            let earliestInvoiceDate = client.invoices?.compactMap { $0.issueDate }.min() ?? now
            return earliestInvoiceDate >= previousMonthStart && earliestInvoiceDate < currentMonthStart
        }.count
        
        // Calculate growth percentage
        guard previousMonthClients > 0 else { return 0 }
        return Double(currentMonthClients - previousMonthClients) / Double(previousMonthClients) * 100
    }
    
    private func calculateAverageInvoiceValueTrend(invoices: [InvoiceEntity], currentAvg: Double) -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current month start
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else { return 0 }
        
        // Get previous month start
        guard let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) else { return 0 }
        
        // Calculate previous month average invoice value
        let previousMonthInvoices = invoices.filter { invoice in
            let issueDate = invoice.issueDate
            return issueDate >= previousMonthStart && issueDate < currentMonthStart
        }
        
        let previousMonthRevenue = previousMonthInvoices.reduce(0.0) { $0 + $1.totalAmount }
        let previousMonthCount = previousMonthInvoices.count
        
        guard previousMonthCount > 0 else { return 0 }
        let previousAvg = previousMonthRevenue / Double(previousMonthCount)
        
        // Calculate trend percentage
        guard previousAvg > 0 else { return 0 }
        return ((currentAvg - previousAvg) / previousAvg) * 100
    }
} 