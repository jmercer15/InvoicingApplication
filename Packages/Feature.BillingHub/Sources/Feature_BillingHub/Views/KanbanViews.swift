//
//  KanbanViews.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import SharedUI

// (PointerStyle available on target; no conditional wrappers needed)

struct KanbanColumn: View {
    // Removed 'color' property, it can be derived from cards
    let cards: [KanbanCardData]
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let columnType: KanbanCardData.BillingColumnType
    // Optional grouping drop handling for cards within this column (used by Grouped column)
    let enableGroupingDrops: Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)? // (sourceID, targetID) -> Bool
    // Optional column-wide drop (e.g., drop into empty space to move to Grouped)
    let onDropOnColumn: ((UUID) -> Bool)? // (sourceID) -> Bool
    // Optional between-card reordering drop zones
    let enableReorderBetween: Bool
    let onReorderBetween: ((UUID, UUID?, UUID?) -> Bool)? // (sourceID, beforeTargetID, scopeGroupID)
    let betweenAccentColor: Color

    // Explicit initializer to control optional drop handlers and bindings
    init(
        cards: [KanbanCardData],
        selectedCard: Binding<KanbanCardData?>,
        isEditingPanelVisible: Binding<Bool>,
        columnType: KanbanCardData.BillingColumnType,
        enableGroupingDrops: Bool = false,
        onDropOnCard: ((UUID, UUID) -> Bool)? = nil,
        onDropOnColumn: ((UUID) -> Bool)? = nil,
        enableReorderBetween: Bool = false,
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
        self.enableReorderBetween = enableReorderBetween
        self.onReorderBetween = onReorderBetween
        self.betweenAccentColor = betweenAccentColor
    }

    // Removed getColumnType as it's no longer needed here
    @EnvironmentObject private var dragDropState: DragDropState
    @State private var cardHeights: [UUID: CGFloat] = [:]

    private var typicalCardHeight: CGFloat {
        guard !cardHeights.isEmpty else { return 84 }
        let total = cardHeights.values.reduce(0, +)
        return max(44, total / CGFloat(cardHeights.count))
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            if enableGroupingDrops {
                let clusters = KanbanColumn.buildClusters(from: cards)
                let suppressedBeforeIDs = KanbanColumn.suppressedIDs(for: clusters, cards: cards)

                ForEach(clusters, id: \.id) { item in
                    renderCluster(item, suppressedBeforeIDs: suppressedBeforeIDs)
                }
            } else {
                renderUngroupedCards()
            }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge * 0.5)
        .modifier(ColumnDropModifier(enable: enableGroupingDrops, onDrop: onDropOnColumn, isDragActive: dragDropState.isDragging))
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.1), value: cards.map { $0.id })
        .onPreferenceChange(CardHeightPreferenceKey.self) { values in
            for (k, v) in values { cardHeights[k] = v }
        }
    }

    @ViewBuilder
    private func renderCluster(_ item: KanbanRenderItem, suppressedBeforeIDs: Set<UUID>) -> some View {
        switch item {
        case .single(let card):
            renderSingle(card, suppressedBeforeIDs: suppressedBeforeIDs)
        case .group(let groupID, let groupCards):
            renderGroup(groupID: groupID, groupCards: groupCards, suppressedBeforeIDs: suppressedBeforeIDs)
        }
    }

    @ViewBuilder
    private func renderSingle(_ card: KanbanCardData, suppressedBeforeIDs: Set<UUID>) -> some View {
        if enableReorderBetween, case .session = card, !suppressedBeforeIDs.contains(card.id) {
            let ungroupedIDs = KanbanColumn.ungroupedIDs(in: cards)
            let insertionIndex = ungroupedIDs.firstIndex(of: card.id)
            BetweenDropTarget(
                accentColor: betweenAccentColor,
                targetHeight: cardHeights[card.id] ?? typicalCardHeight,
                scopeIDs: ungroupedIDs,
                insertionIndex: insertionIndex,
                onDrop: { sourceID in
                    onReorderBetween?(sourceID, card.id, nil) ?? false
                }
            )
        }

        MeasuredCard(id: card.id) { row(for: card) }
            .padding(.horizontal, StyleGuide.Dimensions.paddingLarge * 0.5)
    }

    @ViewBuilder
    private func renderGroup(groupID: UUID, groupCards: [KanbanCardData], suppressedBeforeIDs _: Set<UUID>) -> some View {
        let groupAccent = KanbanColumn.groupAccentColor(for: groupCards)
        let resolvedColumn: KanbanCardData.BillingColumnType = KanbanColumn.resolveColumn(for: groupCards, fallback: columnType)
        return VStack(alignment: .leading, spacing: 0) {
            groupReorderBeforeTargets(groupCards: groupCards)
            groupHeaderView(accent: groupAccent, count: groupCards.count)
            groupCardStack(groupID: groupID,
                           groupCards: groupCards,
                           resolvedColumn: resolvedColumn,
                           accent: groupAccent)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge * 0.5)
        .padding(.vertical, 0)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge)
                .fill(StyleGuide.Colors.secondary.opacity(StyleGuide.Opacity.subtle))
                .shadow(color: groupAccent.opacity(0.08), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge)
                        .stroke(groupAccent.opacity(0.5), lineWidth: 1)
                )
        )
        .pointerStyle(.openHand)
        .draggable(GroupDragPayload(groupID: groupID, column: resolvedColumn)) {
            GroupDragPreviewView(
                groupID: groupID,
                cards: groupCards,
                accent: groupAccent,
                column: resolvedColumn,
                dragDropState: dragDropState
            )
        }
        .id(groupID)
    }

    @ViewBuilder
    private func groupReorderBeforeTargets(groupCards: [KanbanCardData]) -> some View {
        if enableReorderBetween {
            let groupFirstID = groupCards.first?.id
            let ungroupedIDs = KanbanColumn.ungroupedIDs(in: cards)
            let insertionIndex = KanbanColumn.ungroupedInsertionIndexBeforeGroup(cards: cards, firstGroupCardID: groupFirstID)
            BetweenDropTarget(
                accentColor: betweenAccentColor,
                targetHeight: typicalCardHeight,
                scopeIDs: ungroupedIDs,
                insertionIndex: insertionIndex,
                onDrop: { sourceID in
                    let beforeID = groupCards.first?.id
                    return onReorderBetween?(sourceID, beforeID, nil) ?? false
                }
            )
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func groupHeaderView(accent: Color, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(StyleGuide.Colors.text)

            Text("Group")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(StyleGuide.Colors.text)

            Text("\(count)")
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

    @ViewBuilder
    private func groupCardStack(
        groupID: UUID,
        groupCards: [KanbanCardData],
        resolvedColumn: KanbanCardData.BillingColumnType,
        accent: Color
    ) -> some View {
        let groupIDs = KanbanColumn.groupCardIDs(in: groupCards)

        ForEach(groupCards) { card in
            if enableReorderBetween, case .session = card {
                BetweenDropTarget(
                    accentColor: betweenAccentColor,
                    targetHeight: cardHeights[card.id] ?? typicalCardHeight,
                    scopeIDs: groupIDs,
                    insertionIndex: groupIDs.firstIndex(of: card.id),
                    onDrop: { sourceID in
                        onReorderBetween?(sourceID, card.id, groupID) ?? false
                    }
                )
            }
            MeasuredCard(id: card.id) { row(for: card) }
        }

        if enableReorderBetween {
            BetweenDropTarget(
                accentColor: betweenAccentColor,
                targetHeight: typicalCardHeight,
                scopeIDs: groupIDs,
                insertionIndex: groupIDs.count,
                onDrop: { sourceID in
                    onReorderBetween?(sourceID, nil, groupID) ?? false
                }
            )
        }
    }

    @ViewBuilder
    private func renderUngroupedCards() -> some View {
        ForEach(cards) { cardData in
            if enableReorderBetween, case .session = cardData {
                let scopeIDs = KanbanColumn.groupCardIDs(in: cards)
                let insertionIndex = scopeIDs.firstIndex(of: cardData.id)
                BetweenDropTarget(
                    accentColor: betweenAccentColor,
                    targetHeight: cardHeights[cardData.id] ?? typicalCardHeight,
                    scopeIDs: scopeIDs,
                    insertionIndex: insertionIndex,
                    onDrop: { sourceID in
                        onReorderBetween?(sourceID, cardData.id, nil) ?? false
                    }
                )
            }

            MeasuredCard(id: cardData.id) { row(for: cardData) }
                .padding(.horizontal, StyleGuide.Dimensions.paddingLarge * 0.5)
                .padding(.vertical, enableReorderBetween ? 0 : 10)
        }

        if enableReorderBetween {
            let scopeIDs = KanbanColumn.groupCardIDs(in: cards)
            BetweenDropTarget(
                accentColor: betweenAccentColor,
                targetHeight: typicalCardHeight,
                scopeIDs: scopeIDs,
                insertionIndex: scopeIDs.count,
                onDrop: { sourceID in
                    onReorderBetween?(sourceID, nil, nil) ?? false
                }
            )
        }
    }
    // Build a row for a card
    @ViewBuilder
    private func row(for cardData: KanbanCardData) -> some View {
        KanbanCard(
            cardData: cardData,
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible,
            enableGroupingDrop: enableGroupingDrops,
            onDrop: { sourceID, targetID in
                onDropOnCard?(sourceID, targetID) ?? false
            }
        )
    }

    // No list-based reordering; LazyVStack only

// MARK: - Local Previews
private struct KanbanColumn_Preview: View {
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
        _sampleSessions = State(initialValue: [.session(s1), .session(s2)])
    }

    var body: some View {
        KanbanColumn(
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


// Measures the height of a row and publishes via preference keyed by card ID
private struct MeasuredCard<Content: View>: View {
    let id: UUID
    let content: Content
    init(id: UUID, @ViewBuilder content: () -> Content) {
        self.id = id
        self.content = content()
    }
    var body: some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: CardHeightPreferenceKey.self, value: [id: geo.size.height])
                }
            )
    }
}

private struct CardHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

#Preview("KanbanColumn") {
    KanbanColumn_Preview()
}
}

