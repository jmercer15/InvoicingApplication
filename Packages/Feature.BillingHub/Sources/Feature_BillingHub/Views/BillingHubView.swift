//
//  BillingHubView.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import AppKit
import SwiftData
import SharedUI
import Data
import Core

public struct BillingHubView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: BillingHubViewModel
    
    @State private var isEditingPanelVisible = false
    @State private var selectedCard: KanbanCardData?
    @FocusState private var isSearchFocused: Bool


    public init() {
        // Use safe container creation to handle errors gracefully
        guard let container = ModelContainerHelper.createModelContainerSafely() else {
            fatalError("Failed to create ModelContainer for BillingHubView")
        }
        _viewModel = StateObject(wrappedValue: BillingHubViewModel(
            modelContext: ModelContext(container)
        ))
    }

    // Internal initializer to allow previews to inject a custom view model
    init(viewModel: BillingHubViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        // Precompute lightweight counts to ease SwiftUI type-checking
        let completedCount = viewModel.sessionsByStatus[.completed]?.count ?? 0
        let groupedCount = viewModel.sessionsByStatus[.grouped]?.count ?? 0
        let assignCount = viewModel.sessionsByStatus[.assignServices]?.count ?? 0
        let travelCount = viewModel.sessionsByStatus[.addTravel]?.count ?? 0
        let reviewCount = viewModel.invoicesByStatus[.reviewDrafts]?.count ?? 0
        let readyCount = viewModel.invoicesByStatus[.readyToSend]?.count ?? 0
        let pendingCount = viewModel.invoicesByStatus[.pending]?.count ?? 0
        let receivedCount = viewModel.invoicesByStatus[.received]?.count ?? 0
        let visibleSessionCount = viewModel.sessionsByStatus.values.reduce(0) { $0 + $1.count }
        let visibleInvoiceCount = viewModel.invoicesByStatus.values.reduce(0) { $0 + $1.count }

        ZStack {
            BillingHubBackground()

            KanbanBoardView(
                viewModel: viewModel,
                selectedCard: $selectedCard,
                isEditingPanelVisible: $isEditingPanelVisible
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .animation(BillingHubTheme.Animations.spring, value: isEditingPanelVisible)
                    }
                },
                alignment: .bottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            toolbarContent(sessionCount: visibleSessionCount, invoiceCount: visibleInvoiceCount)
        }
        .toolbarBackground(BillingHubTheme.Gradients.toolbar, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarColorScheme(.dark, for: .windowToolbar)
    }
}

// MARK: - Private helpers

private extension BillingHubView {
    @ToolbarContentBuilder
    func toolbarContent(sessionCount: Int, invoiceCount: Int) -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Text("Billing Hub")
                .font(BillingHubTheme.Typography.title)
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
        }

        ToolbarItemGroup(placement: .automatic) {
            searchField
                .frame(minWidth: 200, idealWidth: 240)

            clientFilter

            if viewModel.hasActiveFilters {
                clearFiltersButton
            }

        }

        ToolbarItem(placement: .automatic) {
            refreshButton
        }
    }

    var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(BillingHubTheme.Palette.textSecondary)

            TextField("Search sessions or invoices", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
                .focused($isSearchFocused)
                .disableAutocorrection(true)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(BillingHubTheme.Palette.textMuted)
                }
                .buttonStyle(.plain)
                .pointerStyle(.pointingHand)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
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
                        clientBadge(clientId: summary.id)
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

    func clientBadge(clientId: UUID) -> some View {
        Circle()
            .fill(ColorSystem.Client.color(for: clientId).opacity(0.85))
            .frame(width: 8, height: 8)
    }

    var clearFiltersButton: some View {
        Button {
            withAnimation(BillingHubTheme.Animations.hover) {
                viewModel.clearFilters()
            }
        } label: {
            Label("Clear", systemImage: "line.3.horizontal.decrease.circle")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textSecondary)
                .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                .background(
                    Capsule()
                        .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.6))
                        .overlay(
                            Capsule()
                                .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .pointerStyle(.pointingHand)
    }

    var refreshButton: some View {
        Button {
            withAnimation(BillingHubTheme.Animations.spring) {
                viewModel.refresh()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
                .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                .background(
                    LinearGradient(
                        colors: [
                            BillingHubTheme.Columns.processing.opacity(0.85),
                            BillingHubTheme.Palette.accentHighlight.opacity(0.85)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(BillingHubTheme.Palette.surfaceStroke.opacity(0.6), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerStyle(.pointingHand)
    }
}

// Metric chips removed per updated design.


private struct FilterPill: View {
    let icon: String
    let title: String

    public var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(BillingHubTheme.Palette.textSecondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(
            Capsule()
                .fill(BillingHubTheme.Gradients.card)
                .overlay(
                    Capsule()
                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                )
                .shadow(color: BillingHubTheme.Shadows.soft.opacity(0.15), radius: 10, x: 0, y: 8)
        )
    }
}

// Supporting Views - Moved to separate files: KanbanHeaders.swift, KanbanViews.swift, EditingPanel.swift, StatusIndicator.swift

#Preview("Billing Hub ? Full View") {
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
            configurations: config
        )
        let context = ModelContext(container)

        // Mock clients and services
        let clientA = ClientEntity(id: UUID(), ndisNumber: "410000010", fullName: "Alex Rivers", status: .active)
        let clientB = ClientEntity(id: UUID(), ndisNumber: "410000011", fullName: "Jamie Lee", status: .active)
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
            s.status = SessionStatus(rawValue: status) ?? .scheduled
            s.groupID = groupID
            return s
        }

        func makeInvoice(client: ClientEntity, number: String, status: String, amount: Double, firstItemDesc: String) -> InvoiceEntity {
            let inv = InvoiceEntity(id: UUID(), invoiceNumber: number)
            inv.client = client
            inv.status = InvoiceStatus(rawValue: status) ?? .draft
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

    public var body: some View {
        BillingHubView(viewModel: viewModel)
            .frame(minHeight: 720)
    }
}
