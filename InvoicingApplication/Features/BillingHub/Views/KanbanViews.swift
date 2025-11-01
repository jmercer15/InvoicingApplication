//
//  KanbanViews.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import UniformTypeIdentifiers
 

// Shared drag/drop state to indicate when a drag session is active
final class DragDropState: ObservableObject {
    @Published var isDragging: Bool = false
    @Published var draggingSessionID: UUID? = nil
    @Published var draggingGroupID: UUID? = nil
    @Published var draggingColumn: KanbanCardData.BillingColumnType? = nil
    // Track when pointer is over a between-drop target to avoid parent intercepting
    @Published var hoveringBetween: Bool = false
    // Ensure only one drop target shows targeted styling at a time
    @Published var activeDropTargetKey: String? = nil
}

// (PointerStyle available on target; no conditional wrappers needed)

// MARK: - Typed drag payload for sessions
struct SessionDragPayload: Codable, Transferable, Equatable {
    let sessionID: UUID
    let groupID: UUID?
    let column: KanbanCardData.BillingColumnType

    static var transferRepresentation: some TransferRepresentation {
        // Use a built-in content type to avoid custom UTI plist declarations in previews.
        CodableRepresentation(contentType: .data)
    }
}

struct KanbanColumn: View {
    // Removed 'color' property, it can be derived from cards
    let cards: [KanbanCardData]
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
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
                // Suppress "before single" drop target when immediately following a group,
                // as the group's end-of-group target already covers that boundary.
                let suppressedBeforeIDs: Set<UUID> = {
                    var ids = Set<UUID>()
                    for item in clusters {
                        if case .group(_, let groupCards) = item {
                            if let nextUngrouped = KanbanColumn.firstUngroupedAfterGroup(cards: cards, lastGroupCardID: groupCards.last?.id) {
                                ids.insert(nextUngrouped)
                            }
                        }
                    }
                    return ids
                }()