// MARK: - Grouping helpers for KanbanColumn
enum KanbanRenderItem: Identifiable {
    case single(card: KanbanCardData)
    case group(id: UUID, cards: [KanbanCardData])

    var id: UUID {
        switch self {
        case .single(let card): return card.id
        case .group(let id, _): return id
        }
    }

    func getCardID() -> UUID? {
        switch self {
        case .single(let card): return card.id
        case .group(_, let cards): return cards.first?.id
        }
    }

    func getGroupID() -> UUID? {
        switch self {
        case .single(let card):
            if case .session(let sessionData) = card {
                return sessionData.groupID
            }
            return nil
        case .group(let id, _): return id
        }
    }
}

extension KanbanColumn {
    // Group header used in List sections
    @ViewBuilder
    func groupHeader(for groupCards: [KanbanCardData]) -> some View {
        let groupAccent = KanbanColumn.groupAccentColor(for: groupCards)
        HStack(spacing: 6) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(groupAccent)
            Text("Group (\(groupCards.count))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(groupAccent)
        }
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
    }

    static func buildClusters(from cards: [KanbanCardData]) -> [KanbanRenderItem] {
        var seenGroupIDs: Set<UUID> = []
        var result: [KanbanRenderItem] = []

        for card in cards {
            switch card {
            case .session(let data):
                if let gid = data.groupID {
                    if seenGroupIDs.contains(gid) {
                        continue
                    } else {
                        // Collect all cards with this groupID preserving input order
                        let grouped = cards.filter { c in
                            if case .session(let d) = c { return d.groupID == gid } else { return false }
                        }
                        result.append(.group(id: gid, cards: grouped))
                        seenGroupIDs.insert(gid)
                    }
                } else {
                    result.append(.single(card: card))
                }
            default:
                result.append(.single(card: card))
            }
        }
        return result
    }

