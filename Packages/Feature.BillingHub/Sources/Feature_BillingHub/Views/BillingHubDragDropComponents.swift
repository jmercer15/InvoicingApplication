import SwiftUI
import UniformTypeIdentifiers

// Custom UTIs for BillingHub drag and drop
extension UTType {
    static let sessionID = UTType(exportedAs: "com.invoicingapp.session-id")
    static let invoiceID = UTType(exportedAs: "com.invoicingapp.invoice-id")
    static let groupID = UTType(exportedAs: "com.invoicingapp.group-id")
}

// MARK: - Group Data Structure
struct SessionGroup: Identifiable, Equatable {
    let id: UUID
    let sessions: [KanbanCardData]
    let groupID: UUID?
    
    init(groupID: UUID?, sessions: [KanbanCardData]) {
        if let groupID {
            self.id = groupID
        } else if sessions.count == 1 {
            self.id = sessions[0].id
        } else {
            self.id = UUID()
        }
        self.groupID = groupID
        self.sessions = sessions
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
@discardableResult
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

@discardableResult
private func loadSessionID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
    loadID(from: providers, typeIdentifier: UTType.sessionID.identifier, handle: handle)
}

@discardableResult
private func loadInvoiceID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
    loadID(from: providers, typeIdentifier: UTType.invoiceID.identifier, handle: handle)
}

@discardableResult
private func loadGroupID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
    loadID(from: providers, typeIdentifier: UTType.groupID.identifier, handle: handle)
}

@discardableResult
private func handleSessionOrInvoiceDrop(
    from providers: [NSItemProvider],
    allowsSessions: Bool,
    allowsInvoices: Bool,
    onSession: @escaping (UUID) -> Void,
    onInvoice: @escaping (UUID) -> Void
) -> Bool {
    if allowsSessions,
       let sessionProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.sessionID.identifier) }) {
        return loadSessionID(from: [sessionProvider], handle: onSession)
    }

    if allowsInvoices,
       let invoiceProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.invoiceID.identifier) }) {
        return loadInvoiceID(from: [invoiceProvider], handle: onInvoice)
    }

    return false
}

private func clearTargetedItemOnBottomHover(_ targetedItemID: Binding<UUID?>, isTargeted: Bool) {
    withAnimation(.easeInOut(duration: 0.2)) {
        if isTargeted {
            targetedItemID.wrappedValue = nil
        }
    }
}

private func setTargetedItem(_ targetedItemID: Binding<UUID?>, isTargeted: Bool, id: UUID) {
    withAnimation(.easeInOut(duration: 0.15)) {
        targetedItemID.wrappedValue = isTargeted ? id : nil
    }
}

private extension View {
    @ViewBuilder
    func kanbanBaseListStyle(hideRowSeparators: Bool = false) -> some View {
        if hideRowSeparators {
            self
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
        } else {
            self
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
        }
    }

    func kanbanEmptyStateOverlay(isEmpty: Bool, label: String, icon: String, description: String) -> some View {
        self.overlay(
            Group {
                if isEmpty {
                    ContentUnavailableView(
                        label: {
                            Label(label, systemImage: icon)
                                .font(.title3)
                        },
                        description: {
                            Text(description)
                                .font(.subheadline)
                        }
                    )
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                }
            }
        )
    }
}

