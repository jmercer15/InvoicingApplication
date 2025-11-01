//
//  KanbanBoardView.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import SwiftData


struct KanbanBoardView: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    @StateObject private var dragDropState = DragDropState()
    // Collapsible sections
    @State private var preparingCollapsed: Bool = false
    @State private var processingCollapsed: Bool = false
    @State private var paymentCollapsed: Bool = false

    var body: some View {
        // Precompute lightweight counts to keep body simple
        let completedSessionsCount = viewModel.sessionsByStatus[.completed]?.count ?? 0
        let groupedSessionsCount = viewModel.sessionsByStatus[.grouped]?.count ?? 0
        let assignServicesSessionsCount = viewModel.sessionsByStatus[.assignServices]?.count ?? 0
        let addTravelSessionsCount = viewModel.sessionsByStatus[.addTravel]?.count ?? 0
        let reviewDraftsInvoicesCount = viewModel.invoicesByStatus[.reviewDrafts]?.count ?? 0
        let readyToSendInvoicesCount = viewModel.invoicesByStatus[.readyToSend]?.count ?? 0
        let pendingInvoicesCount = viewModel.invoicesByStatus[.pending]?.count ?? 0
        let receivedInvoicesCount = viewModel.invoicesByStatus[.received]?.count ?? 0

        return GeometryReader { _ in
            VStack(spacing: 0) {
                GeometryReader { columnsGeometry in
                    let totalWidth = columnsGeometry.size.width
                    let collapsedWidth: CGFloat = 60

                    // Weights reflect original 25% : 50% : 25%
                    let leftWeight: CGFloat = 1
                    let middleWeight: CGFloat = 2
                    let rightWeight: CGFloat = 1

                    let collapsedCount = [preparingCollapsed, processingCollapsed, paymentCollapsed].filter { $0 }.count
                    let reservedForCollapsed = CGFloat(collapsedCount) * collapsedWidth
                    let available = max(0, totalWidth - reservedForCollapsed)

                    let activeWeight = (preparingCollapsed ? 0 : leftWeight) + (processingCollapsed ? 0 : middleWeight) + (paymentCollapsed ? 0 : rightWeight)

                    let leftWidth: CGFloat = preparingCollapsed ? collapsedWidth : (activeWeight > 0 ? available * (leftWeight / activeWeight) : collapsedWidth)
                    let middleWidth: CGFloat = processingCollapsed ? collapsedWidth : (activeWeight > 0 ? available * (middleWeight / activeWeight) : collapsedWidth)
                    let rightWidth: CGFloat = paymentCollapsed ? collapsedWidth : (activeWeight > 0 ? available * (rightWeight / activeWeight) : collapsedWidth)

                    Grid(alignment: .top, horizontalSpacing: 0, verticalSpacing: 0) {
                        GridRow {
                            PreparingSessionsColumn(
                                viewModel: viewModel,
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible,
                                completedSessionsCount: completedSessionsCount,
                                groupedSessionsCount: groupedSessionsCount,
                                width: leftWidth,
                                isCollapsed: $preparingCollapsed
                            )

                            ProcessingColumn(
                                viewModel: viewModel,
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible,
                                assignServicesSessionsCount: assignServicesSessionsCount,
                                addTravelSessionsCount: addTravelSessionsCount,
                                reviewDraftsInvoicesCount: reviewDraftsInvoicesCount,
                                readyToSendInvoicesCount: readyToSendInvoicesCount,
                                width: middleWidth,
                                isCollapsed: $processingCollapsed
                            )

                            PaymentColumn(
                                viewModel: viewModel,
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible,
                                pendingInvoicesCount: pendingInvoicesCount,
                                receivedInvoicesCount: receivedInvoicesCount,
                                width: rightWidth,
                                isCollapsed: $paymentCollapsed
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            StyleGuide.Colors.background,
                            StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .background(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.strong))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
                .stroke(StyleGuide.Colors.border.opacity(0.6), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))
        .padding(.top)
        .padding(.horizontal)
        .environmentObject(dragDropState)
    }
}

// MARK: - Preparing Sessions Preview
private struct PreparingSessionsColumnPreview: View {
    @StateObject private var viewModel: BillingHubViewModel
    @State private var selectedCard: KanbanCardData? = nil
    @State private var isEditingPanelVisible: Bool = false
    @State private var isCollapsed: Bool = false

    init() {
        // Build an in-memory SwiftData container for previews
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

        // Seed mock data
        let client = ClientEntity(id: UUID(), ndisNumber: "410000000", fullName: "Alex Rivers", status: "active", colorHex: "007AFF")
        let service = ClientServiceEntity(id: UUID(), serviceName: "Personal Care", unit: "hour", rate: 88.0)
        service.client = client

        func makeSession(title: String, start: Date, end: Date, status: String) -> SessionEntity {
            let s = SessionEntity(id: UUID())
            s.title = title
            s.client = client
            s.clientService = service
            s.startTime = start
            s.endTime = end
            s.status = status
            return s
        }

        let now = Date()
        let sessions: [SessionEntity] = [
            makeSession(title: "Morning Support", start: now.addingTimeInterval(-3*3600), end: now.addingTimeInterval(-2*3600), status: "completed"),
            makeSession(title: "Community Access", start: now.addingTimeInterval(-26*3600), end: now.addingTimeInterval(-24*3600), status: "completed"),
            makeSession(title: "Meal Prep", start: now.addingTimeInterval(-50*3600), end: now.addingTimeInterval(-49*3600), status: "grouped")
        ]

        context.insert(client)
        context.insert(service)
        sessions.forEach { context.insert($0) }
        try? context.save()

        _viewModel = StateObject(wrappedValue: BillingHubViewModel(modelContext: context))
    }

    var body: some View {
        let completedCount = viewModel.sessionsByStatus[.completed]?.count ?? 0
        let groupedCount = viewModel.sessionsByStatus[.grouped]?.count ?? 0

        return HStack(spacing: 0) {
            PreparingSessionsColumn(
                viewModel: viewModel,
                selectedCard: $selectedCard,
                isEditingPanelVisible: $isEditingPanelVisible,
                completedSessionsCount: completedCount,
                groupedSessionsCount: groupedCount,
                width: 420,
                isCollapsed: $isCollapsed
            )
        }
        .frame(height: 520)
        .padding()
        .background(StyleGuide.Colors.secondary)
        .environmentObject(DragDropState())
    }
}

#Preview("Billing Hub – Full Kanban Board") {
    FullKanbanBoardPreview()
}

private struct FullKanbanBoardPreview: View {
    @StateObject private var viewModel: BillingHubViewModel
    @State private var selectedCard: KanbanCardData? = nil
    @State private var isEditingPanelVisible: Bool = false

    init() {
        // In‑memory SwiftData store
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

        // Mock data
        let clientA = ClientEntity(id: UUID(), ndisNumber: "410000001", fullName: "Alex Rivers", status: "active", colorHex: "5856D6")
        let clientB = ClientEntity(id: UUID(), ndisNumber: "410000002", fullName: "Jamie Lee", status: "active", colorHex: "007AFF")

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

        // Completed sessions
        let completed = [
            makeSession(client: clientA, svc: serviceA, title: "Morning Support", start: now.addingTimeInterval(-3*3600), end: now.addingTimeInterval(-2*3600), status: "completed"),
            makeSession(client: clientB, svc: serviceB, title: "Community Access", start: now.addingTimeInterval(-28*3600), end: now.addingTimeInterval(-26*3600), status: "completed"),
            makeSession(client: clientA, svc: serviceA, title: "Meal Prep", start: now.addingTimeInterval(-50*3600), end: now.addingTimeInterval(-49*3600), status: "completed")
        ]

        // Grouped sessions (mix grouped and ungrouped within Grouped column)
        let g1 = UUID()
        let grouped = [
            makeSession(client: clientA, svc: serviceA, title: "AM Support", start: now.addingTimeInterval(-70*3600), end: now.addingTimeInterval(-69*3600), status: "grouped", groupID: g1),
            makeSession(client: clientA, svc: serviceA, title: "PM Support", start: now.addingTimeInterval(-68*3600), end: now.addingTimeInterval(-67*3600), status: "grouped", groupID: g1),
            makeSession(client: clientB, svc: serviceB, title: "Transport", start: now.addingTimeInterval(-40*3600), end: now.addingTimeInterval(-39*3600), status: "grouped", groupID: nil),
            makeSession(client: clientB, svc: serviceB, title: "Community Visit", start: now.addingTimeInterval(-38*3600), end: now.addingTimeInterval(-37*3600), status: "grouped", groupID: nil)
        ]

        // Assign Services + Add Travel
        let needsServices = [
            makeSession(client: clientA, svc: serviceA, title: "Household Tasks", start: now.addingTimeInterval(-10*3600), end: now.addingTimeInterval(-9*3600), status: "needs_services"),
            makeSession(client: clientB, svc: serviceB, title: "Meal Planning", start: now.addingTimeInterval(-12*3600), end: now.addingTimeInterval(-11*3600), status: "needs_services")
        ]
        let needsTravel = [
            makeSession(client: clientA, svc: serviceA, title: "Transport to Appointment", start: now.addingTimeInterval(-8*3600), end: now.addingTimeInterval(-7.5*3600), status: "needs_travel"),
            makeSession(client: clientB, svc: serviceB, title: "Community Event", start: now.addingTimeInterval(-7*3600), end: now.addingTimeInterval(-6.5*3600), status: "needs_travel")
        ]

        // Draft/Ready/Pending/Received invoices
        let invoices: [InvoiceEntity] = [
            makeInvoice(client: clientA, number: "INV-TEST-0001", status: "draft", amount: 220.0, firstItemDesc: "Support Hours"),
            makeInvoice(client: clientB, number: "INV-TEST-0002", status: "draft", amount: 140.0, firstItemDesc: "Transport"),
            makeInvoice(client: clientA, number: "INV-TEST-0003", status: "ready", amount: 310.0, firstItemDesc: "Support + Travel"),
            makeInvoice(client: clientB, number: "INV-TEST-0004", status: "ready", amount: 95.0, firstItemDesc: "Community Access"),
            makeInvoice(client: clientA, number: "INV-TEST-0005", status: "sent", amount: 175.0, firstItemDesc: "Support"),
            makeInvoice(client: clientB, number: "INV-TEST-0006", status: "sent", amount: 260.0, firstItemDesc: "Support Services"),
            makeInvoice(client: clientA, number: "INV-TEST-0007", status: "paid", amount: 420.0, firstItemDesc: "Support Bundle"),
            makeInvoice(client: clientB, number: "INV-TEST-0008", status: "paid", amount: 80.0, firstItemDesc: "Transport Fee")
        ]

        // Persist
        context.insert(clientA)
        context.insert(clientB)
        context.insert(serviceA)
        context.insert(serviceB)
        (completed + grouped + needsServices + needsTravel).forEach { context.insert($0) }
        invoices.forEach { context.insert($0) }
        try? context.save()

        _viewModel = StateObject(wrappedValue: BillingHubViewModel(modelContext: context))
    }

    var body: some View {
        KanbanBoardView(
            viewModel: viewModel,
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible
        )
        .frame(minHeight: 680)
        .padding()
        .background(StyleGuide.Colors.secondary)
        .environmentObject(DragDropState())
    }
}



// Narrow vertical bar shown when a primary column is collapsed
private struct CollapsedColumnBar: View {
    var title: String
    var icon: String
    var color: Color
    var count: String? = nil
    @Binding var isCollapsed: Bool
    @State private var isHovered: Bool = false
    // Simple collapsed placeholder bar layout

    var body: some View {
        
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.85))
                    .lineLimit(1)
                    //.fixedSize() // prevent compression that shrinks font size
                    .rotationEffect(.degrees(-90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let count {
                    Text(count)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color.opacity(0.9))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isCollapsed = false
                }
            }
        .background(color.opacity(isHovered ? 0.32 : 0.24))
        .pointerStyle(.pointingHand)
#if os(macOS)
        .help("Expand \(title)")
#endif
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

// (VerticalText removed; using rotated Text(title) instead)

// MARK: - Extracted Columns for Simpler Type-Checking

private struct PreparingSessionsColumn: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let completedSessionsCount: Int
    let groupedSessionsCount: Int
    let width: CGFloat
    @Binding var isCollapsed: Bool

    init(
        viewModel: BillingHubViewModel,
        selectedCard: Binding<KanbanCardData?>,
        isEditingPanelVisible: Binding<Bool>,
        completedSessionsCount: Int,
        groupedSessionsCount: Int,
        width: CGFloat,
        isCollapsed: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self._selectedCard = selectedCard
        self._isEditingPanelVisible = isEditingPanelVisible
        self.completedSessionsCount = completedSessionsCount
        self.groupedSessionsCount = groupedSessionsCount
        self.width = width
        self._isCollapsed = isCollapsed
    }

    var body: some View {
        Group {
            if isCollapsed {
                CollapsedColumnBar(
                    title: "Preparing",
                    icon: "calendar.badge.plus",
                    color: Color(hex: "5856D6"),
                    count: "\(completedSessionsCount + groupedSessionsCount)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(spacing: 0) {
                    KanbanSectionHeader(
                        title: "Preparing Sessions",
                        icon: "calendar.badge.plus",
                        color: Color(hex: "5856D6"),
                        count: "\(completedSessionsCount + groupedSessionsCount)",
                        isCollapsed: $isCollapsed
                    )
                    Grid(alignment: .top, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    // Completed
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Completed",
                            icon: "calendar.badge.checkmark",
                            color: Color(hex: "5856D6"),
                            count: "\(completedSessionsCount)"
                        )

                        ScrollView {
                            KanbanColumn(
                                cards: viewModel.sessionsByStatus[.completed] ?? [],
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible,
                                enableReorderBetween: true,
                                onReorderBetween: { sourceID, beforeTargetID, _ in
                                    viewModel.reorderInCompleted(sourceID: sourceID, beforeTargetID: beforeTargetID)
                                },
                                betweenAccentColor: Color(hex: "5856D6")
                            )
                        }
                        .modifier(AutoScrollOnDrag())
                        .modifier(FullAreaDropModifier(enable: true, onDrop: { sourceID in
                            guard viewModel.fetchSession(byID: sourceID) != nil else { return false }
                            viewModel.moveSessionToCompletedSmooth(sessionID: sourceID)
                            return true
                        }, isEligible: { state in
                            (state.draggingColumn != .completed) && !state.hoveringBetween
                        }, accentColor: Color(hex: "5856D6"), labelProvider: { state in
                            "Drop to Completed"
                        }))
                        .background(Color.black.opacity(0.04))
                    }
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(StyleGuide.Colors.border),
                        alignment: .trailing
                    )

                    // Grouped
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Grouped",
                            icon: "rectangle.on.rectangle.badge.gearshape",
                            color: Color(hex: "5856D6"),
                            count: "\(groupedSessionsCount)"
                        )

                        ScrollView {
                            KanbanColumn(
                                cards: viewModel.sessionsByStatus[.grouped] ?? [],
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible,
                                enableGroupingDrops: true,
                                onDropOnCard: { sourceID, targetID in
                                    guard sourceID != targetID,
                                          viewModel.fetchSession(byID: sourceID) != nil,
                                          viewModel.fetchSession(byID: targetID) != nil else { return false }
                                    viewModel.groupSessionsSmooth(sourceID: sourceID, targetID: targetID)
                                    return true
                                },
                                enableReorderBetween: true,
                                onReorderBetween: { sourceID, beforeTargetID, scopeGroupID in
                                    viewModel.reorderInGrouped(sourceID: sourceID, beforeTargetID: beforeTargetID, scopeGroupID: scopeGroupID)
                                },
                                betweenAccentColor: Color(hex: "5856D6")
                            )
                        }
                        .modifier(AutoScrollOnDrag())
                        .modifier(FullAreaDropModifier(enable: true, onDrop: { sourceID in
                            guard viewModel.fetchSession(byID: sourceID) != nil else { return false }
                            viewModel.dropIntoGroupedColumnSmooth(sessionID: sourceID)
                            return true
                        }, isEligible: { state in
                            // Allow when dragging from other columns, or ungrouping a grouped session
                            ((state.draggingColumn != .grouped) || (state.draggingGroupID != nil)) && !state.hoveringBetween
                        }, accentColor: Color(hex: "5856D6"), labelProvider: { state in
                            if state.draggingColumn == .grouped && state.draggingGroupID != nil {
                                return "Drop to Ungroup"
                            }
                            return "Drop to Grouped"
                        }))
                        .background(Color.black.opacity(0.04))
                    }
                }
                    }
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(StyleGuide.Colors.border),
            alignment: .trailing
        )
    }
}