    static func suppressedIDs(for clusters: [KanbanRenderItem], cards: [KanbanCardData]) -> Set<UUID> {
        var ids = Set<UUID>()
        for item in clusters {
            if case .group(_, let groupCards) = item,
               let lastID = groupCards.last?.id,
               let next = KanbanColumn.firstUngroupedAfterGroup(cards: cards, lastGroupCardID: lastID) {
                ids.insert(next)
            }
        }
        return ids
    }

    static func resolveColumn(for cards: [KanbanCardData], fallback: KanbanCardData.BillingColumnType) -> KanbanCardData.BillingColumnType {
        for card in cards {
            switch card {
            case .session(let data):
                return data.columnType
            case .invoice(let data):
                return data.columnType
            }
        }
        return fallback
    }

    static func groupAccentColor(for cards: [KanbanCardData]) -> Color {
        if let first = cards.first {
            switch first {
            case .session(let d): return d.accentColor
            case .invoice(let d): return d.accentColor
            }
        }
        return StyleGuide.Colors.border
    }

    // IDs for ungrouped sessions within the Grouped column rendering
    static func ungroupedIDs(in cards: [KanbanCardData]) -> [UUID] {
        cards.compactMap { c in
            if case .session(let d) = c, d.groupID == nil { return d.id }
            return nil
        }
    }

