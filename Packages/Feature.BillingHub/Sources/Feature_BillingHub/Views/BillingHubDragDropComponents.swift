//
//  BillingHubDragDropComponents.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import UniformTypeIdentifiers

// Custom UTIs for BillingHub drag and drop
extension UTType {
    static let sessionID = UTType(exportedAs: "com.example.session-id")
    static let invoiceID = UTType(exportedAs: "com.example.invoice-id")
    static let groupID = UTType(exportedAs: "com.example.group-id")
}

// MARK: - Group Data Structure
struct SessionGroup: Identifiable, Equatable {
    let id: UUID
    let sessions: [KanbanCardData]
    let groupID: UUID?
    
    init(groupID: UUID?, sessions: [KanbanCardData]) {
        self.id = groupID ?? UUID() // Use groupID as the group's ID, or generate new one
        self.groupID = groupID
        self.sessions = sessions
    }
    
    var title: String {
        if sessions.count == 1 {
            switch sessions.first {
            case .session(let data):
                return data.title
            case .invoice(let data):
                return data.title
            case .none:
                return "Group"
            }
        } else {
            return "Group (\(sessions.count) sessions)"
        }
    }
    
    var subtitle: String {
        if let firstSession = sessions.first {
            switch firstSession {
            case .session(let data):
                return "\(data.clientName) • \(data.serviceName)"
            case .invoice(let data):
                return "\(data.clientName) • \(data.amount)"
            }
        }
        return "Multiple sessions"
    }
    
    var accentColor: Color {
        switch sessions.first {
        case .session(let data):
            return data.accentColor
        case .invoice(let data):
            return data.accentColor
        case .none:
            return .blue
        }
    }
}

// MARK: - Helper Functions
private func loadID(from providers: [NSItemProvider], typeIdentifier: String, handle: @escaping (UUID) -> Void) -> Bool {
    guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(typeIdentifier) }) else {
        return false
    }
    
    provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
        guard let data = data,
              let s = String(data: data, encoding: .utf8),
              let id = UUID(uuidString: s) else { return }
        DispatchQueue.main.async { handle(id) }
    }
    return true
}

private func loadSessionID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
    loadID(from: providers, typeIdentifier: UTType.sessionID.identifier, handle: handle)
}

private func loadInvoiceID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
    loadID(from: providers, typeIdentifier: UTType.invoiceID.identifier, handle: handle)
}

private func loadGroupID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
    loadID(from: providers, typeIdentifier: UTType.groupID.identifier, handle: handle)
}

private func createDragProvider(for id: UUID, typeIdentifier: String) -> NSItemProvider {
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier, visibility: .all) { completion in
        completion(id.uuidString.data(using: .utf8), nil)
        return nil
    }
    return provider
}


// MARK: - Grouped Kanban Column (specialized for groups)
struct GroupedKanbanColumn: View {
    let groups: [SessionGroup]
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let columnType: KanbanCardData.BillingColumnType
    let onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let onAddSessionToGroup: (UUID, UUID) -> Void // (sessionID, groupID)
    let canAddSessionToGroup: (UUID, UUID) -> Bool // (sessionID, groupID) -> canAdd
    let betweenAccentColor: Color
    
    @State private var targetedItemID: UUID?
    @State private var isBottomTargeted = false
    
    init(
        groups: [SessionGroup],
        selectedCard: Binding<KanbanCardData?>,
        isEditingPanelVisible: Binding<Bool>,
        columnType: KanbanCardData.BillingColumnType,
        onReorderBetween: @escaping (UUID, UUID?, UUID?) -> Bool,
        onDropOnCard: ((UUID, UUID) -> Bool)? = nil,
        onAddSessionToGroup: @escaping (UUID, UUID) -> Void,
        canAddSessionToGroup: @escaping (UUID, UUID) -> Bool,
        betweenAccentColor: Color
    ) {
        self.groups = groups
        self._selectedCard = selectedCard
        self._isEditingPanelVisible = isEditingPanelVisible
        self.columnType = columnType
        self.onReorderBetween = onReorderBetween
        self.onDropOnCard = onDropOnCard
        self.onAddSessionToGroup = onAddSessionToGroup
        self.canAddSessionToGroup = canAddSessionToGroup
        self.betweenAccentColor = betweenAccentColor
    }
    