private struct ProcessingColumn: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let assignServicesSessionsCount: Int
    let addTravelSessionsCount: Int
    let reviewDraftsInvoicesCount: Int
    let readyToSendInvoicesCount: Int
    let width: CGFloat
    @Binding var isCollapsed: Bool

    var body: some View {
        Group {
            if isCollapsed {
                CollapsedColumnBar(
                    title: "Processing",
                    icon: "document.badge.gearshape.fill",
                    color: Color(hex: "007AFF"),
                    count: "\(assignServicesSessionsCount + addTravelSessionsCount + reviewDraftsInvoicesCount + readyToSendInvoicesCount)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(spacing: 0) {
                    KanbanSectionHeader(
                        title: "Processing",
                        icon: "document.badge.gearshape.fill",
                        color: Color(hex: "007AFF"),
                        count: "\(assignServicesSessionsCount + addTravelSessionsCount + reviewDraftsInvoicesCount + readyToSendInvoicesCount)",
                        isCollapsed: $isCollapsed
                    )

                    Grid(alignment: .top, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    // Assign Services
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Assign Services",
                            icon: "questionmark.text.page",
                            color: Color(hex: "007AFF"),
                            count: "\(assignServicesSessionsCount)"
                        )

                        ScrollView {
                            KanbanColumn(
                                cards: viewModel.sessionsByStatus[.assignServices] ?? [],
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible
                            )
                        }
                        .background(Color.black.opacity(0.04))
                    }
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(StyleGuide.Colors.border),
                        alignment: .trailing
                    )

                    // Add Travel
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Add Travel",
                            icon: "car",
                            color: Color(hex: "007AFF"),
                            count: "\(addTravelSessionsCount)"
                        )

                        ScrollView {
                            KanbanColumn(
                                cards: viewModel.sessionsByStatus[.addTravel] ?? [],
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible
                            )
                        }
                        .background(Color.black.opacity(0.04))
                    }
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(StyleGuide.Colors.border),
                        alignment: .trailing
                    )

                    // Review Drafts
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Review Drafts",
                            icon: "doc.text.magnifyingglass",
                            color: Color(hex: "007AFF"),
                            count: "\(reviewDraftsInvoicesCount)"
                        )

                        ScrollView {
                            KanbanColumn(
                                cards: viewModel.invoicesByStatus[.reviewDrafts] ?? [],
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible
                            )
                        }
                        .background(Color.black.opacity(0.04))
                    }
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(StyleGuide.Colors.border),
                        alignment: .trailing
                    )

                    // Ready to Send
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Ready to Send",
                            icon: "square.and.arrow.up.badge.clock",
                            color: Color(hex: "007AFF"),
                            count: "\(readyToSendInvoicesCount)"
                        )

                        ScrollView {
                            KanbanColumn(
                                cards: viewModel.invoicesByStatus[.readyToSend] ?? [],
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible
                            )
                        }
                        .background(Color.black.opacity(0.04))
                    }
                }
                    }
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.strong))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(StyleGuide.Colors.border),
            alignment: .trailing
        )
    }
}