    // IDs for sessions inside a specific group cluster
    static func groupCardIDs(in cards: [KanbanCardData]) -> [UUID] {
        cards.compactMap { c in
            if case .session(let d) = c { return d.id }
            return nil
        }
    }

    // IDs for all session cards regardless of grouping
    static func sessionIDs(in cards: [KanbanCardData]) -> [UUID] {
        groupCardIDs(in: cards)
    }

    // Compute insertion index in ungrouped scope before a group cluster
    static func ungroupedInsertionIndexBeforeGroup(cards: [KanbanCardData], firstGroupCardID: UUID?) -> Int? {
        guard let firstID = firstGroupCardID,
              let gFirstIdx = cards.firstIndex(where: { $0.id == firstID }) else { return nil }
        var count = 0
        for (idx, c) in cards.enumerated() where idx < gFirstIdx {
            if case .session(let d) = c, d.groupID == nil { count += 1 }
        }
        return count
    }

    // First ungrouped card after a group cluster (anchor for insertion); nil means append
    static func firstUngroupedAfterGroup(cards: [KanbanCardData], lastGroupCardID: UUID?) -> UUID? {
        guard let lastID = lastGroupCardID,
              let lastIndex = cards.firstIndex(where: { $0.id == lastID }) else { return nil }
        for c in cards.dropFirst(lastIndex + 1) {
            if case .session(let d) = c, d.groupID == nil { return d.id }
        }
        return nil
    }

    // Adjacency helper (no-op if adjusted insertion equals source index)
    static func isNoOpReorder(sourceIndex: Int, insertionIndex: Int) -> Bool {
        let adjusted = (sourceIndex < insertionIndex) ? (insertionIndex - 1) : insertionIndex
        return adjusted == sourceIndex
    }
}

struct KanbanCard: View {
    let cardData: KanbanCardData
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    // Optional drop handler for grouping when this card is in Grouped column
    let enableGroupingDrop: Bool
    let onDrop: ((UUID, UUID) -> Bool)? // (sourceID, targetID)
    @EnvironmentObject private var dragDropState: DragDropState