                ForEach(clusters, id: \.id) { item in
                    switch item {
                    case .single(let card):
                        if enableReorderBetween, case .session = card, !suppressedBeforeIDs.contains(card.id) {
                            let ungroupedIDs: [UUID] = KanbanColumn.ungroupedIDs(in: cards)
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
                            // External padding for ungrouped cards inside the Grouped subcolumn
                            .padding(.horizontal, StyleGuide.Dimensions.paddingLarge * 0.5)
                    case .group(let groupID, let groupCards):
                        let groupAccent = KanbanColumn.groupAccentColor(for: groupCards)
                        // Outside-above target (between clusters): drop here to insert into ungrouped scope before this group cluster
                        if enableReorderBetween {
                            let groupFirstID = groupCards.first?.id
                            let ungroupedIDs = KanbanColumn.ungroupedIDs(in: cards)
                            let insertionIndex: Int? = KanbanColumn.ungroupedInsertionIndexBeforeGroup(cards: cards, firstGroupCardID: groupFirstID)
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
                        }
                        VStack(alignment: .leading, spacing: 0) {
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
                                            .fill(groupAccent.opacity(0.18))
                                            .overlay(
                                                Capsule()
                                                    .stroke(groupAccent.opacity(0.45), lineWidth: 0.5)
                                            )
                                    )
                            }
                            .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
                            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                            .background(
                                Capsule()
                                    .fill(groupAccent.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .stroke(groupAccent, lineWidth: 0.5)
                                    )
                            )

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
                            // End-of-group drop target
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
                        // Use exactly half of the subcolumn's internal horizontal padding; vertical is half of 0 = 0
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
                        .id(groupID)

                        // No outside-below target to prevent adjacent BetweenDropTargets; end-of-group target covers appending to the group.
                    }
                }
            } else {
                ForEach(cards) { cardData in
                    if enableReorderBetween, case .session = cardData {
                        BetweenDropTarget(
                            accentColor: betweenAccentColor,
                            targetHeight: cardHeights[cardData.id] ?? typicalCardHeight,
                            scopeIDs: KanbanColumn.groupCardIDs(in: cards),
                            insertionIndex: KanbanColumn.groupCardIDs(in: cards).firstIndex(of: cardData.id),
                            onDrop: { sourceID in
                                onReorderBetween?(sourceID, cardData.id, nil) ?? false
                            }
                        )
                    }
                    MeasuredCard(id: cardData.id) { row(for: cardData) }
                        // External horizontal padding to mirror grouped singles
                        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge * 0.5)
                        // When there are no BetweenDropTargets, add vertical spacing equal to the
                        // unhovered height of a BetweenDropTarget (10pt) to separate cards.
                        .padding(.vertical, enableReorderBetween ? 0 : 10)
                }
                // End-of-column drop target (append to end of scope)
                if enableReorderBetween {
                    BetweenDropTarget(
                        accentColor: betweenAccentColor,
                        targetHeight: typicalCardHeight,
                        scopeIDs: KanbanColumn.groupCardIDs(in: cards),
                        insertionIndex: KanbanColumn.groupCardIDs(in: cards).count,
                        onDrop: { sourceID in
                            onReorderBetween?(sourceID, nil, nil) ?? false
                        }
                    )
                }
            }
            // Removed Spacer to avoid extra trailing space below cards
        }
        .padding(.vertical, 0)
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge * 0.5)
        .modifier(ColumnDropModifier(enable: enableGroupingDrops, onDrop: onDropOnColumn, isDragActive: dragDropState.isDragging))
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.1), value: cards.map { $0.id })
        .onPreferenceChange(CardHeightPreferenceKey.self) { values in
            // Merge measured heights; prefer latest values
            for (k, v) in values { cardHeights[k] = v }
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

// MARK: - Between drop target for reordering
private struct BetweenDropTarget: View {
    var accentColor: Color
    var targetHeight: CGFloat?
    // Provide scope and intended insertion directly; internal logic computes adjacency
    var scopeIDs: [UUID]? = nil
    var insertionIndex: Int? = nil
    var onDrop: (UUID) -> Bool
    @EnvironmentObject private var dragDropState: DragDropState
    @State private var isTargeted: Bool = false
    @State private var targetKey: String = UUID().uuidString
    private let placeholderHeight: CGFloat = 84 // approximate card height
    private var isValidHover: Bool {
        guard let scopeIDs, let insertionIndex,
              let src = dragDropState.draggingSessionID,
              let sIndex = scopeIDs.firstIndex(of: src) else { return true }
        return !KanbanColumn.isNoOpReorder(sourceIndex: sIndex, insertionIndex: insertionIndex)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
            .fill((isTargeted && isValidHover) ? accentColor.opacity(StyleGuide.Opacity.subtle) : Color.clear)
            .stroke((isTargeted && isValidHover) ? Color.accentColor : Color.clear, style: StrokeStyle(lineWidth: (isTargeted && isValidHover) ? 1 : 0, dash: [6, 3]))
            .transition(.opacity.combined(with: .scale))
            .frame(height: (isTargeted && isValidHover) ? placeholderHeight : 10)
            .padding(.vertical, (isTargeted && isValidHover) ? 10 : 0)
            .pointerStyle(.rectSelection)
            .dropDestination(for: SessionDragPayload.self) { items, _ in
                guard let item = items.first else { return false }
                // Do not block drops based on local validation; let the view model no-op invalid moves
                var ok = false
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    ok = onDrop(item.sessionID)
                }
                if ok {
                    isTargeted = false
                    dragDropState.isDragging = false
                    dragDropState.hoveringBetween = false
                    dragDropState.activeDropTargetKey = nil
                }
                return ok
            } isTargeted: { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    if hovering {
                        dragDropState.activeDropTargetKey = targetKey
                        isTargeted = true
                    } else {
                        if dragDropState.activeDropTargetKey == targetKey { dragDropState.activeDropTargetKey = nil }
                        isTargeted = false
                    }
                    dragDropState.hoveringBetween = hovering
                }
            }
            .zIndex(isTargeted ? 2 : 1)
            .onDisappear { dragDropState.hoveringBetween = false }
            .onChange(of: dragDropState.activeDropTargetKey) { _, newVal in
                if newVal != targetKey { isTargeted = false }
            }
            .onChange(of: dragDropState.isDragging) { _, newVal in
                if newVal == false {
                    isTargeted = false
                    dragDropState.hoveringBetween = false
                }
            }
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
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Autoscroll on drag for ScrollViews (macOS)
private struct ScrollViewIntrospector: NSViewRepresentable {
    var onResolve: (NSScrollView) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let scroll = view?.enclosingScrollView { onResolve(scroll) }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            if let scroll = nsView?.enclosingScrollView { onResolve(scroll) }
        }
    }
}