    var body: some View {
        List {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                groupItemView(for: group, at: index)
            }
            
            bottomDropZone
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.2))
        )
    }
    
    private func groupItemView(for group: SessionGroup, at index: Int) -> some View {
        GroupItemWrapper(
            group: group,
            targetedItemID: $targetedItemID,
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible,
            columnType: columnType,
            onReorderBetween: onReorderBetween,
            onDropOnCard: onDropOnCard,
            onAddSessionToGroup: onAddSessionToGroup,
            canAddSessionToGroup: canAddSessionToGroup,
            shouldHighlightSeparator: shouldHighlightSeparator(for: group, at: index)
        )
    }
    
    private var bottomDropZone: some View {
        BillingHubBottomDropZone(isTargeted: .constant(targetedItemID == nil && isBottomTargeted))
        .onDrop(of: [UTType.sessionID.identifier, UTType.invoiceID.identifier, UTType.groupID.identifier], isTargeted: $isBottomTargeted) { providers in
            // Handle bottom drop - append to end
            if loadSessionID(from: providers, handle: { _ = onReorderBetween($0, nil, nil) }) ||
               loadInvoiceID(from: providers, handle: { _ = onReorderBetween($0, nil, nil) }) ||
               loadGroupID(from: providers, handle: { _ = onReorderBetween($0, nil, nil) }) {
                return true
            }
            return false
        }
            .onChange(of: isBottomTargeted) { isTargeted in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isTargeted {
                        targetedItemID = nil // Clear item targeting when targeting bottom
                    }
                }
            }
    }
    
    private func shouldHighlightSeparator(for group: SessionGroup, at index: Int) -> Bool {
        guard let targetedID = targetedItemID else { return false }
        
        // Highlight this group's separator (which appears below this group) 
        // only if the NEXT group is the one being targeted for insertion
        if index < groups.count - 1 {
            let nextGroup = groups[index + 1]
            if nextGroup.id == targetedID {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Group Item Wrapper
struct GroupItemWrapper: View {
    let group: SessionGroup
    @Binding var targetedItemID: UUID?
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let columnType: KanbanCardData.BillingColumnType
    let onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let onAddSessionToGroup: (UUID, UUID) -> Void // (sessionID, groupID)
    let canAddSessionToGroup: (UUID, UUID) -> Bool // (sessionID, groupID) -> canAdd
    let shouldHighlightSeparator: Bool
    @State private var isItemTargeted = false
    
    var body: some View {
        GroupCardView(
            group: group,
            isSelected: .constant(selectedCard?.id == group.id),
            onTap: {
                // Select the first session in the group
                if let firstSession = group.sessions.first {
                    selectedCard = firstSession
                    isEditingPanelVisible = true
                }
            },
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible,
            onAddSessionToGroup: onAddSessionToGroup,
            canAddSessionToGroup: canAddSessionToGroup
        )
        .onDrop(of: [UTType.sessionID.identifier, UTType.invoiceID.identifier, UTType.groupID.identifier], isTargeted: $isItemTargeted) { providers in
            let handleDrop: (UUID) -> Void = { id in
                if let onDropOnCard = onDropOnCard {
                    _ = onDropOnCard(id, group.id)
                } else {
                    _ = onReorderBetween(id, group.id, nil)
                }
            }
            
            return loadSessionID(from: providers, handle: handleDrop) ||
                   loadInvoiceID(from: providers, handle: handleDrop) ||
                   loadGroupID(from: providers, handle: handleDrop)
        }
        .onChange(of: isItemTargeted) { isTargeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                targetedItemID = isTargeted ? group.id : nil
            }
        }
        .listRowSeparator(.visible)
        .listRowSeparatorTint(shouldHighlightSeparator ? Color.blue : .gray.opacity(0.3))
    }
}

// MARK: - Custom Kanban Column
struct CustomKanbanColumn: View {
    let cards: [KanbanCardData]
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let columnType: KanbanCardData.BillingColumnType
    let onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let betweenAccentColor: Color
    let enableGroupingDrops: Bool
    
    @State private var targetedItemID: UUID?
    @State private var isBottomTargeted = false
    
    init(
        cards: [KanbanCardData],
        selectedCard: Binding<KanbanCardData?>,
        isEditingPanelVisible: Binding<Bool>,
        columnType: KanbanCardData.BillingColumnType,
        onReorderBetween: @escaping (UUID, UUID?, UUID?) -> Bool,
        onDropOnCard: ((UUID, UUID) -> Bool)? = nil,
        betweenAccentColor: Color,
        enableGroupingDrops: Bool = false
    ) {
        self.cards = cards
        self._selectedCard = selectedCard
        self._isEditingPanelVisible = isEditingPanelVisible
        self.columnType = columnType
        self.onReorderBetween = onReorderBetween
        self.onDropOnCard = onDropOnCard
        self.betweenAccentColor = betweenAccentColor
        self.enableGroupingDrops = enableGroupingDrops
    }
    
    var body: some View {
        List {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                cardItemView(for: card, at: index)
            }
            
            bottomDropZone
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.2))
        )
    }
    
    private func cardItemView(for card: KanbanCardData, at index: Int) -> some View {
        CardItemWrapper(
            card: card,
            targetedItemID: $targetedItemID,
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible,
            columnType: columnType,
            onReorderBetween: onReorderBetween,
            onDropOnCard: onDropOnCard,
            shouldHighlightSeparator: shouldHighlightSeparator(for: card, at: index)
        )
    }
    
    private var bottomDropZone: some View {
        BillingHubBottomDropZone(isTargeted: .constant(targetedItemID == nil && isBottomTargeted))
            .onDrop(of: [UTType.sessionID.identifier, UTType.invoiceID.identifier], isTargeted: $isBottomTargeted) { providers in
                // Handle bottom drop - append to end
                if let sessionProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.sessionID.identifier) }) {
                    loadSessionID(from: [sessionProvider]) { sessionID in
                        _ = onReorderBetween(sessionID, nil, nil) // Append to end
                    }
                } else if let invoiceProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.invoiceID.identifier) }) {
                    loadInvoiceID(from: [invoiceProvider]) { invoiceID in
                        _ = onReorderBetween(invoiceID, nil, nil) // Append to end
                    }
                }
                return true
            }
            .onChange(of: isBottomTargeted) { isTargeted in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isTargeted {
                        targetedItemID = nil // Clear item targeting when targeting bottom
                    }
                }
            }
    }
    
    private func shouldHighlightSeparator(for card: KanbanCardData, at index: Int) -> Bool {
        guard let targetedID = targetedItemID else { return false }
        
        // Highlight this card's separator (which appears below this card) 
        // only if the NEXT card is the one being targeted for insertion
        if index < cards.count - 1 {
            let nextCard = cards[index + 1]
            if nextCard.id == targetedID {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Card Item Wrapper
struct CardItemWrapper: View {
    let card: KanbanCardData
    @Binding var targetedItemID: UUID?
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let columnType: KanbanCardData.BillingColumnType
    let onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let shouldHighlightSeparator: Bool
    @State private var isItemTargeted = false
    
    var body: some View {
        KanbanCardView(
            card: card,
            isSelected: .constant(selectedCard?.id == card.id),
            onTap: {
                selectedCard = card
                isEditingPanelVisible = true
            }
        )
        .onDrop(of: [UTType.sessionID.identifier, UTType.invoiceID.identifier], isTargeted: $isItemTargeted) { providers in
            if let sessionProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.sessionID.identifier) }) {
                loadSessionID(from: [sessionProvider]) { sessionID in
                    if let onDropOnCard = onDropOnCard {
                        // Handle drop on card (e.g., grouping)
                        _ = onDropOnCard(sessionID, card.id)
                    } else {
                        // Handle insertion above this card
                        _ = onReorderBetween(sessionID, card.id, nil)
                    }
                }
            } else if let invoiceProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.invoiceID.identifier) }) {
                loadInvoiceID(from: [invoiceProvider]) { invoiceID in
                    if let onDropOnCard = onDropOnCard {
                        // Handle drop on card (e.g., grouping)
                        _ = onDropOnCard(invoiceID, card.id)
                    } else {
                        // Handle insertion above this card
                        _ = onReorderBetween(invoiceID, card.id, nil)
                    }
                }
            }
            return true
        }
        .onChange(of: isItemTargeted) { isTargeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                targetedItemID = isTargeted ? card.id : nil
            }
        }
        .listRowSeparator(.visible)
        .listRowSeparatorTint(shouldHighlightSeparator ? Color.blue : .gray.opacity(0.3))
    }
}