    // Explicit initializer to ensure all parameters are accepted at call site
    init(
        cardData: KanbanCardData,
        selectedCard: Binding<KanbanCardData?>,
        isEditingPanelVisible: Binding<Bool>,
        enableGroupingDrop: Bool = false,
        onDrop: ((UUID, UUID) -> Bool)? = nil
    ) {
        self.cardData = cardData
        self._selectedCard = selectedCard
        self._isEditingPanelVisible = isEditingPanelVisible
        self.enableGroupingDrop = enableGroupingDrop
        self.onDrop = onDrop
    }

    var priorityColor: Color {
        switch cardData {
        case .session(let sessionData):
            switch sessionData.priority {
            case Priority.low: return Color(hex: "00FF88")
            case Priority.medium: return Color(hex: "007AFF")
            case Priority.high: return Color(hex: "FF6B6B")
            }
        case .invoice(let invoiceData):
            switch invoiceData.priority {
            case Priority.low: return Color(hex: "00FF88")
            case Priority.medium: return Color(hex: "007AFF")
            case Priority.high: return Color(hex: "FF6B6B")
            }
        }
    }

    var body: some View {
        switch cardData {
        case .session(let sessionData):
            sessionCard(sessionData)
        case .invoice(let invoiceData):
            invoiceCard(invoiceData)
        }
    }

    // MARK: - Extracted subviews to ease type-checking

