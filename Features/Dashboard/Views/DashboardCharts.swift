//
//  DashboardCharts.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import Charts


// MARK: - Chart Components

struct RevenueChart: View {
    let period: String
    let invoices: [InvoiceEntity]
    
    var body: some View {
        Chart {
            ForEach(generateChartData(), id: \.label) { item in
                BarMark(
                    x: .value("Period", item.label),
                    y: .value("Revenue", item.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
            }
        }
        .chartYAxis {
            AxisMarks(preset: .automatic) { value in
                AxisGridLine()
                    .foregroundStyle(.white.opacity(0.2))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formattedCurrency(doubleValue))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    Text(value.as(String.self) ?? "")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Liquid glass overlay with subtle animation
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.overlay)
                
                // Enhanced border with liquid effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.4),
                                Color.blue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
                
                // Liquid glass shadow with depth
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .shadow(
                        color: Color.black.opacity(0.3),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            }
        )
        .cornerRadius(8)
        .padding(.vertical, 8)
    }
    
    private func generateChartData() -> [ChartData] {
        let calendar = Calendar.current
        let now = Date()
        var chartData: [ChartData] = []
        
        // Pre-filter paid invoices once for efficiency
        let paidInvoices = invoices.filter { $0.status?.lowercased() == "paid" }
        
        switch period {
        case "This Week":
            // Generate data for each day of the week
            chartData.reserveCapacity(7)
            for dayOffset in (0...6).reversed() {
                let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
                let dayRevenue = paidInvoices
                    .filter { invoice in
                        let issueDate = invoice.issueDate
                        return calendar.isDate(issueDate, inSameDayAs: date)
                    }
                    .reduce(0.0) { $0 + $1.totalAmount }
                
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEE"
                let label = dayFormatter.string(from: date)
                
                chartData.append(ChartData(label: label, value: dayRevenue))
            }
            
        case "This Year":
            // Generate data for each month of the year
            chartData.reserveCapacity(12)
            for monthOffset in (0...11).reversed() {
                let date = calendar.date(byAdding: .month, value: -monthOffset, to: now) ?? now
                let monthRevenue = paidInvoices
                    .filter { invoice in
                        let issueDate = invoice.issueDate
                        return calendar.isDate(issueDate, equalTo: date, toGranularity: .month)
                    }
                    .reduce(0.0) { $0 + $1.totalAmount }
                
                let monthFormatter = DateFormatter()
                monthFormatter.dateFormat = "MMM"
                let label = monthFormatter.string(from: date)
                
                chartData.append(ChartData(label: label, value: monthRevenue))
            }
            
        case "This Quarter":
            // Generate data for each month of the quarter
            chartData.reserveCapacity(3)
            for monthOffset in (0...2).reversed() {
                let date = calendar.date(byAdding: .month, value: -monthOffset, to: now) ?? now
                let monthRevenue = paidInvoices
                    .filter { invoice in
                        let issueDate = invoice.issueDate
                        return calendar.isDate(issueDate, equalTo: date, toGranularity: .month)
                    }
                    .reduce(0.0) { $0 + $1.totalAmount }
                
                let monthFormatter = DateFormatter()
                monthFormatter.dateFormat = "MMM"
                let label = monthFormatter.string(from: date)
                
                chartData.append(ChartData(label: label, value: monthRevenue))
            }
            
        default: // "This Month"
            // Generate data for each week of the month
            chartData.reserveCapacity(4)
            for weekOffset in (0...3).reversed() {
                let weekStart = calendar.date(byAdding: .weekOfMonth, value: -weekOffset, to: now) ?? now
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
                
                let weekRevenue = paidInvoices
                    .filter { invoice in
                        let issueDate = invoice.issueDate
                        return issueDate >= weekStart && issueDate < weekEnd
                    }
                    .reduce(0.0) { $0 + $1.totalAmount }
                
                let weekFormatter = DateFormatter()
                weekFormatter.dateFormat = "MMM d"
                let label = weekFormatter.string(from: weekStart)
                
                chartData.append(ChartData(label: label, value: weekRevenue))
            }
        }
        
        return chartData
    }
    
    private func formattedCurrency(_ value: Double) -> String {
        if value >= 1000000 {
            return "$\(Int(value / 1000000))M"
        } else if value >= 1000 {
            return "$\(Int(value / 1000))k"
        }
        return "$\(Int(value))"
    }
}

struct PaymentStatusChart: View {
    let invoices: [InvoiceEntity]
    
    var body: some View {
        Chart {
            ForEach(paymentStatusData, id: \.status) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(item.color)
                .opacity(0.8)
            }
        }
        .chartBackground { _ in
            VStack {
                Text("Total")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(invoices.count)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .chartLegend(.hidden)
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Liquid glass overlay with subtle animation
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.overlay)
                
                // Enhanced border with liquid effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.4),
                                Color.green.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
                
                // Liquid glass shadow with depth
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .shadow(
                        color: Color.black.opacity(0.3),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            }
        )
        .cornerRadius(8)
    }
    