// MARK: - Search Highlighting Helper
@ViewBuilder
private func highlightedText(_ text: String, searchingFor query: String) -> some View {
    if !query.isEmpty, let range = text.range(of: query, options: .caseInsensitive) {
        let prefix = text[..<range.lowerBound]
        let match = text[range]
        let suffix = text[range.upperBound...]
        
        Text(prefix) +
        Text(match).bold().foregroundColor(.blue) +
        Text(suffix)
    } else {
        Text(text)
    }
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
    let onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    let onReorderGroup: (UUID, UUID?) -> Bool
    var onDropOnCard: ((UUID, UUID) -> Bool)? = nil
    let onAddSessionToGroup: (UUID, UUID) -> Void // (sessionID, groupID)
    let canAddSessionToGroup: (UUID, UUID) -> Bool // (sessionID, groupID) -> canAdd
    var searchText: String = ""
    
    @State private var targetedItemID: UUID?
    @State private var isBottomTargeted = false
    
    var body: some View {
        List {
            ForEach(groups, id: \.id) { group in
                groupItemView(for: group)
            }
            
            bottomDropZone
        }
        .kanbanBaseListStyle(hideRowSeparators: true)
        .kanbanEmptyStateOverlay(
            isEmpty: groups.isEmpty,
            label: "No Groups",
            icon: "rectangle.stack",
            description: "Drag sessions here to bundle them"
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: groups.isEmpty)
    }
    
    private func groupItemView(for group: SessionGroup) -> some View {
        GroupItemWrapper(
            group: group,
            targetedItemID: $targetedItemID,
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible,
            onReorderBetween: onReorderBetween,
            onReorderGroup: onReorderGroup,
            onDropOnCard: onDropOnCard,
            onAddSessionToGroup: onAddSessionToGroup,
            canAddSessionToGroup: canAddSessionToGroup,
            searchText: searchText
        )
        .listRowSeparator(.hidden)
    }
    
    private var bottomDropZone: some View {
        BillingHubBottomDropZone(isTargeted: .constant(targetedItemID == nil && isBottomTargeted))
        .onDrop(of: [UTType.sessionID.identifier, UTType.groupID.identifier], isTargeted: $isBottomTargeted) { providers in
            // Handle bottom drop - append to end
            if loadGroupID(from: providers, handle: { _ = onReorderGroup($0, nil) }) ||
               loadSessionID(from: providers, handle: { _ = onReorderBetween($0, nil, nil) }) {
                return true
            }
            return false
        }
            .onChange(of: isBottomTargeted) { isTargeted in
                clearTargetedItemOnBottomHover($targetedItemID, isTargeted: isTargeted)
            }
        .listRowSeparator(.hidden)
    }
}

// MARK: - Group Item Wrapper
struct GroupItemWrapper: View {
    let group: SessionGroup
    @Binding var targetedItemID: UUID?
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    let onReorderGroup: (UUID, UUID?) -> Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let onAddSessionToGroup: (UUID, UUID) -> Void // (sessionID, groupID)
    let canAddSessionToGroup: (UUID, UUID) -> Bool // (sessionID, groupID) -> canAdd
    let searchText: String
    @State private var isItemTargeted = false
    
    var body: some View {
        GroupCardView(
            group: group,
            isSelected: .constant(false), // Group selection not fully implemented, or use derived
            onTap: {
                // Handle group tap if needed
            },
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible,
            onDropOnCard: onDropOnCard,
            onAddSessionToGroup: onAddSessionToGroup,
            canAddSessionToGroup: canAddSessionToGroup,
            searchText: searchText
        )
        .onDrop(of: [UTType.sessionID.identifier, UTType.groupID.identifier], isTargeted: $isItemTargeted) { providers in
            if loadGroupID(from: providers, handle: { groupID in
                if groupID != group.groupID {
                    _ = onReorderGroup(groupID, group.id)
                }
            }) {
                return true
            }

            let handleDrop: (UUID) -> Void = { id in
                if let existingGroupID = group.groupID {
                    if canAddSessionToGroup(id, existingGroupID) {
                        onAddSessionToGroup(id, existingGroupID)
                    }
                    return
                }

                guard let anchorSessionID = group.sessions.first?.id else { return }
                if let onDropOnCard = onDropOnCard {
                    _ = onDropOnCard(id, anchorSessionID)
                } else {
                    _ = onReorderBetween(id, anchorSessionID, nil)
                }
            }
            
            return loadSessionID(from: providers, handle: handleDrop)
        }
        .onChange(of: isItemTargeted) { isTargeted in
            setTargetedItem($targetedItemID, isTargeted: isTargeted, id: group.id)
        }
    }
}

// MARK: - Custom Kanban Column
struct CustomKanbanColumn: View {
    enum DropPolicy {
        case sessionsOnly
        case invoicesOnly
        case sessionsAndInvoices

        var typeIdentifiers: [String] {
            switch self {
            case .sessionsOnly:
                return [UTType.sessionID.identifier]
            case .invoicesOnly:
                return [UTType.invoiceID.identifier]
            case .sessionsAndInvoices:
                return [UTType.sessionID.identifier, UTType.invoiceID.identifier]
            }
        }

        var allowsSessions: Bool {
            switch self {
            case .sessionsOnly, .sessionsAndInvoices:
                return true
            case .invoicesOnly:
                return false
            }
        }

        var allowsInvoices: Bool {
            switch self {
            case .invoicesOnly, .sessionsAndInvoices:
                return true
            case .sessionsOnly:
                return false
            }
        }
    }

    let cards: [KanbanCardData]
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let columnType: KanbanCardData.BillingColumnType
    let onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    var onDropOnCard: ((UUID, UUID) -> Bool)? = nil
    var dropPolicy: DropPolicy = .sessionsAndInvoices
    