    @ViewBuilder
    private func sessionCard(_ sessionData: SessionKanbanCardData) -> some View {
        let startText = sessionData.startTime?.formatted(date: .omitted, time: .shortened) ?? "-"
        let endText = sessionData.endTime?.formatted(date: .omitted, time: .shortened) ?? "-"
        // Strip spaces (including NBSP and narrow NBSP) from individual time strings
        let stripSpaces: (String) -> String = {
            $0
                .replacingOccurrences(of: "\u{00A0}", with: "") // NBSP
                .replacingOccurrences(of: "\u{202F}", with: "") // narrow NBSP
                .replacingOccurrences(of: " ", with: "")
        }
        let timeRange = "\(stripSpaces(startText)) - \(stripSpaces(endText))"
        let iconSize: CGFloat = 14

        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingSmall) {
            // Title
            HStack(spacing: 8) {
                Text(sessionData.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text)
                    .lineLimit(1)
            }

            // Client
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.72))
                    .frame(width: iconSize, height: iconSize, alignment: .center)
                Text(sessionData.clientName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.72))
                    .lineLimit(1)
            }

            // Service
            HStack(spacing: 6) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.72))
                    .frame(width: iconSize, height: iconSize, alignment: .center)
                Text(sessionData.serviceName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.72))
                    .lineLimit(1)
            }

            // Date
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.72))
                    .frame(width: iconSize, height: iconSize, alignment: .center)
                Text(sessionData.date)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.72))
            }

            // Time
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.72))
                    .frame(width: iconSize, height: iconSize, alignment: .center)
                Text(timeRange)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.72))
            }

            // Status (issues)
            if sessionData.hasIssues {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                        .frame(width: iconSize, height: iconSize, alignment: .center)
                    Text("Check")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pointerStyle((dragDropState.draggingSessionID == sessionData.sessionId) ? .closedHand : .openHand)
        .modifier(CardContainer())
        .modifier(CardHoverSelectionModifier(
            accent: sessionData.accentColor,
            isSelected: selectedCard?.id == cardData.id
        ))
        .onTapGesture {
            if selectedCard?.id == cardData.id {
                // Toggle off selection
                selectedCard = nil
                isEditingPanelVisible = false
            } else {
                selectedCard = cardData
                isEditingPanelVisible = true
            }
        }
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))
        .draggable(SessionDragPayload(sessionID: sessionData.sessionId, groupID: sessionData.groupID, column: sessionData.columnType)) {
            sessionDragPreview(sessionData)
        }
        .modifier(
            GroupingDropModifier(
                enable: enableGroupingDrop,
                targetID: sessionData.sessionId,
                onDrop: onDrop,
                isDragActive: dragDropState.isDragging,
                currentDraggedID: dragDropState.draggingSessionID,
                currentDraggedGroupID: dragDropState.draggingGroupID,
                targetGroupID: sessionData.groupID,
                accentColor: sessionData.accentColor
            )
        )
        .scaleEffect(dragDropState.draggingSessionID == sessionData.sessionId ? 0.98 : 1.0)
        .opacity(dragDropState.draggingSessionID == sessionData.sessionId ? 0.35 : 1.0)
        .transition(.scale.combined(with: .opacity))
        .animation(.easeInOut(duration: 0.12), value: dragDropState.draggingSessionID)
    }

    @ViewBuilder
    private func invoiceCard(_ invoiceData: InvoiceKanbanCardData) -> some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
            HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                Circle()
                    .fill(priorityColor.opacity(StyleGuide.Opacity.strong))
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 3, height: 3)
                    )

                Text(invoiceData.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text)
                    .lineLimit(1)

                Spacer()
            }

            HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                Text(invoiceData.clientName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.8))
                    .lineLimit(1)

                Spacer()

                Text(invoiceData.date)
                    .font(.system(size: 8, weight: .regular, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.6))
            }

            HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                Text(invoiceData.amount)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.9))

                Spacer()
            }
        }
        .modifier(CardContainer())
        .pointerStyle(.pointingHand)
        .modifier(CardHoverSelectionModifier(
            accent: invoiceData.accentColor,
            isSelected: selectedCard?.id == cardData.id
        ))
        .onTapGesture {
            if selectedCard?.id == cardData.id {
                selectedCard = nil
                isEditingPanelVisible = false
            } else {
                selectedCard = cardData
                isEditingPanelVisible = true
            }
        }
    }

    // Custom drag preview extracted to lighten body type-checking
    private func sessionDragPreview(_ sessionData: SessionKanbanCardData) -> some View {
        let startText = sessionData.startTime?.formatted(date: .omitted, time: .shortened) ?? "-"
        let endText = sessionData.endTime?.formatted(date: .omitted, time: .shortened) ?? "-"
        let timeRange = "\(startText) - \(endText)"

        return VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 8, height: 8)
                    Text(sessionData.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.text)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(sessionData.clientName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.text.opacity(0.8))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(timeRange)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.text.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
                    .fill(StyleGuide.Colors.background)
                    .stroke(sessionData.accentColor, lineWidth: 2)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            )

        .frame(width: 260, height: 84)
        .scaleEffect(0.5) // Scale down the drag preview for a lighter feel
        .onAppear {
            dragDropState.isDragging = true
            dragDropState.draggingSessionID = sessionData.sessionId
            dragDropState.draggingGroupID = sessionData.groupID
            dragDropState.draggingColumn = sessionData.columnType
        }
        .onDisappear {
            dragDropState.isDragging = false
            dragDropState.draggingSessionID = nil
            dragDropState.draggingGroupID = nil
            dragDropState.draggingColumn = nil
        }
    }

}


// MARK: - Unified card styling
private struct CardContainer: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(StyleGuide.Dimensions.paddingMedium)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
                    .fill(StyleGuide.Colors.background)
                    .stroke(StyleGuide.Colors.border, lineWidth: 1)
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
            )
    }
}

// MARK: - Hover + Selection styling for cards (non-drag state)
private struct CardHoverSelectionModifier: ViewModifier {
    var accent: Color
    var isSelected: Bool
    @EnvironmentObject private var dragDropState: DragDropState
    @State private var isHovered: Bool = false

    func body(content: Content) -> some View {
        let showHover = isHovered && !dragDropState.isDragging && !isSelected
        let shape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
        return content
            .overlay(
                ZStack {
                    if showHover {
                        shape.fill(Color.accentColor.opacity(0.06))
                    }
                    if isSelected {
                        shape.stroke(Color.accentColor, lineWidth: 1)
                    } else if showHover {
                        shape.stroke(Color.accentColor.opacity(0.8), lineWidth: 0.5)
                    }
                }
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
