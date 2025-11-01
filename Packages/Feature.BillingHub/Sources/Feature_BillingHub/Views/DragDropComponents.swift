//
//  DragDropComponents.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import SharedUI

// MARK: - Drag & Drop State Management

// Shared drag/drop state to indicate when a drag session is active
final class DragDropState: ObservableObject {
    @Published var isDragging: Bool = false
    @Published var draggingSessionID: UUID? = nil
    @Published var draggingGroupID: UUID? = nil
    @Published var draggingColumn: KanbanCardData.BillingColumnType? = nil
    @Published var isGroupDrag: Bool = false
    // Track when pointer is over a between-drop target to avoid parent intercepting
    @Published var hoveringBetween: Bool = false
    // Ensure only one drop target shows targeted styling at a time
    @Published var activeDropTargetKey: String? = nil
}

// MARK: - Drag Payloads

struct SessionDragPayload: Codable, Transferable, Equatable {
    let sessionID: UUID
    let groupID: UUID?
    let column: KanbanCardData.BillingColumnType

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

struct GroupDragPayload: Codable, Transferable, Equatable {
    let groupID: UUID
    let column: KanbanCardData.BillingColumnType

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
        CodableRepresentation(contentType: UTType(exportedAs: "com.invoicingapplication.billinghub.group"))
    }
}

// MARK: - DragDropState Extensions

extension DragDropState {
    func apply(_ payload: SessionDragPayload) {
        draggingSessionID = payload.sessionID
        draggingGroupID = payload.groupID
        draggingColumn = payload.column
        isGroupDrag = false
    }

    func apply(_ payload: GroupDragPayload) {
        draggingSessionID = nil
        draggingGroupID = payload.groupID
        draggingColumn = payload.column
        isGroupDrag = true
    }

    func clearContext() {
        draggingSessionID = nil
        draggingGroupID = nil
        draggingColumn = nil
        isGroupDrag = false
        hoveringBetween = false
        activeDropTargetKey = nil
    }
}

// MARK: - Between Drop Target for Reordering

struct BetweenDropTarget: View {
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

// MARK: - Auto-scroll on Drag for ScrollViews (macOS)

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

    public func body(content: Content) -> some View {
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

// MARK: - Drop Modifiers

struct GroupingDropModifier: ViewModifier {
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

// Column-wide drop handler (e.g., drop into empty space to move to Grouped)
struct ColumnDropModifier: ViewModifier {
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
    let onDrop: ((UUID, DragDropState) -> Bool)?
    let onGroupDrop: ((UUID, DragDropState) -> Bool)?
    var isEligible: ((DragDropState) -> Bool)?
    var accentColor: Color
    var labelProvider: ((DragDropState) -> String?)?
    @EnvironmentObject private var dragDropState: DragDropState
    @State private var isTargeted: Bool = false
    @State private var didDrop: Bool = false
    @State private var targetKey: String = UUID().uuidString

    init(
        enable: Bool,
        onDrop: ((UUID, DragDropState) -> Bool)?,
        onGroupDrop: ((UUID, DragDropState) -> Bool)? = nil,
        isEligible: ((DragDropState) -> Bool)? = nil,
        accentColor: Color = StyleGuide.Colors.primary,
        labelProvider: ((DragDropState) -> String?)? = nil
    ) {
        self.enable = enable
        self.onDrop = onDrop
        self.onGroupDrop = onGroupDrop
        self.isEligible = isEligible
        self.accentColor = accentColor
        self.labelProvider = labelProvider
    }

    func body(content: Content) -> some View {
        if enable, (onDrop != nil || onGroupDrop != nil) {
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
                        guard eligible, let handler = onDrop else { return false }
                        guard let item = items.first else { return false }
                        dragDropState.apply(item)
                        var ok = false
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            ok = handler(item.sessionID, dragDropState)
                        }
                        if ok {
                            didDrop = true
                            isTargeted = false
                            dragDropState.isDragging = false
                            dragDropState.clearContext()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { didDrop = false }
                        }
                        return ok
                    },
                    isTargeted: { hovering in
                        isTargeted = hovering
                    }
                )
                .dropDestination(for: GroupDragPayload.self) { items, _ in
                    guard eligible, let handler = onGroupDrop else { return false }
                    guard let item = items.first else { return false }
                    dragDropState.apply(item)
                    var ok = false
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        ok = handler(item.groupID, dragDropState)
                    }
                    if ok {
                        didDrop = true
                        isTargeted = false
                        dragDropState.isDragging = false
                        dragDropState.clearContext()
                        if dragDropState.activeDropTargetKey == targetKey {
                            dragDropState.activeDropTargetKey = nil
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { didDrop = false }
                    }
                    return ok
                } isTargeted: { hovering in
                    if hovering && onGroupDrop != nil && eligible {
                        dragDropState.activeDropTargetKey = targetKey
                        isTargeted = true
                    } else {
                        if dragDropState.activeDropTargetKey == targetKey {
                            dragDropState.activeDropTargetKey = nil
                        }
                        isTargeted = false
                    }
                }
                .onChange(of: dragDropState.isDragging) { _, newVal in
                    if newVal == false { isTargeted = false }
                }
        } else {
            content
        }
    }
}

// MARK: - Drag Preview Views

struct GroupDragPreviewView: View {
    let groupID: UUID
    let cards: [KanbanCardData]
    let accent: Color
    let column: KanbanCardData.BillingColumnType
    let dragDropState: DragDropState

    private var entries: [(String, String)] {
        cards.prefix(3).compactMap { card -> (String, String)? in
            switch card {
            case .session(let data):
                return (data.title, data.clientName)
            case .invoice(let data):
                return (data.title, data.clientName)
            }
        }
    }

    private var overflowCount: Int {
        max(0, cards.count - entries.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
                Text("Group")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text)
                Text("\(cards.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.7))
            }

            ForEach(entries, id: \.0) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.0)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.text)
                        .lineLimit(1)
                    Text(entry.1)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(StyleGuide.Colors.text.opacity(0.75))
                        .lineLimit(1)
                }
            }

            if overflowCount > 0 {
                Text("+\(overflowCount) more")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(StyleGuide.Colors.text.opacity(0.6))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
                .fill(StyleGuide.Colors.background)
                .stroke(accent, lineWidth: 2)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .frame(width: 260)
        .scaleEffect(0.5)
        .onAppear {
            dragDropState.isDragging = true
            dragDropState.draggingSessionID = nil
            dragDropState.draggingGroupID = groupID
            dragDropState.draggingColumn = column
            dragDropState.isGroupDrag = true
        }
        .onDisappear {
            dragDropState.isDragging = false
            dragDropState.clearContext()
        }
    }
}