    var emptyStateIcon: String = "tray"
    var emptyStateMessage: String = "No items"
    var searchText: String = ""
    
    @State private var targetedItemID: UUID?
    @State private var isBottomTargeted = false
    
    var body: some View {
        List {
            ForEach(cards, id: \.id) { card in
                cardItemView(for: card)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .listRowSeparator(.hidden)

            }
            
            bottomDropZone
        }
        .kanbanBaseListStyle()
        .kanbanEmptyStateOverlay(
            isEmpty: cards.isEmpty,
            label: emptyStateMessage,
            icon: emptyStateIcon,
            description: "Drag items here"
        )
        .overlay(
            SuccessEffectView(trigger: $triggerSuccessEffect),
            alignment: .center
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cards.isEmpty)
        .onChange(of: cards.count) { newCount, oldCount in
            if newCount > oldCount {
                checkAndTriggerSuccess()
            }
        }
    }
    
    // MARK: - Success Effect Logic
    @State private var triggerSuccessEffect = false
    
    private func checkAndTriggerSuccess() {
        let successColumns: [KanbanCardData.BillingColumnType] = [.completed, .received]
        if successColumns.contains(columnType) {
            triggerSuccessEffect = true
        }
    }
    
    // MARK: - Success Effect View
    private struct SuccessEffectView: View {
        @Binding var trigger: Bool
        @State private var opac: Double = 0
        @State private var scale: Double = 0.5
        
        var body: some View {
            if trigger {
                Image(systemName: "checkmark.seal.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.green.opacity(0.8))
                    .scaleEffect(scale)
                    .opacity(opac)
                    .blur(radius: 2)
                    .onAppear {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            scale = 1.2
                            opac = 1.0
                        }
                        
                        // Fade out
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            withAnimation(.easeOut(duration: 0.4)) {
                                opac = 0
                                scale = 1.5
                            }
                        }
                        
                        // Reset
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            trigger = false
                            scale = 0.5
                        }
                    }
                    .allowsHitTesting(false)
            }
        }
    }
    
    private func cardItemView(for card: KanbanCardData) -> some View {
        CardItemWrapper(
            card: card,
            targetedItemID: $targetedItemID,
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible,
            onReorderBetween: onReorderBetween,
            onDropOnCard: onDropOnCard,
            dropPolicy: dropPolicy,
            searchText: searchText
        )
    }
    
    private var bottomDropZone: some View {
        BillingHubBottomDropZone(isTargeted: .constant(targetedItemID == nil && isBottomTargeted))
            .onDrop(of: dropPolicy.typeIdentifiers, isTargeted: $isBottomTargeted) { providers in
                handleSessionOrInvoiceDrop(
                    from: providers,
                    allowsSessions: dropPolicy.allowsSessions,
                    allowsInvoices: dropPolicy.allowsInvoices,
                    onSession: { sessionID in
                        _ = onReorderBetween(sessionID, nil, nil)
                    },
                    onInvoice: { invoiceID in
                        _ = onReorderBetween(invoiceID, nil, nil)
                    }
                )
            }
            .onChange(of: isBottomTargeted) { isTargeted in
                clearTargetedItemOnBottomHover($targetedItemID, isTargeted: isTargeted)
            }
    }
}

// MARK: - Card Item Wrapper
struct CardItemWrapper: View {
    let card: KanbanCardData
    @Binding var targetedItemID: UUID?
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let onReorderBetween: (UUID, UUID?, UUID?) -> Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let dropPolicy: CustomKanbanColumn.DropPolicy
    var searchText: String
    @State private var isItemTargeted = false
    
    var body: some View {
        KanbanCardView(
            card: card,
            isSelected: .constant(selectedCard?.id == card.id),
            onTap: {
                selectedCard = card
                isEditingPanelVisible = true
            },
            searchText: searchText
        )
        .onDrop(of: dropPolicy.typeIdentifiers, isTargeted: $isItemTargeted) { providers in
            handleSessionOrInvoiceDrop(
                from: providers,
                allowsSessions: dropPolicy.allowsSessions,
                allowsInvoices: dropPolicy.allowsInvoices,
                onSession: { sessionID in
                    if let onDropOnCard = onDropOnCard {
                        _ = onDropOnCard(sessionID, card.id)
                    } else {
                        _ = onReorderBetween(sessionID, card.id, nil)
                    }
                },
                onInvoice: { invoiceID in
                    if let onDropOnCard = onDropOnCard {
                        _ = onDropOnCard(invoiceID, card.id)
                    } else {
                        _ = onReorderBetween(invoiceID, card.id, nil)
                    }
                }
            )
        }
        .onChange(of: isItemTargeted) { isTargeted in
            setTargetedItem($targetedItemID, isTargeted: isTargeted, id: card.id)
        }
    }
}

