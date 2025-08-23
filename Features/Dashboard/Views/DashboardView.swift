//
//  DashboardViewRefactored.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import Charts
import SwiftData // Import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @ObservedObject var containerViewModel: DashboardContainerViewModel
    
    private static let todayStart = Calendar.current.startOfDay(for: Date())
    private static let draftStatus = AppConstants.invoiceStatusDraft
    
    // Adaptive padding based on screen size
    private var adaptivePadding: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        if screenWidth > 1400 {
            return 40
        } else if screenWidth > 1000 {
            return 32
        } else {
            return 24
        }
    }
    
    // Adaptive grid layout columns based on screen size with equal heights
    private var gridColumns: [GridItem] {
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        if screenWidth > 1400 {
            // Large screens: 3 columns
            return [
                GridItem(.flexible(minimum: 100), spacing: 20),
                GridItem(.flexible(minimum: 100), spacing: 20),
                GridItem(.flexible(minimum: 100), spacing: 20)
            ]
        } else if screenWidth > 1000 {
            // Medium screens: 2 columns
            return [
                GridItem(.flexible(minimum: 100), spacing: 24),
                GridItem(.flexible(minimum: 100), spacing: 24)
            ]
        } else {
            // Small screens: 1 column
            return [GridItem(.flexible(minimum: 100))]
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Solid black background per design
                Color.black
                    .ignoresSafeArea()
                
                // Main content
                if containerViewModel.hasError {
                    errorView
                } else if containerViewModel.isLoading && containerViewModel.cachedMetrics == nil {
                    loadingView
                } else {
                    mainContentView
                }
            }
        }
        .onAppear {
            containerViewModel.loadDashboardData()
        }
        .onChange(of: containerViewModel.selectedPeriod) {
            containerViewModel.onDataChange()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $containerViewModel.selectedPeriod) {
                    ForEach(containerViewModel.periodOptions, id: \.self) { period in
                        Text(period).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .help("Select reporting period")
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                Button(action: { containerViewModel.showingQuickActions.toggle() }) { Label("Quick Actions", systemImage: "bolt") }
                .appInteractiveCursor()
                .help("Open quick actions menu")
                Button(action: { containerViewModel.refreshDashboard() }) { Label(containerViewModel.isRefreshing ? "Refreshing..." : "Refresh", systemImage: containerViewModel.isRefreshing ? "hourglass" : "arrow.clockwise") }
                .disabled(containerViewModel.isRefreshing)
                .appInteractiveCursor()
                .help("Reload dashboard data")
                Button(action: { containerViewModel.exportDashboardData() }) { Label("Export Report", systemImage: "square.and.arrow.up") }
                .appInteractiveCursor()
                .help("Export dashboard data")
            }
        }
        
    }
    
    // MARK: - Error View
    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Dashboard Error")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if let errorMessage = containerViewModel.errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if let lastError = containerViewModel.lastError,
               let recoverySuggestion = lastError.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            HStack(spacing: 16) {
                Button("Retry") {
                    containerViewModel.retryOperation()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                
                Button("Dismiss") {
                    containerViewModel.dismissError()
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Skeleton for Key Metrics
                skeletonKeyMetricsSection
                
                // Skeleton for Main Content
                ViewThatFits {
                    // Primary layout: 3x2 grid skeleton
                    VStack(spacing: 16) {
                        // Row 1: 3 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                skeletonAnalyticsChartsGrid
                                    .frame(maxWidth: .infinity)
                                skeletonFinancialOverviewGrid
                                    .frame(maxWidth: .infinity)
                                skeletonSessionsAndClientGrid
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Row 2: 3 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                skeletonRecentActivityGrid
                                    .frame(maxWidth: .infinity)
                                skeletonPerformanceInsightsGrid
                                    .frame(maxWidth: .infinity)
                                skeletonUpcomingDeadlinesGrid
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    
                    // Fallback layout: 2x3 grid skeleton
                    VStack(spacing: 16) {
                        // Row 1: 2 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                skeletonAnalyticsChartsGrid
                                    .frame(maxWidth: .infinity)
                                skeletonFinancialOverviewGrid
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Row 2: 2 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                skeletonSessionsAndClientGrid
                                    .frame(maxWidth: .infinity)
                                skeletonRecentActivityGrid
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Row 3: 2 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                skeletonPerformanceInsightsGrid
                                    .frame(maxWidth: .infinity)
                                skeletonUpcomingDeadlinesGrid
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, adaptivePadding)
            .padding(.vertical, 20)
        }
        .transition(.opacity)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Key Metrics - Always full width for importance
                enhancedKeyMetricsSection
                    .opacity(containerViewModel.isLoading ? 0 : 1)
                    .offset(y: containerViewModel.isLoading ? -10 : 0)
                    .animation(.easeInOut(duration: 0.8).delay(0.2), value: containerViewModel.isLoading)
                
                // Main content with ViewThatFits for adaptive layout
                ViewThatFits {
                    // Primary layout: 3x2 grid (3 columns, 2 rows)
                    VStack(spacing: 16) {
                        // Row 1: 3 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                analyticsChartsGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.3)
                                financialOverviewGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.4)
                                sessionsAndClientGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.5)
                            }
                        }
                        
                        // Row 2: 3 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                recentActivityGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.6)
                                performanceInsightsGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.7)
                                upcomingDeadlinesGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.8)
                            }
                        }
                    }
                    
                    // Fallback layout: 2x3 grid (2 columns, 3 rows)
                    VStack(spacing: 16) {
                        // Row 1: 2 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                analyticsChartsGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.3)
                                financialOverviewGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.4)
                            }
                        }
                        
                        // Row 2: 2 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                sessionsAndClientGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.5)
                                recentActivityGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.6)
                            }
                        }
                        
                        // Row 3: 2 columns
                        dashboardRow {
                            HStack(spacing: 16) {
                                performanceInsightsGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.7)
                                upcomingDeadlinesGrid
                                    .frame(maxWidth: .infinity)
                                    .loadingState(containerViewModel.isLoading, delay: 0.8)
                            }
                        }
                    }
                    
                    // Final fallback: 1x6 grid (1 column, 6 rows)
                    VStack(spacing: 16) {
                        dashboardRow { 
                            analyticsChartsGrid
                                .loadingState(containerViewModel.isLoading, delay: 0.3)
                        }
                        dashboardRow { 
                            financialOverviewGrid
                                .loadingState(containerViewModel.isLoading, delay: 0.4)
                        }
                        dashboardRow { 
                            sessionsAndClientGrid
                                .loadingState(containerViewModel.isLoading, delay: 0.5)
                        }
                        dashboardRow { 
                            recentActivityGrid
                                .loadingState(containerViewModel.isLoading, delay: 0.6)
                        }
                        dashboardRow { 
                            performanceInsightsGrid
                                .loadingState(containerViewModel.isLoading, delay: 0.7)
                        }
                        dashboardRow { 
                            upcomingDeadlinesGrid
                                .loadingState(containerViewModel.isLoading, delay: 0.8)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .opacity(containerViewModel.isLoading ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: containerViewModel.isLoading)
        .overlay(
            // Refresh indicator
            Group {
                if containerViewModel.isRefreshing {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Refreshing...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            Spacer()
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        )
        .refreshable {
            await containerViewModel.refreshDashboardAsync()
        }

    }
}

// MARK: - Header and Sections

extension DashboardView {
    // MARK: - Header View removed (system toolbar used)
    private var headerView: some View { EmptyView() }
    

    
    // MARK: - Enhanced Key Metrics Section
    private var enhancedKeyMetricsSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                HStack {
                    Text("Key Metrics")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(containerViewModel.selectedPeriod)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                
                ViewThatFits {
                    // 4x1 Layout (Horizontal)
                    HStack(spacing: 20) {
                        // Total Revenue Card
                        NavigableDashboardMetricCard(
                            metric: .totalRevenue,
                            title: "Total Revenue",
                            value: currentMetrics.totalRevenue,
                            trend: currentMetrics.monthlyRevenueTrend,
                            icon: "dollarsign.circle.fill",
                            color: Color.white,
                            subtitle: "vs last month",
                            isHovered: containerViewModel.hoveredCard == "revenue",
                            additionalData: ["period": containerViewModel.selectedPeriod]
                        ) {
                            containerViewModel.hoveredCard = containerViewModel.hoveredCard == "revenue" ? nil : "revenue"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .appInteractiveCursor()
                        
                        // Collection Rate Card
                        NavigableDashboardMetricCard(
                            metric: .paidInvoices,
                            title: "Collection Rate",
                            value: String(format: "%.1f%%", currentMetrics.collectionRate * 100),
                            trend: currentMetrics.collectionRateTrend,
                            icon: "percent",
                            color: Color.white,
                            subtitle: "payment efficiency",
                            isHovered: containerViewModel.hoveredCard == "collection",
                            additionalData: ["filterType": "paid", "period": containerViewModel.selectedPeriod]
                        ) {
                            containerViewModel.hoveredCard = containerViewModel.hoveredCard == "collection" ? nil : "collection"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .appInteractiveCursor()
                        
                        // Active Clients Card
                        NavigableDashboardMetricCard(
                            metric: .activeClients,
                            title: "Active Clients",
                            value: "\(currentMetrics.activeClients)",
                            trend: currentMetrics.clientGrowthTrend,
                            icon: "person.3.fill",
                            color: Color.white,
                            subtitle: "total clients",
                            isHovered: containerViewModel.hoveredCard == "clients",
                            additionalData: ["filterType": "active"]
                        ) {
                            containerViewModel.hoveredCard = containerViewModel.hoveredCard == "clients" ? nil : "clients"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .appInteractiveCursor()
                        
                        // Average Invoice Value Card
                        NavigableDashboardMetricCard(
                            metric: .totalRevenue,
                            title: "Avg Invoice Value",
                            value: currentMetrics.averageInvoiceValue,
                            trend: currentMetrics.avgInvoiceValueTrend,
                            icon: "chart.bar.fill",
                            color: Color.white,
                            subtitle: "per invoice",
                            isHovered: containerViewModel.hoveredCard == "average",
                            additionalData: ["filterType": "averageValue", "period": containerViewModel.selectedPeriod]
                        ) {
                            containerViewModel.hoveredCard = containerViewModel.hoveredCard == "average" ? nil : "average"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .appInteractiveCursor()
                    }
                    
                    // 2x2 Layout (Grid)
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        // Total Revenue Card
                        NavigableDashboardMetricCard(
                            metric: .totalRevenue,
                            title: "Total Revenue",
                            value: currentMetrics.totalRevenue,
                            trend: currentMetrics.monthlyRevenueTrend,
                            icon: "dollarsign.circle.fill",
                            color: Color.white,
                            subtitle: "vs last month",
                            isHovered: containerViewModel.hoveredCard == "revenue",
                            additionalData: ["period": containerViewModel.selectedPeriod]
                        ) {
                            containerViewModel.hoveredCard = containerViewModel.hoveredCard == "revenue" ? nil : "revenue"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .appInteractiveCursor()
                        
                        // Collection Rate Card
                        NavigableDashboardMetricCard(
                            metric: .paidInvoices,
                            title: "Collection Rate",
                            value: String(format: "%.1f%%", currentMetrics.collectionRate * 100),
                            trend: currentMetrics.collectionRateTrend,
                            icon: "percent",
                            color: Color.white,
                            subtitle: "payment efficiency",
                            isHovered: containerViewModel.hoveredCard == "collection",
                            additionalData: ["filterType": "paid", "period": containerViewModel.selectedPeriod]
                        ) {
                            containerViewModel.hoveredCard = containerViewModel.hoveredCard == "collection" ? nil : "collection"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .appInteractiveCursor()
                        
                        // Active Clients Card
                        NavigableDashboardMetricCard(
                            metric: .activeClients,
                            title: "Active Clients",
                            value: "\(currentMetrics.activeClients)",
                            trend: currentMetrics.clientGrowthTrend,
                            icon: "person.3.fill",
                            color: Color.white,
                            subtitle: "total clients",
                            isHovered: containerViewModel.hoveredCard == "clients",
                            additionalData: ["filterType": "active"]
                        ) {
                            containerViewModel.hoveredCard = containerViewModel.hoveredCard == "clients" ? nil : "clients"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .appInteractiveCursor()
                        
                        // Average Invoice Value Card
                        NavigableDashboardMetricCard(
                            metric: .totalRevenue,
                            title: "Avg Invoice Value",
                            value: currentMetrics.averageInvoiceValue,
                            trend: currentMetrics.avgInvoiceValueTrend,
                            icon: "chart.bar.fill",
                            color: Color.white,
                            subtitle: "per invoice",
                            isHovered: containerViewModel.hoveredCard == "average",
                            additionalData: ["filterType": "averageValue", "period": containerViewModel.selectedPeriod]
                        ) {
                            containerViewModel.hoveredCard = containerViewModel.hoveredCard == "average" ? nil : "average"
                        }
                        .buttonStyle(PlainButtonStyle())
                        .appInteractiveCursor()
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
    
    // MARK: - Analytics Charts Grid
    private var analyticsChartsGrid: some View {
        EnhancedDashboardSection(title: "Revenue Analytics", icon: "chart.line.uptrend.xyaxis", accentColor: .clear) {
            VStack(spacing: 16) {
                // Revenue Chart
                RevenueChart(period: containerViewModel.selectedPeriod, invoices: filteredInvoices)
                    .frame(height: 200)
                
                // Quick Stats Row
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Month")
                        .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(currentMetrics.monthlyRevenue)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Avg/Invoice")
                        .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(currentMetrics.averageInvoiceValue)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Financial Overview Grid
    private var financialOverviewGrid: some View {
        EnhancedDashboardSection(title: "Financial Overview", icon: "banknote.fill", accentColor: .clear) {
            VStack(spacing: 16) {
                    EnhancedFinancialSummaryRow(
                        title: "Outstanding", 
                        amount: currentMetrics.outstandingAmount, 
                        count: currentMetrics.outstandingInvoices,
                        color: Color.yellow,
                        trend: calculateOutstandingTrend()
                    )
                    
                Divider()
                    .background(
                        ZStack {
                            // Primary glass background with liquid effect
                            RoundedRectangle(cornerRadius: 1)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            // Liquid glass overlay with subtle animation
                            RoundedRectangle(cornerRadius: 1)
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
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.15)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    )
                
                    EnhancedFinancialSummaryRow(
                        title: "Overdue", 
                        amount: currentMetrics.overdueAmount, 
                        count: currentMetrics.overdueInvoices,
                        color: Color.red,
                        trend: calculateOverdueTrend()
                    )
                    
                Divider()
                    .background(
                        ZStack {
                            // Primary glass background with liquid effect
                            RoundedRectangle(cornerRadius: 1)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            // Liquid glass overlay with subtle animation
                            RoundedRectangle(cornerRadius: 1)
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
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.15)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    )
                
                    EnhancedFinancialSummaryRow(
                        title: "Paid This Month", 
                        amount: currentMetrics.paidThisMonth, 
                        count: currentMetrics.paidInvoicesThisMonth,
                        color: Color.green,
                        trend: currentMetrics.collectionRateTrend
                    )
            }
        }
    }
    
    // MARK: - Sessions and Client Grid
    private var sessionsAndClientGrid: some View {
        EnhancedDashboardSection(title: "Sessions Overview", icon: "calendar.circle.fill", accentColor: .clear) {
            VStack(spacing: 16) {
                // Today's Sessions
                    VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Today")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(todaySessions.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    if !todaySessions.isEmpty {
                        ForEach(todaySessions.prefix(2), id: \.id) { session in
                                EnhancedSessionRow(session: session)
                            }
                    } else {
                        Text("No sessions today")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Divider()
                    .background(
                        ZStack {
                            // Primary glass background with liquid effect
                            RoundedRectangle(cornerRadius: 1)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            // Liquid glass overlay with subtle animation
                            RoundedRectangle(cornerRadius: 1)
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
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.15)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    )
                
                // This Week's Sessions
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("This Week")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(thisWeekSessions.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Activity Grid
    private var recentActivityGrid: some View {
        EnhancedDashboardSection(title: "Recent Activity", icon: "clock.fill", accentColor: .clear) {
            VStack(spacing: 12) {
                ForEach(recentActivities.indices, id: \.self) { index in
                    let activity = recentActivities[index]
                    CompactActivityRow(activity: activity)
                    
                    if index != recentActivities.count - 1 {
                        Divider()
                            .background(
                                ZStack {
                                    // Primary glass background with liquid effect
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.15),
                                                    Color.white.opacity(0.08)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    // Liquid glass overlay with subtle animation
                                    RoundedRectangle(cornerRadius: 1)
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
                                    RoundedRectangle(cornerRadius: 1)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.15)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            )
                    }
                }
                
                if recentActivities.isEmpty {
                    EnhancedEmptyStateView(
                        icon: "clock.badge.questionmark",
                        title: "No recent activity",
                        message: "Activity will appear here",
                        color: .gray
                    )
                }
            }
        }
    }
    
    // MARK: - Performance Insights Grid
    private var performanceInsightsGrid: some View {
        EnhancedDashboardSection(title: "Performance Insights", icon: "chart.xyaxis.line", accentColor: .clear) {
            VStack(spacing: 16) {
                PerformanceIndicator(
                    title: "Session Completion",
                    value: currentMetrics.sessionCompletionRate * 100,
                    format: .percentage,
                    color: Color.green
                )
                
                TotalHoursVisualization(
                    title: "Total Hours",
                    hours: calculateTotalHours(),
                    color: Color.white
                )
            }
        }
    }
    
    // MARK: - Upcoming Deadlines Grid
    private var upcomingDeadlinesGrid: some View {
        EnhancedDashboardSection(title: "Upcoming Deadlines", icon: "exclamationmark.triangle.fill", accentColor: .clear) {
            VStack(spacing: 12) {
                ForEach(urgentItems.indices, id: \.self) { index in
                    let item = urgentItems[index]
                    UrgentItemRow(item: item)
                    
                    if index != urgentItems.count - 1 {
                        Divider()
                            .background(
                                ZStack {
                                    // Primary glass background with liquid effect
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.15),
                                                    Color.white.opacity(0.08)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    // Liquid glass overlay with subtle animation
                                    RoundedRectangle(cornerRadius: 1)
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
                                    RoundedRectangle(cornerRadius: 1)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.15)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            )
                    }
                }
                
                if urgentItems.isEmpty {
                    EnhancedEmptyStateView(
                        icon: "checkmark.circle.fill",
                        title: "All caught up!",
                        message: "No urgent items",
                        color: .green
                    )
                }
            }
        }
    }
}

// MARK: - Computed Properties and Data

extension DashboardView {
    private var currentMetrics: DashboardMetrics {
        if let cached = containerViewModel.cachedMetrics,
           Date().timeIntervalSince(cached.calculatedAt) < 30 { // Cache for 30 seconds
            return cached
        }
        
        // Return a default metrics object if no cached data
        return DashboardMetrics(
            totalRevenue: "$0",
            monthlyRevenue: "$0",
            monthlyRevenueTrend: 0.0,
            collectionRate: 0.0,
            collectionRateTrend: 0.0,
            clientGrowthTrend: 0.0,
            avgInvoiceValueTrend: 0.0,
            outstandingAmount: "$0",
            outstandingInvoices: 0,
            overdueAmount: "$0",
            overdueInvoices: 0,
            paidThisMonth: "$0",
            paidInvoicesThisMonth: 0,
            activeClients: 0,
            averageInvoiceValue: "$0",
            sessionCompletionRate: 0.0,
            calculatedAt: Date()
        )
    }
    
    private var urgentItems: [UrgentItem] {
        return containerViewModel.cachedUrgentItems
    }
    
    private var recentActivities: [DashboardActivity] {
        return containerViewModel.cachedActivities
    }
    
    private var filteredInvoices: [InvoiceEntity] {
        return containerViewModel.getFilteredInvoices(for: containerViewModel.selectedPeriod)
    }
    
    private var todaySessions: [SessionEntity] {
        return containerViewModel.getTodaySessions()
    }
    
    private var thisWeekSessions: [SessionEntity] {
        return containerViewModel.getThisWeekSessions()
    }
}

// MARK: - Helper Functions

extension DashboardView {
    @ViewBuilder
    private func dashboardRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .alignmentGuide(.top) { _ in 0 }
    }
    
    private func calculateTotalHours() -> Double {
        return containerViewModel.calculateTotalHours()
    }
    
    // MARK: - Trend Calculation Helpers
    
    private func calculateOutstandingTrend() -> Double {
        let currentInvoices = containerViewModel.getFilteredInvoices(for: containerViewModel.selectedPeriod)
        let previousPeriod = getPreviousPeriod(for: containerViewModel.selectedPeriod)
        let previousInvoices = containerViewModel.getFilteredInvoices(for: previousPeriod)
        
        let currentOutstanding = currentInvoices.filter { $0.status != "paid" }.reduce(0.0) { total, invoice in
            total + invoice.totalAmount
        }
        
        let previousOutstanding = previousInvoices.filter { $0.status != "paid" }.reduce(0.0) { total, invoice in
            total + invoice.totalAmount
        }
        
        guard previousOutstanding > 0 else { return 0.0 }
        return ((currentOutstanding - previousOutstanding) / previousOutstanding) * 100
    }
    
    private func calculateOverdueTrend() -> Double {
        let currentInvoices = containerViewModel.getFilteredInvoices(for: containerViewModel.selectedPeriod)
        let previousPeriod = getPreviousPeriod(for: containerViewModel.selectedPeriod)
        let previousInvoices = containerViewModel.getFilteredInvoices(for: previousPeriod)
        
        let now = Date()
        
        let currentOverdue = currentInvoices.filter { invoice in
            guard let dueDate = invoice.dueDate else { return false }
            return dueDate < now && invoice.status != "paid"
        }.reduce(0.0) { total, invoice in
            total + invoice.totalAmount
        }
        
        let previousOverdue = previousInvoices.filter { invoice in
            guard let dueDate = invoice.dueDate else { return false }
            return dueDate < now && invoice.status != "paid"
        }.reduce(0.0) { total, invoice in
            total + invoice.totalAmount
        }
        
        guard previousOverdue > 0 else { return 0.0 }
        return ((currentOverdue - previousOverdue) / previousOverdue) * 100
    }
    
    private func getPreviousPeriod(for period: String) -> String {
        switch period {
        case "This Week":
            return "Last Week"
        case "This Month":
            return "Last Month"
        case "This Quarter":
            return "Last Quarter"
        case "This Year":
            return "Last Year"
        default:
            return "Last Month"
        }
    }
}

// MARK: - Skeleton Loading Components

extension DashboardView {
    
    // MARK: - Skeleton Key Metrics Section
    private var skeletonKeyMetricsSection: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                skeletonText(width: 120, height: 24)
                Spacer()
                skeletonButton(width: 100, height: 32)
            }
            
            // Metrics Grid
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    skeletonMetricCard
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Skeleton Metric Card
    private var skeletonMetricCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            skeletonText(width: 80, height: 16)
            skeletonText(width: 120, height: 24)
            skeletonText(width: 60, height: 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Skeleton Grid Components
    private var skeletonAnalyticsChartsGrid: some View {
        skeletonGridCard(title: "Analytics Charts")
    }
    
    private var skeletonFinancialOverviewGrid: some View {
        skeletonGridCard(title: "Financial Overview")
    }
    
    private var skeletonSessionsAndClientGrid: some View {
        skeletonGridCard(title: "Sessions & Clients")
    }
    
    private var skeletonRecentActivityGrid: some View {
        skeletonGridCard(title: "Recent Activity")
    }
    
    private var skeletonPerformanceInsightsGrid: some View {
        skeletonGridCard(title: "Performance Insights")
    }
    
    private var skeletonUpcomingDeadlinesGrid: some View {
        skeletonGridCard(title: "Upcoming Deadlines")
    }
    
    // MARK: - Skeleton Grid Card
    private func skeletonGridCard(title: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            skeletonText(width: 140, height: 20)
            
            // Content
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        skeletonCircle(size: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            skeletonText(width: 100, height: 14)
                            skeletonText(width: 80, height: 12)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Skeleton UI Elements
    private func skeletonText(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.1))
            .frame(width: width, height: height)
            .shimmer()
    }
    
    private func skeletonCircle(size: CGFloat) -> some View {
        Circle()
            .fill(Color.white.opacity(0.1))
            .frame(width: size, height: size)
            .shimmer()
    }
    
    private func skeletonButton(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.white.opacity(0.1))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmer() -> some View {
        self
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(self)
                .offset(x: -200)
                .animation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: UUID()
                )
            )
    }
    
    func loadingState(_ isLoading: Bool, delay: Double = 0.0) -> some View {
        self
            .opacity(isLoading ? 0.3 : 1.0)
            .scaleEffect(isLoading ? 0.98 : 1.0)
            .animation(
                .easeInOut(duration: 0.3)
                .delay(delay),
                value: isLoading
            )
    }
} 