public struct AutoScrollOnDrag: ViewModifier {
    var enable: Bool = true
    var speed: CGFloat = 260 // points per second
    @EnvironmentObject private var dragDropState: DragDropState
    @State private var scrollView: NSScrollView?
    @State private var topActive = false
    @State private var bottomActive = false
    @State private var timer: Timer?

    func body(content: Content) -> some View {
        ZStack {
            content
                .overlay(alignment: .top) {
                    AutoScrollZone(height: 40, direction: .up) { active in
                        topActive = active
                        updateTimer()
                    }
                    .allowsHitTesting(enable)
                }
                .overlay(alignment: .bottom) {
                    AutoScrollZone(height: 40, direction: .down) { active in
                        bottomActive = active
                        updateTimer()
                    }
                    .allowsHitTesting(enable)
                }
                .background(ScrollViewIntrospector { sv in self.scrollView = sv })
        }
        .onChange(of: dragDropState.isDragging) { _, dragging in
            if dragging == false { stopTimer() }
        }
    }

    private func updateTimer() {
        guard enable, dragDropState.isDragging else { stopTimer(); return }
        if topActive || bottomActive {
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
                    stepScroll()
                }
            }
        } else {
            stopTimer()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func stepScroll() {
        guard let sv = scrollView else { return }
        guard let docView = sv.documentView else { return }
        let clip = sv.contentView
        var origin = clip.bounds.origin
        let maxY = max(0, docView.bounds.height - clip.bounds.height)
        let delta: CGFloat = (speed / 60.0) * (topActive ? -1 : (bottomActive ? 1 : 0))
        origin.y = min(max(0, origin.y + delta), maxY)
        clip.setBoundsOrigin(origin)
        sv.reflectScrolledClipView(clip)
    }
}

private enum AutoScrollDirection { case up, down }

private struct AutoScrollZone: View {
    var height: CGFloat
    var direction: AutoScrollDirection
    var onActiveChange: (Bool) -> Void
    @EnvironmentObject private var dragDropState: DragDropState
    @State private var isTargeted = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: height)
            .contentShape(Rectangle())
            .dropDestination(for: SessionDragPayload.self) { _, _ in false } isTargeted: { hovering in
                isTargeted = hovering
                onActiveChange(hovering)
            }
            .allowsHitTesting(dragDropState.isDragging)
    }
}

#Preview("KanbanColumn") {
    KanbanColumn_Preview()
}
}

// No-op fallback so usage sites can always reference the modifier cross-platform
struct AutoScrollOnDrag: ViewModifier {
    func body(content: Content) -> some View { content }
}

// MARK: - Grouping helpers for KanbanColumn
private enum KanbanRenderItem: Identifiable {
    case single(card: KanbanCardData)
    case group(id: UUID, cards: [KanbanCardData])

    var id: UUID {
        switch self {
        case .single(let card): return card.id
        case .group(let id, _): return id
        }
    }
}

private extension KanbanColumn {
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
private struct GroupingDropModifier: ViewModifier {
    let enable: Bool
    let targetID: UUID
    let onDrop: ((UUID, UUID) -> Bool)?
    let isDragActive: Bool
    let currentDraggedID: UUID?
    let currentDraggedGroupID: UUID?
    let targetGroupID: UUID?
    let accentColor: Color
    @State private var isTargeted: Bool = false
    @State private var didDrop: Bool = false
    @EnvironmentObject private var dragDropState: DragDropState
    @State private var targetKey: String = UUID().uuidString