// MARK: - Session Drop Zone (for adding sessions to groups)
struct SessionDropZone: View {
    let onAdd: (UUID) -> Void
    let groupID: UUID
    @State private var isTargeted = false
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Plus icon indicator
            Image(systemName: "plus")
                .font(.caption2)
                .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.6))
            
            Text(isTargeted ? "Drop session here" : "Add session...")
                .font(.caption)
                .fontWeight(isTargeted ? .bold : .medium)
                .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.7))
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.blue.opacity(0.1) : (isHovering ? Color(.controlBackgroundColor).opacity(0.8) : Color(.controlBackgroundColor).opacity(0.6)))
                .shadow(
                    color: isTargeted ? .blue.opacity(0.2) : (isHovering ? .black.opacity(0.05) : .black.opacity(0.03)),
                    radius: isTargeted ? 3 : (isHovering ? 1 : 0.5),
                    x: 0,
                    y: isTargeted ? 1 : (isHovering ? 0.8 : 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isTargeted ? .blue : (isHovering ? .secondary.opacity(0.4) : .secondary.opacity(0.2)), 
                            style: StrokeStyle(lineWidth: 1, dash: isTargeted ? [] : [3, 2])
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onDrop(of: [UTType.sessionID.identifier], isTargeted: $isTargeted) { providers in
            loadSessionID(from: providers) { sessionID in
                onAdd(sessionID)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .pointerStyle(.pointingHand)
    }
}

// MARK: - Bottom Drop Zone
struct BillingHubBottomDropZone: View {
    @Binding var isTargeted: Bool
    
    var body: some View {
        Rectangle()
            .fill(isTargeted ? Color.blue.opacity(0.2) : Color.clear)
            .frame(height: isTargeted ? 40 : 20)
            .overlay(
                Text(isTargeted ? "Drop to add" : "")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            )
            .padding(.horizontal, 12)
    }
}

// MARK: - Group Card View
struct GroupCardView: View {
    let group: SessionGroup
    @Binding var isSelected: Bool
    let onTap: () -> Void
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let onAddSessionToGroup: (UUID, UUID) -> Void // (sessionID, groupID)
    let canAddSessionToGroup: (UUID, UUID) -> Bool // (sessionID, groupID) -> canAdd
    @State private var targetedSessionID: UUID?
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Group color indicator
                Circle()
                    .fill(group.accentColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(group.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Session count indicator
                Text("\(group.sessions.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(.quaternary.opacity(0.3))
                    )
            }
            
            // Embedded sessions list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(group.sessions.indices, id: \.self) { index in
                    let session = group.sessions[index]
                    SessionItemView(
                        session: session,
                        isDropTargeted: .constant(targetedSessionID == session.id),
                        onTap: {
                            selectedCard = session
                            isEditingPanelVisible = true
                        }
                    )
                }
                
                // Drop zone for adding sessions to this group
                SessionDropZone(
                    onAdd: { sessionID in
                        // Check if the session can be added to this group (same client only)
                        let targetGroupID = group.groupID ?? group.sessions.first?.id ?? UUID()
                        if canAddSessionToGroup(sessionID, targetGroupID) {
                            onAddSessionToGroup(sessionID, targetGroupID)
                        }
                    },
                    groupID: group.groupID ?? UUID() // Use actual groupID or fallback
                )
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? Color(.controlBackgroundColor).opacity(0.9) : Color(.controlBackgroundColor))
                .shadow(
                    color: isSelected ? .blue.opacity(0.3) : (isHovering ? .black.opacity(0.15) : .black.opacity(0.1)),
                    radius: isSelected ? 8 : (isHovering ? 4 : 2),
                    x: 0,
                    y: isSelected ? 2 : (isHovering ? 1.5 : 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? .blue : (isHovering ? .blue.opacity(0.6) : .secondary.opacity(0.4)), lineWidth: 1)
                )
        )
        .onTapGesture {
            onTap()
        }
        .onDrag {
            return createDragProvider(for: group.id, typeIdentifier: UTType.groupID.identifier)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .pointerStyle(.pointingHand)
    }
}