// MARK: - Session Drop Zone (for adding sessions to groups)
struct SessionDropZone: View {
    let onAdd: (UUID) -> Void
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
                .fill(
                    isTargeted
                    ? Color.blue.opacity(0.12)
                    : (isHovering ? BillingHubTheme.Surfaces.dropZoneBase.opacity(0.9) : BillingHubTheme.Surfaces.dropZoneBase.opacity(0.72))
                )
                .shadow(
                    color: isTargeted ? .blue.opacity(0.2) : .black.opacity(isHovering ? 0.05 : 0.03),
                    radius: isTargeted ? 3 : (isHovering ? 1 : 0.5),
                    x: 0,
                    y: isTargeted ? 1 : (isHovering ? 0.8 : 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isTargeted ? .blue : (isHovering ? BillingHubTheme.Surfaces.dropZoneStroke.opacity(1.2) : BillingHubTheme.Surfaces.dropZoneStroke),
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
        .pointerStyle(.link)
    }
}

struct BillingHubBottomDropZone: View {
    @Binding var isTargeted: Bool

    var body: some View {
        ZStack {
            // Idle state: Subtle dashed line to indicate drop capability
            if !isTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(BillingHubTheme.Surfaces.dropZoneStroke, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(height: 30)
                    .overlay(
                        Text("Drop to add")
                            .font(.caption)
                            .foregroundColor(BillingHubTheme.Palette.textSecondary.opacity(0.55))
                    )
            } else {
                // Targeted state: Active feedback
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
                    .frame(height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.55), lineWidth: 1)
                    )
                    .overlay(
                        Text("Drop to add")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                            .scaleEffect(1.05)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
    }
}

// MARK: - Group Card View
struct GroupCardView: View {
    let group: SessionGroup
    @Binding var isSelected: Bool
    let onTap: () -> Void
    @Binding var selectedCard: KanbanCardData?
    @Binding var isEditingPanelVisible: Bool
    let onDropOnCard: ((UUID, UUID) -> Bool)?
    let onAddSessionToGroup: (UUID, UUID) -> Void // (sessionID, groupID)
    let canAddSessionToGroup: (UUID, UUID) -> Bool // (sessionID, groupID) -> canAdd
    var searchText: String = ""
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(group.sessions.indices, id: \.self) { index in
                    let session = group.sessions[index]
                    SessionItemView(
                        session: session,
                        isSelected: selectedCard?.id == session.id,
                        onTap: {
                            selectedCard = session
                            isEditingPanelVisible = true
                        },
                        searchText: searchText
                    )
                }
            }

            SessionDropZone(
                onAdd: { sessionID in
                    // Existing grouped scope: add directly to the persisted group.
                    if let targetGroupID = group.groupID {
                        if canAddSessionToGroup(sessionID, targetGroupID) {
                            onAddSessionToGroup(sessionID, targetGroupID)
                        }
                        return
                    }

                    // Singleton ungrouped card: group against its anchor session.
                    if let anchorSessionID = group.sessions.first?.id {
                        _ = onDropOnCard?(sessionID, anchorSessionID)
                    }
                }
            )
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(BillingHubTheme.Surfaces.subcolumnBase)
                .shadow(
                    color: isSelected ? .blue.opacity(0.22) : .black.opacity(isHovering ? 0.09 : 0.05),
                    radius: isSelected ? 8 : (isHovering ? 6 : 3),
                    x: 0,
                    y: isSelected ? 2 : 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isSelected ? .blue : group.accentColor.opacity(isHovering ? 0.55 : 0.36),
                    style: StrokeStyle(lineWidth: isSelected ? 2 : 1.5, dash: [6, 4])
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 1)
                .stroke(BillingHubTheme.Surfaces.cardStroke.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onTap()
        }
        .onDrag {
            if let groupID = group.groupID {
                return createDragProvider(for: groupID, typeIdentifier: UTType.groupID.identifier)
            }
            if let sessionID = group.sessions.first?.id {
                return createDragProvider(for: sessionID, typeIdentifier: UTType.sessionID.identifier)
            }
            return NSItemProvider()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .scaleEffect(isHovering ? 1.003 : 1.0)
        .pointerStyle(.link)
    }
}

// MARK: - Session Item View (embedded in groups)
struct SessionItemView: View {
    let session: KanbanCardData
    let isSelected: Bool
    let onTap: () -> Void
    var searchText: String = ""
    