private struct PaymentColumn: View {
    @ObservedObject var viewModel: BillingHubViewModel
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let pendingInvoicesCount: Int
    let receivedInvoicesCount: Int
    let width: CGFloat
    @Binding var isCollapsed: Bool

    var body: some View {
        Group {
            if isCollapsed {
                CollapsedColumnBar(
                    title: "Payment",
                    icon: "dollarsign.circle.fill",
                    color: Color(hex: "00FF88"),
                    count: "\(pendingInvoicesCount + receivedInvoicesCount)",
                    isCollapsed: $isCollapsed
                )
            } else {
                VStack(spacing: 0) {
                    KanbanSectionHeader(
                        title: "Payment",
                        icon: "dollarsign.circle.fill",
                        color: Color(hex: "00FF88"),
                        count: "\(pendingInvoicesCount + receivedInvoicesCount)",
                        isCollapsed: $isCollapsed
                    )

                    Grid(alignment: .top, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                    // Pending
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Pending",
                            icon: "clock",
                            color: Color(hex: "00FF88"),
                            count: "\(pendingInvoicesCount)"
                        )

                        ScrollView {
                            KanbanColumn(
                                cards: viewModel.invoicesByStatus[.pending] ?? [],
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible
                            )
                        }
                        .background(Color.black.opacity(0.04))

                    }
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(StyleGuide.Colors.border),
                        alignment: .trailing
                    )

                    // Received
                    VStack(spacing: 0) {
                        KanbanColumnHeader(
                            title: "Received",
                            icon: "checkmark.circle",
                            color: Color(hex: "00FF88"),
                            count: "\(receivedInvoicesCount)"
                        )
                        ScrollView {
                            KanbanColumn(
                                cards: viewModel.invoicesByStatus[.received] ?? [],
                                selectedCard: $selectedCard,
                                isEditingPanelVisible: $isEditingPanelVisible
                            )
                        }
                        .background(Color.black.opacity(0.04))
                    }
                }
                    }
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.medium))
    }
}
