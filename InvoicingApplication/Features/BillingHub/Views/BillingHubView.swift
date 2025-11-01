//
//  BillingHubView.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import AppKit
import SwiftData

struct BillingHubView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: BillingHubViewModel
    
    @State private var isEditingPanelVisible = false
    @State private var selectedCard: KanbanCardData?
    @FocusState private var isSearchFocused: Bool
    

    init() {
        _viewModel = StateObject(wrappedValue: BillingHubViewModel(
            modelContext: ModelContext(try! ModelContainerHelper.createModelContainer())
        ))
    }

    // Internal initializer to allow previews to inject a custom view model
    init(viewModel: BillingHubViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        // Precompute lightweight counts to ease SwiftUI type-checking
        let completedCount = viewModel.sessionsByStatus[.completed]?.count ?? 0
        let groupedCount = viewModel.sessionsByStatus[.grouped]?.count ?? 0
        let assignCount = viewModel.sessionsByStatus[.assignServices]?.count ?? 0
        let travelCount = viewModel.sessionsByStatus[.addTravel]?.count ?? 0
        let reviewCount = viewModel.invoicesByStatus[.reviewDrafts]?.count ?? 0
        let readyCount = viewModel.invoicesByStatus[.readyToSend]?.count ?? 0
        let pendingCount = viewModel.invoicesByStatus[.pending]?.count ?? 0
        let receivedCount = viewModel.invoicesByStatus[.received]?.count ?? 0
        let prep = completedCount + groupedCount
        let processing = assignCount + travelCount + reviewCount + readyCount
        let payment = pendingCount + receivedCount
        let visibleSessionCount = viewModel.sessionsByStatus.values.reduce(0) { $0 + $1.count }
        let visibleInvoiceCount = viewModel.invoicesByStatus.values.reduce(0) { $0 + $1.count }

        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    StyleGuide.Colors.background,
                    StyleGuide.Colors.background.opacity(0.94),
                    StyleGuide.Colors.background.opacity(0.88)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                overviewSection(preparing: prep, processing: processing, payment: payment)
                filterSection(sessionCount: visibleSessionCount, invoiceCount: visibleInvoiceCount)

                KanbanBoardView(
                    viewModel: viewModel,
                    selectedCard: $selectedCard,
                    isEditingPanelVisible: $isEditingPanelVisible
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, StyleGuide.Dimensions.paddingXXLarge)
            .padding(.vertical, StyleGuide.Dimensions.paddingLarge)
            .overlay(
                Group {
                    if isEditingPanelVisible, let card = selectedCard {
                        EditingPanel(
                            card: card,
                            isVisible: $isEditingPanelVisible
                        )
                        .transition(.move(edge: .bottom))
                        .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: isEditingPanelVisible)
                    }
                },
                alignment: .bottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "5856D6").opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "5856D6"))
                }
                Text("Billing Hub")
                    .font(StyleGuide.Section.titleFont)
            }
            ToolbarItem(placement: .status) {
                HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                    StatusIndicator(color: Color(hex: "5856D6"), label: "Preparing", count: "\(prep)")
                    StatusIndicator(color: Color(hex: "007AFF"), label: "Processing", count: "\(processing)")
                    StatusIndicator(color: Color(hex: "00FF88"), label: "Payment", count: "\(payment)")
                }
            }
        }
    }
}

// MARK: - Private helpers