    var body: some View {
        KanbanCardView(
            card: session,
            isSelected: .constant(isSelected),
            onTap: onTap,
            searchText: searchText
        )
    }
}

// MARK: - Kanban Card View (simplified version)
struct KanbanCardView: View {
    let card: KanbanCardData
    @Binding var isSelected: Bool
    let onTap: () -> Void
    var searchText: String = "" // Added for highlighting
    @EnvironmentObject private var viewModel: BillingHubViewModel
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Integrated Accent Strip (Left Border)
            Rectangle()
                .fill(cardModel.accent)
                .frame(width: 4)
                .frame(alignment: .leading)
            
            VStack(alignment: .leading, spacing: 6) {
                // 1) Title
                highlightedText(cardModel.title, searchingFor: searchText)
                    .font(.system(.body, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)

                // 2) Subtitle
                highlightedText(cardModel.subtitle, searchingFor: searchText)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)

                // 3) Metadata adapts to narrow widths
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        metadataLeading

                        Spacer(minLength: 4)

                        metadataTrailing
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        metadataLeading
                        metadataTrailing
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(BillingHubTheme.Surfaces.cardBase)
                .shadow(
                    color: isSelected ? .blue.opacity(0.3) : (isHovering ? .black.opacity(0.08) : .black.opacity(0.04)),
                    radius: isSelected ? 6 : (isHovering ? 5 : 2),
                    x: 0,
                    y: isSelected ? 2 : (isHovering ? 2 : 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.blue : Color.white.opacity(0.20),
                    lineWidth: isSelected ? 1.5 : 0.7
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { onTap() }
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Edit Details", systemImage: "pencil")
            }
            
            Divider()
            
            if let nextColumn = viewModel.nextColumn(for: card) {
                Button {
                    Task {
                        _ = await viewModel.advanceCard(card)
                    }
                } label: {
                    Label("Move to \(nextColumn.menuTitle)", systemImage: "arrow.right.circle")
                }
            }
        }
        .onDrag {
            let uti = cardModel.isSession ? UTType.sessionID.identifier : UTType.invoiceID.identifier
            let provider = createDragProvider(for: card.id, typeIdentifier: uti)
            // Note: SwiftUI 4+ on macOS supports custom previews via `preview:` closure
            // For now, we rely on the standard drag image but improved with `preview` if targeting newer OS
            return provider
        } preview: {
            dragPreview
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .scaleEffect(isHovering ? 1.01 : 1.0) // Subtle scale
        .pointerStyle(.link)
        .overlay(
            GeometryReader { proxy in
                if isHovering && proxy.size.width > 170 {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                onTap()
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Circle().fill(Color.blue))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            },
            alignment: .topTrailing
        )
    }

    private var cardModel: (
        isSession: Bool,
        accent: Color,
        title: String,
        subtitle: String,
        detail: String?,
        status: String?
    ) {
        switch card {
        case .session(let data):
            return (true, data.accentColor, data.title, data.clientName, data.date, data.duration)
        case .invoice(let data):
            return (false, data.accentColor, data.title, data.clientName, data.date, data.amount)
        }
    }
    
    // MARK: - Drag Preview (Ghost Card)
    @ViewBuilder
    private var dragPreview: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(cardModel.accent)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(cardModel.title)
                    .font(.system(.body, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(cardModel.subtitle)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 260) // Fixed width for preview
            .background(BillingHubTheme.Surfaces.cardBase)
        }
        .frame(height: 60)
        .cornerRadius(8)
        .shadow(radius: 4)
    }

    private var metadataLeading: some View {
        HStack(spacing: 2) {
            Image(systemName: "calendar")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(cardModel.detail ?? "No date")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)
        }
    }

    private var metadataTrailing: some View {
        HStack(spacing: 2) {
            Image(systemName: cardModel.isSession ? "clock" : "banknote")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(cardModel.status ?? "No amount")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)
        }
    }

}

private extension KanbanCardData.BillingColumnType {
    var menuTitle: String {
        switch self {
        case .completed:
            return "Completed"
        case .grouped:
            return "Grouped"
        case .addTravel:
            return "Add Travel"
        case .reviewDrafts:
            return "Review Drafts"
        case .readyToSend:
            return "Ready to Send"
        case .pending:
            return "Pending"
        case .received:
            return "Received"
        }
    }
}