// MARK: - Session Item View (embedded in groups)
struct SessionItemView: View {
    let session: KanbanCardData
    @Binding var isDropTargeted: Bool
    let onTap: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini icon/indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(isDropTargeted ? .blue : .blue.opacity(0.6))
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(sessionSubtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.blue.opacity(0.15) : Color(.controlBackgroundColor).opacity(0.6))
                .shadow(
                    color: isDropTargeted ? .blue.opacity(0.3) : (isHovering ? .black.opacity(0.1) : .black.opacity(0.05)),
                    radius: isDropTargeted ? 4 : (isHovering ? 2 : 1),
                    x: 0,
                    y: isDropTargeted ? 1 : (isHovering ? 0.8 : 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDropTargeted ? .blue : (isHovering ? .blue.opacity(0.6) : .secondary.opacity(0.3)), lineWidth: 1)
                )
        )
        .onTapGesture {
            onTap()
        }
        .onDrag {
            let uti = isSession ? UTType.sessionID.identifier : UTType.invoiceID.identifier
            return createDragProvider(for: session.id, typeIdentifier: uti)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .pointerStyle(.pointingHand)
    }
    
    // MARK: - Computed Properties
    private var isSession: Bool {
        switch session {
        case .session: return true
        case .invoice: return false
        }
    }
    
    private var sessionTitle: String {
        switch session {
        case .session(let data): return data.title
        case .invoice(let data): return data.title
        }
    }
    
    private var sessionSubtitle: String {
        switch session {
        case .session(let data): return data.duration
        case .invoice(let data): return data.amount
        }
    }
}