private extension BillingHubView {
    func overviewSection(preparing: Int, processing: Int, payment: Int) -> some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
            HStack(alignment: .firstTextBaseline, spacing: StyleGuide.Dimensions.paddingMedium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Billing Hub")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.text)
                    Text("Monitor workflows, keep invoices moving, and spot blockers fast.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                Label {
                    Text(viewModel.lastUpdated, style: .relative)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.textSecondary)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(StyleGuide.Colors.textSecondary)
                }
                .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                .background(
                    Capsule()
                        .fill(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium))
                )

                Button {
                    withAnimation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping)) {
                        viewModel.refresh()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.text)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule()
                                .fill(StyleGuide.Colors.primary.opacity(0.85))
                        )
                }
                .buttonStyle(.plain)
                .pointerStyle(.pointingHand)
            }

            HStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                InsightTile(
                    title: "Preparing",
                    caption: "Sessions ready to group",
                    value: preparing,
                    icon: "calendar.badge.plus",
                    accent: Color(hex: "5856D6")
                )
                InsightTile(
                    title: "Processing",
                    caption: "Work in progress",
                    value: processing,
                    icon: "arrow.triangle.branch",
                    accent: Color(hex: "007AFF")
                )
                InsightTile(
                    title: "Payment",
                    caption: "Awaiting cash flow",
                    value: payment,
                    icon: "dollarsign.circle",
                    accent: Color(hex: "00FF88")
                )
            }
        }
        .padding(StyleGuide.Dimensions.paddingXLarge)
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge))
    }

    func filterSection(sessionCount: Int, invoiceCount: Int) -> some View {
        HStack(alignment: .center, spacing: StyleGuide.Dimensions.paddingMedium) {
            searchField

            Divider()
                .frame(height: 32)
                .overlay(StyleGuide.Colors.border.opacity(0.35))

            clientFilter

            if viewModel.hasActiveFilters {
                Button {
                    withAnimation(.easeInOut(duration: StyleGuide.Animations.durationShort)) {
                        viewModel.clearFilters()
                    }
                } label: {
                    Label("Clear", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.textSecondary)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule().fill(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium))
                        )
                }
                .buttonStyle(.plain)
                .pointerStyle(.pointingHand)
            }

            Spacer(minLength: 0)

            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                Image(systemName: "rectangle.grid.3x2")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(StyleGuide.Colors.textSecondary)
                Text("\(sessionCount) sessions • \(invoiceCount) invoices")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.textSecondary)
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
            .background(
                Capsule().fill(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium))
            )
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge))
    }

    var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(StyleGuide.Colors.textSecondary)

            TextField("Search sessions or invoices", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(StyleGuide.Colors.text)
                .focused($isSearchFocused)
                .disableAutocorrection(true)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(StyleGuide.Colors.textSecondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .pointerStyle(.pointingHand)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                .fill(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                        .stroke(StyleGuide.Colors.border.opacity(0.4), lineWidth: 1)
                )
        )
    }

    var clientFilter: some View {
        Menu {
            Button {
                viewModel.selectClient(withID: nil)
            } label: {
                HStack {
                    Text("All Clients")
                    if viewModel.selectedClientID == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            if !viewModel.clientSummaries.isEmpty {
                Divider()
            }

            ForEach(viewModel.clientSummaries) { summary in
                Button {
                    viewModel.selectClient(withID: summary.id)
                } label: {
                    HStack {
                        clientBadge(colorHex: summary.colorHex)
                        Text(summary.name)
                        if viewModel.selectedClientID == summary.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            FilterPill(
                icon: "person.2.fill",
                title: viewModel.selectedClientName ?? "All Clients"
            )
        }
        .menuStyle(.borderlessButton)
    }

    func clientBadge(colorHex: String?) -> some View {
        Circle()
            .fill(Color(hex: colorHex ?? "5856D6").opacity(0.8))
            .frame(width: 8, height: 8)
    }
}

private struct InsightTile: View {
    let title: String
    let caption: String
    let value: Int
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accent)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text)
            }

            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(StyleGuide.Colors.text)

            Text(caption)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(StyleGuide.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StyleGuide.Dimensions.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge, style: .continuous)
                .fill(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge, style: .continuous)
                        .stroke(accent.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

private struct FilterPill: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(StyleGuide.Colors.textSecondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(StyleGuide.Colors.text)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(
            Capsule()
                .fill(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium))
                .overlay(
                    Capsule().stroke(StyleGuide.Colors.border.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// Supporting Views - Moved to separate files: KanbanHeaders.swift, KanbanViews.swift, EditingPanel.swift, StatusIndicator.swift

#Preview("Billing Hub – Full View") {
    BillingHubView_Preview()
}

private struct BillingHubView_Preview: View {
    @StateObject private var viewModel: BillingHubViewModel
    @State private var selectedCard: KanbanCardData? = nil
    @State private var isEditingPanelVisible: Bool = false

    init() {
        // Use an in-memory SwiftData container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ClientEntity.self,
                 BusinessEntity.self,
                 AddressEntity.self,
                 InvoiceEntity.self,
                 InvoiceItemEntity.self,
                 ClientServiceEntity.self,
                 PayeeEntity.self,
                 PlanManagerEntity.self,
                 SessionEntity.self,
                 TravelChargeEntity.self,
                 TravelChargeAuditLog.self,
                 TravelChargeReviewItem.self,
                 CreditHistoryEntryEntity.self,
                 NDISItemEntity.self,
                 RegionalPriceEntity.self,
                 ServiceEntity.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Mock clients and services
        let clientA = ClientEntity(id: UUID(), ndisNumber: "410000010", fullName: "Alex Rivers", status: "active", colorHex: "5856D6")
        let clientB = ClientEntity(id: UUID(), ndisNumber: "410000011", fullName: "Jamie Lee", status: "active", colorHex: "007AFF")
        let serviceA = ClientServiceEntity(id: UUID(), serviceName: "Personal Care", unit: "hour", rate: 88.0)
        let serviceB = ClientServiceEntity(id: UUID(), serviceName: "Community Access", unit: "hour", rate: 75.0)
        serviceA.client = clientA
        serviceB.client = clientB

        func makeSession(client: ClientEntity, svc: ClientServiceEntity, title: String, start: Date, end: Date, status: String, groupID: UUID? = nil) -> SessionEntity {
            let s = SessionEntity(id: UUID())
            s.title = title
            s.client = client
            s.clientService = svc
            s.startTime = start
            s.endTime = end
            s.status = status
            s.groupID = groupID
            return s
        }

        func makeInvoice(client: ClientEntity, number: String, status: String, amount: Double, firstItemDesc: String) -> InvoiceEntity {
            let inv = InvoiceEntity(id: UUID(), invoiceNumber: number)
            inv.client = client
            inv.status = status
            inv.issueDate = Date()
            inv.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())
            inv.totalAmount = amount
            let item = InvoiceItemEntity(id: UUID(), itemDescription: firstItemDesc)
            item.quantity = 1
            item.rate = amount
            item.invoice = inv
            inv.items.append(item)
            return inv
        }

        let now = Date()

        // Sessions across subcolumns
        let g1 = UUID()
        let sessions: [SessionEntity] = [
            // Completed
            makeSession(client: clientA, svc: serviceA, title: "Morning Support", start: now.addingTimeInterval(-3*3600), end: now.addingTimeInterval(-2*3600), status: "completed"),
            makeSession(client: clientB, svc: serviceB, title: "Community Access", start: now.addingTimeInterval(-28*3600), end: now.addingTimeInterval(-26*3600), status: "completed"),
            // Grouped (with and without group)
            makeSession(client: clientA, svc: serviceA, title: "AM Support", start: now.addingTimeInterval(-70*3600), end: now.addingTimeInterval(-69*3600), status: "grouped", groupID: g1),
            makeSession(client: clientA, svc: serviceA, title: "PM Support", start: now.addingTimeInterval(-68*3600), end: now.addingTimeInterval(-67*3600), status: "grouped", groupID: g1),
            makeSession(client: clientB, svc: serviceB, title: "Transport", start: now.addingTimeInterval(-40*3600), end: now.addingTimeInterval(-39*3600), status: "grouped", groupID: nil),
            // Needs services / travel
            makeSession(client: clientA, svc: serviceA, title: "Household Tasks", start: now.addingTimeInterval(-10*3600), end: now.addingTimeInterval(-9*3600), status: "needs_services"),
            makeSession(client: clientB, svc: serviceB, title: "Meal Planning", start: now.addingTimeInterval(-12*3600), end: now.addingTimeInterval(-11*3600), status: "needs_services"),
            makeSession(client: clientA, svc: serviceA, title: "Transport to Appointment", start: now.addingTimeInterval(-8*3600), end: now.addingTimeInterval(-7.5*3600), status: "needs_travel"),
            makeSession(client: clientB, svc: serviceB, title: "Community Event", start: now.addingTimeInterval(-7*3600), end: now.addingTimeInterval(-6.5*3600), status: "needs_travel")
        ]

        // Invoices across subcolumns
        let invoices: [InvoiceEntity] = [
            makeInvoice(client: clientA, number: "INV-PREV-0001", status: "draft", amount: 220.0, firstItemDesc: "Support Hours"),
            makeInvoice(client: clientB, number: "INV-PREV-0002", status: "draft", amount: 140.0, firstItemDesc: "Transport"),
            makeInvoice(client: clientA, number: "INV-PREV-0003", status: "ready", amount: 310.0, firstItemDesc: "Support + Travel"),
            makeInvoice(client: clientB, number: "INV-PREV-0004", status: "ready", amount: 95.0, firstItemDesc: "Community Access"),
            makeInvoice(client: clientA, number: "INV-PREV-0005", status: "sent", amount: 175.0, firstItemDesc: "Support"),
            makeInvoice(client: clientB, number: "INV-PREV-0006", status: "sent", amount: 260.0, firstItemDesc: "Support Services"),
            makeInvoice(client: clientA, number: "INV-PREV-0007", status: "paid", amount: 420.0, firstItemDesc: "Support Bundle"),
            makeInvoice(client: clientB, number: "INV-PREV-0008", status: "paid", amount: 80.0, firstItemDesc: "Transport Fee")
        ]

        // Persist
        context.insert(clientA)
        context.insert(clientB)
        context.insert(serviceA)
        context.insert(serviceB)
        sessions.forEach { context.insert($0) }
        invoices.forEach { context.insert($0) }
        try? context.save()

        _viewModel = StateObject(wrappedValue: BillingHubViewModel(modelContext: context))
    }

    var body: some View {
        BillingHubView(viewModel: viewModel)
            .frame(minHeight: 720)
    }
}
