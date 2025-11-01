//
//  NativeListKanbanColumn.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import SharedUI

// MARK: - Native List-based Kanban Column

struct NativeListKanbanColumn: View {
    let cards: [KanbanCardData]
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let columnType: KanbanCardData.BillingColumnType
    let enableGroupingDrops: Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)? // (sourceID, targetID) -> Bool
    let onDropOnColumn: ((UUID) -> Bool)? // (sourceID) -> Bool
    let onReorderBetween: ((UUID, UUID?, UUID?) -> Bool)? // (sourceID, beforeTargetID, scopeGroupID)
    let betweenAccentColor: Color

    @EnvironmentObject private var dragDropState: DragDropState
    @State private var draggedItem: KanbanCardData?

    init(
        cards: [KanbanCardData],
        selectedCard: Binding<KanbanCardData?>,
        isEditingPanelVisible: Binding<Bool>,
        columnType: KanbanCardData.BillingColumnType,
        enableGroupingDrops: Bool = false,
        onDropOnCard: ((UUID, UUID) -> Bool)? = nil,
        onDropOnColumn: ((UUID) -> Bool)? = nil,
        onReorderBetween: ((UUID, UUID?, UUID?) -> Bool)? = nil,
        betweenAccentColor: Color = StyleGuide.Colors.primary
    ) {
        self.cards = cards
        self._selectedCard = selectedCard
        self._isEditingPanelVisible = isEditingPanelVisible
        self.columnType = columnType
        self.enableGroupingDrops = enableGroupingDrops
        self.onDropOnCard = onDropOnCard
        self.onDropOnColumn = onDropOnColumn
        self.onReorderBetween = onReorderBetween
        self.betweenAccentColor = betweenAccentColor
    }

    var body: some View {
        if enableGroupingDrops {
            groupedList
        } else {
            simpleList
        }
    }

    // MARK: - Simple List (for non-grouped columns)

    private var simpleList: some View {
        List {
            ForEach(cards) { card in
                KanbanCard(
                    cardData: card,
                    selectedCard: $selectedCard,
                    isEditingPanelVisible: $isEditingPanelVisible,
                    enableGroupingDrop: false,
                    onDrop: nil
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            }
            .onMove(perform: moveItems)
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .dropDestination(for: SessionDragPayload.self) { items, location in
            handleColumnDrop(items: items)
        } isTargeted: { isTargeted in
            // Handle visual feedback for column drops
        }
    }

    // MARK: - Grouped List (for Grouped column)

    private var groupedList: some View {
        let clusters = KanbanColumn.buildClusters(from: cards)

        return List {
            ForEach(Array(clusters.enumerated()), id: \.offset) { index, item in
                switch item {
                case .single(let card):
                    KanbanCard(
                        cardData: card,
                        selectedCard: $selectedCard,
                        isEditingPanelVisible: $isEditingPanelVisible,
                        enableGroupingDrop: enableGroupingDrops,
                        onDrop: onDropOnCard
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))

                case .group(let groupID, let groupCards):
                    Section(
                        content: {
                            ForEach(groupCards) { card in
                                KanbanCard(
                                    cardData: card,
                                    selectedCard: $selectedCard,
                                    isEditingPanelVisible: $isEditingPanelVisible,
                                    enableGroupingDrop: enableGroupingDrops,
                                    onDrop: onDropOnCard
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 8))
                            }
                            .onMove { from, to in
                                moveItemsInGroup(groupID: groupID, from: from, to: to)
                            }
                        },
                        header: {
                            let accent = KanbanColumn.groupAccentColor(for: groupCards)
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.stack")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(StyleGuide.Colors.text)

                                Text("Group")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(StyleGuide.Colors.text)

                                Text("\(groupCards.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(StyleGuide.Colors.text)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(accent.opacity(0.18))
                                            .overlay(
                                                Capsule()
                                                    .stroke(accent.opacity(0.45), lineWidth: 0.5)
                                            )
                                    )
                            }
                            .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
                            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                            .background(
                                Capsule()
                                    .fill(accent.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .stroke(accent, lineWidth: 0.5)
                                    )
                            )
                        }
                    )
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Color.clear)
        .onAppear {
            // Enable smooth drag animations
        }
        .dropDestination(for: SessionDragPayload.self) { items, location in
            handleColumnDrop(items: items)
        } isTargeted: { isTargeted in
            if isTargeted {
                // Add subtle visual feedback when dragging over the list
                Rectangle()
                    .fill(Color.accentColor.opacity(0.1))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Helper Methods

    private func moveItems(from source: IndexSet, to destination: Int) {
        // Handle reordering within the list
        guard let onReorderBetween = onReorderBetween else { return }

        let sourceIndex = source.first!
        let sourceCard = cards[sourceIndex]

        // Determine the target position
        let targetIndex = destination > sourceIndex ? destination - 1 : destination
        let beforeTargetID = targetIndex < cards.count ? cards[targetIndex].id : nil

        // Call the reorder handler
        if case .session(let sessionData) = sourceCard {
            _ = onReorderBetween(sessionData.sessionId, beforeTargetID, nil)
        }
    }

    private func moveItemsInGroup(groupID: UUID, from source: IndexSet, to destination: Int) {
        // Handle reordering within a group
        guard let onReorderBetween = onReorderBetween else { return }

        // Find the group cards
        let groupCards = cards.filter { card in
            if case .session(let sessionData) = card {
                return sessionData.groupID == groupID
            }
            return false
        }

        let sourceIndex = source.first!
        let sourceCard = groupCards[sourceIndex]

        // Determine the target position within the group
        let targetIndex = destination > sourceIndex ? destination - 1 : destination
        let beforeTargetID = targetIndex < groupCards.count ? groupCards[targetIndex].id : nil

        // Call the reorder handler with the group scope
        if case .session(let sessionData) = sourceCard {
            _ = onReorderBetween(sessionData.sessionId, beforeTargetID, groupID)
        }
    }

    private func moveItemsInList(from source: IndexSet, to destination: Int) {
        // Handle reordering within the main list
        guard let onReorderBetween = self.onReorderBetween else { return }

        // Get the clusters to work with the visual order
        let clusters = KanbanColumn.buildClusters(from: self.cards)
        let flattenedItems = clusters.flatMap { cluster -> [(KanbanRenderItem, Int)] in
            switch cluster {
            case .single(let card):
                return [(cluster, 0)]
            case .group(_, let groupCards):
                return groupCards.enumerated().map { (cluster, $0.offset) }
            }
        }

        let sourceIndex = source.first!
        guard sourceIndex < flattenedItems.count else { return }

        let sourceItem = flattenedItems[sourceIndex]

        // Ensure destination is within bounds
        let clampedDestination = max(0, min(destination, flattenedItems.count))

        // Determine the target position
        let targetIndex = clampedDestination > sourceIndex ? clampedDestination - 1 : clampedDestination
        let beforeTargetID = targetIndex < flattenedItems.count && targetIndex >= 0 ?
            flattenedItems[targetIndex].0.getCardID() : nil

        // Call the reorder handler
        if let sourceCardID = sourceItem.0.getCardID() {
            let targetGroupID = targetIndex < flattenedItems.count && targetIndex >= 0 ?
                flattenedItems[targetIndex].0.getGroupID() : sourceItem.0.getGroupID()
            _ = onReorderBetween(sourceCardID, beforeTargetID, targetGroupID)
        }
    }

    private func handleColumnDrop(items: [SessionDragPayload]) -> Bool {
        guard let item = items.first,
              let onDropOnColumn = onDropOnColumn else { return false }

        return onDropOnColumn(item.sessionID)
    }

    // MARK: - Grouping Logic (moved from KanbanColumn)

// MARK: - Preview

#Preview("Native List Kanban Column") {
    NativeListKanbanColumn_Preview()
}

private struct NativeListKanbanColumn_Preview: View {
    @State private var selected: KanbanCardData? = nil
    @State private var showEditor = false
    @State private var sampleSessions: [KanbanCardData]

    init() {
        let baseAccent = KanbanCardData.columnAccentColor(for: .grouped)
        let gid = UUID()
        let s1 = SessionKanbanCardData(
            sessionId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            title: "Morning Support",
            clientName: "Alex Rivers",
            serviceName: "Personal Care",
            travelRate: 0.92,
            travelRateUnit: "km",
            suggestedTravelDistanceKM: 14.8,
            suggestedTravelTimeMinutes: 18,
            priority: .medium,
            accentColor: baseAccent,
            duration: "1.0h",
            date: "Dec 15",
            hasIssues: false,
            workflowStatus: .grouped,
            columnType: .grouped,
            startTime: nil,
            endTime: nil,
            groupID: gid
        )
        let s2 = SessionKanbanCardData(
            sessionId: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            title: "Community Access",
            clientName: "Sam Green",
            serviceName: "Transport",
            travelRate: 48.0,
            travelRateUnit: "hour",
            suggestedTravelDistanceKM: 9.6,
            suggestedTravelTimeMinutes: 32,
            priority: .low,
            accentColor: baseAccent,
            duration: "2.0h",
            date: "Dec 14",
            hasIssues: false,
            workflowStatus: .grouped,
            columnType: .grouped,
            startTime: nil,
            endTime: nil,
            groupID: gid
        )
        let s3 = SessionKanbanCardData(
            sessionId: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            title: "Transport",
            clientName: "Jamie Lee",
            serviceName: "Transport",
            travelRate: 0.85,
            travelRateUnit: "km",
            suggestedTravelDistanceKM: 6.4,
            suggestedTravelTimeMinutes: 12,
            priority: .low,
            accentColor: baseAccent,
            duration: "1.5h",
            date: "Dec 13",
            hasIssues: false,
            workflowStatus: .grouped,
            columnType: .grouped,
            startTime: nil,
            endTime: nil,
            groupID: nil
        )
        _sampleSessions = State(initialValue: [.session(s1), .session(s2), .session(s3)])
    }

    var body: some View {
        NativeListKanbanColumn(
            cards: sampleSessions,
            selectedCard: $selected,
            isEditingPanelVisible: $showEditor,
            columnType: .grouped,
            enableGroupingDrops: true,
            onDropOnCard: { _, _ in false },
            onDropOnColumn: { _ in false }
        )
        .frame(width: 320, height: 420)
        .environmentObject(DragDropState())
        .padding()
        .background(StyleGuide.Colors.secondary)
    }
}
}