// MARK: - Kanban Card View (simplified version)
struct KanbanCardView: View {
    let card: KanbanCardData
    @Binding var isSelected: Bool
    let onTap: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Client color indicator
                Circle()
                    .fill(cardAccentColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(cardTitle)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(cardSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                if let statusText = cardStatusText {
                    Text(statusText)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.quaternary.opacity(0.3))
                        )
                }
            }
            
            // Additional details if available
            if let details = cardDetails, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? Color(.controlBackgroundColor).opacity(0.9) : Color(.controlBackgroundColor))
                .shadow(
                    color: isSelected ? .blue.opacity(0.3) : (isHovering ? .black.opacity(0.15) : .black.opacity(0.1)),
                    radius: isSelected ? 8 : (isHovering ? 4 : 2),
                    x: 0,
                    y: isSelected ? 2 : (isHovering ? 1.5 : 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? .blue : (isHovering ? .blue.opacity(0.6) : .secondary.opacity(0.4)), lineWidth: 1)
                )
        )
        .onTapGesture {
            onTap()
        }
        .onDrag {
            let uti = isSession ? UTType.sessionID.identifier : UTType.invoiceID.identifier
            return createDragProvider(for: card.id, typeIdentifier: uti)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .pointerStyle(.pointingHand)
    }
    
    // MARK: - Computed Properties
    private var isSession: Bool {
        switch card {
        case .session: return true
        case .invoice: return false
        }
    }
    
    private var cardAccentColor: Color {
        switch card {
        case .session(let data): return data.accentColor
        case .invoice(let data): return data.accentColor
        }
    }
    
    private var cardTitle: String {
        switch card {
        case .session(let data): return data.title
        case .invoice(let data): return data.title
        }
    }
    
    private var cardSubtitle: String {
        switch card {
        case .session(let data): return "\(data.clientName) • \(data.serviceName)"
        case .invoice(let data): return "\(data.clientName) • \(data.amount)"
        }
    }
    
    private var cardStatusText: String? {
        switch card {
        case .session(let data): return data.duration
        case .invoice(let data): return data.amount
        }
    }
    
    private var cardDetails: String? {
        switch card {
        case .session(let data): return data.date
        case .invoice(let data): return data.date
        }
    }
}