    func body(content: Content) -> some View {
        if enable, let onDrop {
            let isSameGroup = (currentDraggedGroupID != nil && currentDraggedGroupID == targetGroupID)
            let amActive = (dragDropState.activeDropTargetKey == targetKey)
            let validHover = (isTargeted && amActive && currentDraggedID != targetID && !isSameGroup)
            content
                .background(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
                        .fill(accentColor.opacity(validHover ? StyleGuide.Opacity.light : (isDragActive ? StyleGuide.Opacity.subtle : 0)))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: validHover ? 2 : 1, dash: [6, 3]))
                        .opacity(validHover ? 1 : (isDragActive ? StyleGuide.Opacity.faint : 0))
                        .allowsHitTesting(false)
                )
                // Indicate a precise drop target when hovering a valid card
                .pointerStyle(validHover ? .rectSelection : .default)

                // Drop glyph
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(accentColor)
                        .padding(6)
                        .opacity(validHover ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .scaleEffect(didDrop ? 0.98 : 1.0)
                .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: isTargeted)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: didDrop)
                .dropDestination(
                    for: SessionDragPayload.self,
                    action: { items, _ in
                        guard let item = items.first else { return false }
                        let sourceID = item.sessionID
                        // Prevent dropping onto itself
                        guard sourceID != targetID else {
                            // Clear any lingering highlight on invalid self-drop
                            isTargeted = false
                            dragDropState.activeDropTargetKey = nil
                            dragDropState.isDragging = false
                            return false
                        }
                        // Prevent no-op drops within the same group
                        if isSameGroup {
                            // Clear highlight when rejecting drop in same group (use between-target for reorder)
                            isTargeted = false
                            dragDropState.activeDropTargetKey = nil
                            dragDropState.isDragging = false
                            return false
                        }
                        var ok = false
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            ok = onDrop(sourceID, targetID)
                        }
                        if ok {
                            didDrop = true
                            isTargeted = false
                            dragDropState.isDragging = false
                            dragDropState.activeDropTargetKey = nil
                            // best-effort: notify global state
                            // (dragDropState env is not available here; consolidated elsewhere)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                didDrop = false
                            }
                        }
                        return ok
                    },
                    isTargeted: { hovering in
                        // Do not show target state when hovering the same card
                        if let currentDraggedID, currentDraggedID == targetID {
                            isTargeted = false
                            return
                        }
                        if hovering {
                            dragDropState.activeDropTargetKey = targetKey
                            isTargeted = true
                        } else {
                            if dragDropState.activeDropTargetKey == targetKey { dragDropState.activeDropTargetKey = nil }
                            isTargeted = false
                        }
                    }
                )
                .onChange(of: isTargeted) { _, newVal in
                    if newVal == false { /* cleared */ }
                }
                .onChange(of: dragDropState.activeDropTargetKey) { _, newVal in
                    if newVal != targetKey { isTargeted = false }
                }
                .onChange(of: dragDropState.isDragging) { _, newVal in
                    if newVal == false { isTargeted = false }
                }
        } else {
            content
        }
    }
}

// Column-wide drop handler (e.g., drop into empty area to move to Grouped)
private struct ColumnDropModifier: ViewModifier {
    let enable: Bool
    let onDrop: ((UUID) -> Bool)?
    let isDragActive: Bool
    @State private var isTargeted: Bool = false
    @EnvironmentObject private var dragDropState: DragDropState
    @State private var targetKey: String = UUID().uuidString