    private var paymentStatusData: [PaymentStatusData] {
        let paid = invoices.filter { $0.status?.lowercased() == "paid" }.count
        let outstanding = invoices.filter { $0.status?.lowercased() == "outstanding" }.count
        let overdue = invoices.filter { $0.status?.lowercased() == "overdue" }.count
        let draft = invoices.filter { $0.status?.lowercased() == "draft" }.count
        
        return [
            PaymentStatusData(status: "Paid", count: paid, color: .green),
            PaymentStatusData(status: "Outstanding", count: outstanding, color: .orange),
            PaymentStatusData(status: "Overdue", count: overdue, color: .red),
            PaymentStatusData(status: "Draft", count: draft, color: .blue)
        ].filter { $0.count > 0 }
    }
}

struct SessionCompletionChart: View {
    let sessions: [SessionEntity]
    
    var body: some View {
        Chart {
            ForEach(completionData, id: \.status) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(item.color)
                .opacity(0.8)
            }
        }
        .chartBackground { _ in
            VStack {
                Text("Rate")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(Int(completionRate * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .chartLegend(.hidden)
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Liquid glass overlay with subtle animation
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.overlay)
                
                // Enhanced border with liquid effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.4),
                                Color.blue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
                
                // Liquid glass shadow with depth
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .shadow(
                        color: Color.black.opacity(0.3),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            }
        )
        .cornerRadius(8)
    }
    
    private var completionData: [SessionCompletionData] {
        let completed = sessions.filter { $0.status?.lowercased() == "completed" }.count
        let total = sessions.count
        let pending = total - completed
        
        return [
            SessionCompletionData(status: "Completed", count: completed, color: .green),
            SessionCompletionData(status: "Pending", count: pending, color: .orange)
        ].filter { $0.count > 0 }
    }
    
    private var completionRate: Double {
        guard !sessions.isEmpty else { return 0 }
        let completed = sessions.filter { $0.status?.lowercased() == "completed" }.count
        return Double(completed) / Double(sessions.count)
    }
}

struct ClientActivityChart: View {
    let clients: [ClientEntity]
    
    var body: some View {
        Chart {
            ForEach(activityData, id: \.month) { item in
                BarMark(
                    x: .value("Month", item.month),
                    y: .value("Active Clients", item.count)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(4)
            }
        }
        .chartYAxis {
            AxisMarks(preset: .automatic) { _ in
                AxisGridLine()
                    .foregroundStyle(.white.opacity(0.2))
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Liquid glass overlay with subtle animation
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.overlay)
                
                // Enhanced border with liquid effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.4),
                                Color.blue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
                
                // Liquid glass shadow with depth
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .shadow(
                        color: Color.black.opacity(0.3),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            }
        )
        .cornerRadius(8)
    }
    
    private var activityData: [ClientActivityData] {
        let calendar = Calendar.current
        let now = Date()
        
        return (0..<6).compactMap { monthsBack in
            guard let monthDate = calendar.date(byAdding: .month, value: -monthsBack, to: now) else { return nil }
            
            let monthName = DateFormatter().monthSymbols[calendar.component(.month, from: monthDate) - 1]
            let shortMonth = String(monthName.prefix(3))
            
            // This is a simplified calculation - in reality you'd track actual client activity
            let count = max(1, clients.count - monthsBack * 2)
            
            return ClientActivityData(month: shortMonth, count: count)
        }.reversed()
    }
}

struct PaymentTimelineView: View {
    let invoices: [InvoiceEntity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Timeline")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(upcomingPaymentData, id: \.id) { payment in
                        PaymentTimelineCard(payment: payment)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var upcomingPaymentData: [PaymentTimelineData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return invoices
            .filter { invoice in
                guard let dueDate = invoice.dueDate,
                      invoice.status?.lowercased() != "paid" else { return false }
                return dueDate >= today
            }
            .sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
            .prefix(5)
            .map { invoice in
                PaymentTimelineData(
                    id: invoice.id,
                    clientName: invoice.clientName ?? invoice.client?.fullName ?? "Unknown",
                    amount: NumberFormatter.currency.string(from: NSNumber(value: invoice.totalAmount)) ?? "$0.00",
                    dueDate: invoice.dueDate ?? Date(),
                    status: invoice.status ?? "Unknown"
                )
            }
    }
}

struct PaymentTimelineCard: View {
    let payment: PaymentTimelineData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(payment.clientName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(payment.amount)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Text(payment.dueDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(8)
        .frame(width: 80)
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Liquid glass overlay with subtle animation
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.overlay)
                
                // Enhanced border with liquid effect
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.4),
                                Color.green.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
                
                // Liquid glass shadow with depth
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .shadow(
                        color: Color.black.opacity(0.3),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            }
        )
    }
} 