    func body(content: Content) -> some View {
        if enable, let onDrop {
            content
                .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))
                .background(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
                        .fill(StyleGuide.Colors.primary.opacity((isTargeted && (dragDropState.activeDropTargetKey == targetKey)) ? StyleGuide.Opacity.light : (isDragActive ? StyleGuide.Opacity.subtle : 0)))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: (isTargeted && (dragDropState.activeDropTargetKey == targetKey)) ? 2 : 1, dash: [6, 3]))
                        .opacity((isTargeted && (dragDropState.activeDropTargetKey == targetKey)) ? 1 : (isDragActive ? StyleGuide.Opacity.faint : 0))

                )
                // Signal full-column drop area when hovered during a drag
                .pointerStyle((isTargeted && (dragDropState.activeDropTargetKey == targetKey)) ? .rectSelection : .default)
                .scaleEffect(isTargeted ? 1.01 : 1.0)
                .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: isTargeted)
                .dropDestination(
                    for: SessionDragPayload.self,
                    action: { items, _ in
                        guard let item = items.first else { return false }
                        // Disallow background drops on the Grouped column when dragging an ungrouped Grouped card
                        if dragDropState.draggingColumn == .grouped && dragDropState.draggingGroupID == nil {
                            isTargeted = false
                            if dragDropState.activeDropTargetKey == targetKey { dragDropState.activeDropTargetKey = nil }
                            return false
                        }
                        var ok = false
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            ok = onDrop(item.sessionID)
                        }
                        if ok {
                            isTargeted = false
                            dragDropState.isDragging = false
                            dragDropState.activeDropTargetKey = nil
                        }
                        return ok
                    },
                    isTargeted: { hovering in
                        let eligibleHover = !(dragDropState.draggingColumn == .grouped && dragDropState.draggingGroupID == nil)
                        if hovering && eligibleHover {
                            dragDropState.activeDropTargetKey = targetKey
                            isTargeted = true
                        } else {
                            if dragDropState.activeDropTargetKey == targetKey { dragDropState.activeDropTargetKey = nil }
                            isTargeted = false
                        }
                    }
                )
                .onChange(of: dragDropState.isDragging) { _, newVal in
                    if newVal == false { isTargeted = false }
                }
                .onChange(of: dragDropState.activeDropTargetKey) { _, newVal in
                    if newVal != targetKey { isTargeted = false }
                }
        } else {
            content
        }
    }
}

// Full-area drop handler intended for applying to a ScrollView so the
// entire visible subcolumn acts as a drop target, not just the content height.
struct FullAreaDropModifier: ViewModifier {
    let enable: Bool
    let onDrop: ((UUID) -> Bool)?
    var isEligible: ((DragDropState) -> Bool)? = nil
    var accentColor: Color = StyleGuide.Colors.primary
    var labelProvider: ((DragDropState) -> String?)? = nil
    @EnvironmentObject private var dragDropState: DragDropState
    @State private var isTargeted: Bool = false
    @State private var didDrop: Bool = false

    func body(content: Content) -> some View {
        if enable, let onDrop {
            let eligible = isEligible?(dragDropState) ?? true
            content
                .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium))
                .background(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
                        .fill(accentColor.opacity(isTargeted && eligible ? StyleGuide.Opacity.light : ((dragDropState.isDragging && eligible) ? StyleGuide.Opacity.subtle : 0)))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: isTargeted && eligible ? 2 : 1, dash: [6, 3]))
                        .opacity(isTargeted && eligible ? 1 : ((dragDropState.isDragging && eligible) ? StyleGuide.Opacity.faint : 0))
                        .allowsHitTesting(false)
                )
                // Use a selection-style cursor to indicate dropping into the column
                .pointerStyle((isTargeted && eligible) ? .rectSelection : .default)
                .overlay(
                    Group {
                        if (dragDropState.isDragging && eligible && isTargeted) {
                            if let label = labelProvider?(dragDropState) {
                                Text(label)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.white.opacity(0.9)))
                                    .foregroundColor(.black)
                                    .opacity(isTargeted ? 1 : 0.0)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                )
                .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: isTargeted)
                .dropDestination(
                    for: SessionDragPayload.self,
                    action: { items, _ in
                        guard eligible else { return false }
                        guard let item = items.first else { return false }
                        var ok = false
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            ok = onDrop(item.sessionID)
                        }
                        if ok {
                            didDrop = true
                            // Ensure any floating label/highlight clears once drop completes
                            isTargeted = false
                            // Proactively end the global dragging state to clean up overlays
                            dragDropState.isDragging = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { didDrop = false }
                        }
                        return ok
                    },
                    isTargeted: { hovering in
                        isTargeted = hovering
                    }
                )
                // If a drag session ends elsewhere, ensure the targeted state clears here
                .onChange(of: dragDropState.isDragging) { _, newVal in
                    if newVal == false { isTargeted = false }
                }
        } else {
            content
        }
    }
}
