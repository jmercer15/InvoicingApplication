import SwiftUI
import SharedUI

struct BillingHubGroupedSessionItemRow: View {
    let cardActions: KanbanCardActions
    let session: KanbanCardData
    @Binding var selectedCardID: UUID?
    let interactionState: BillingHubBoardInteractionState
    let showsInsertionSeparator: Bool
    let isInsertionSeparatorHighlighted: Bool
    let showsInsertionUI: Bool
    let insertIndex: Int
    let acceptsDrop: (BillingHubBoardDragKind, Int) -> Bool
    let onInsert: (BillingHubBoardDragKind, Int) -> Void
    let onTargetingChanged: (Bool) -> Void
    let onOpenCard: (UUID) -> Void
    let searchText: String

    @State private var isDragTargeted = false

    private var acceptsCurrentDrop: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return acceptsDrop(dragKind, insertIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            BillingHubGroupedSessionItemView(
                cardActions: cardActions,
                session: session,
                selectedCardID: $selectedCardID,
                isDropTargeted: acceptsCurrentDrop && isDragTargeted,
                interactionState: interactionState,
                onOpenCard: onOpenCard,
                searchText: searchText
            )

            if showsInsertionSeparator {
                BillingHubGroupSessionInsertionSeparator(
                    isHighlighted: acceptsCurrentDrop && isInsertionSeparatorHighlighted,
                    isVisible: showsInsertionUI
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .billingHubDropHandler(
            targeted: $isDragTargeted,
            interactionState: interactionState,
            accepts: { acceptsDrop($0, insertIndex) }
        ) { onInsert($0, insertIndex) }
        .onChange(of: isDragTargeted) { _, targeted in
            onTargetingChanged(acceptsCurrentDrop && targeted)
        }
        .resetBillingHubTargetOnDragEnd(interactionState.isDragActive) {
            isDragTargeted = false
        }
    }
}

struct BillingHubGroupedSessionItemView: View {
    let cardActions: KanbanCardActions
    let session: KanbanCardData
    @Binding var selectedCardID: UUID?
    let isDropTargeted: Bool
    let interactionState: BillingHubBoardInteractionState
    let onOpenCard: (UUID) -> Void
    let searchText: String

    private var previewItem: BillingHubBoardTransferItem {
        BillingHubBoardTransferItem.previewItem(for: session)
    }

    private var isBeingDragged: Bool {
        interactionState.activeDragKind == .session(session.id)
    }

    var body: some View {
        KanbanCardView(
            cardActions: cardActions,
            card: session,
            isSelected: selectedCardID == session.id,
            onTap: {
                selectedCardID = session.id
            },
            onOpen: {
                onOpenCard(session.id)
            },
            searchText: searchText
        )
        .billingHubDragPointerStyle(isBeingDragged: isBeingDragged, interactionState: interactionState)
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    selectedCardID = session.id
                    onOpenCard(session.id)
                }
        )
        .overlay {
            RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius, style: .continuous)
                .stroke(
                    isDropTargeted
                        ? BillingHubTheme.Surfaces.dropTargetStroke
                        : .clear,
                    lineWidth: 1
                )
        }
        .background {
            RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius, style: .continuous)
                .fill(isDropTargeted ? BillingHubTheme.Surfaces.dropTargetFill : .clear)
        }
        .opacity(isBeingDragged ? 0.6 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .billingHubDragSource(
            interactionState: interactionState,
            dragKind: .session(session.id),
            provider: {
                BillingHubBoardTransfer.provider(for: session.id, type: .billingHubSessionID)
            }
        ) {
            BillingHubBoardDragPreview(item: previewItem)
        }
    }
}

struct BillingHubGroupSessionInsertionSeparator: View {
    let isHighlighted: Bool
    let isVisible: Bool

    private var laneTint: Color {
        isHighlighted ? BillingHubTheme.Surfaces.dropTargetFill.opacity(0.9) : BillingHubTheme.Surfaces.dropTargetFill.opacity(0.35)
    }

    private var ruleTint: Color {
        isHighlighted ? BillingHubTheme.Surfaces.dropTargetStroke : Color.accentColor.opacity(0.22)
    }

    var body: some View {
        Group {
            if isVisible || isHighlighted {
                RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.groupCardCornerRadius, style: .continuous)
                    .fill(laneTint)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(ruleTint)
                            .frame(height: isHighlighted ? 2.5 : 2)
                    }
                    .frame(height: 14)
            } else {
                Color.clear.frame(height: 4)
            }
        }
        .animation(BillingHubBoardMotion.quick, value: isHighlighted)
        .animation(BillingHubBoardMotion.smooth, value: isVisible)
    }
}

struct BillingHubGroupSessionDropZone: View {
    @Binding var isTargeted: Bool
    let isVisible: Bool
    let acceptsDrop: (BillingHubBoardDragKind) -> Bool
    let onAdd: (BillingHubBoardDragKind) -> Void
    let interactionState: BillingHubBoardInteractionState

    var body: some View {
        Group {
            if isVisible || isTargeted {
                ZStack {
                    RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius, style: .continuous)
                        .fill(effectiveTargeting ? BillingHubTheme.Surfaces.dropTargetFill : .clear)

                    VStack(spacing: 0) {
                        Capsule(style: .continuous)
                            .fill(effectiveTargeting ? BillingHubTheme.Surfaces.dropTargetStroke : Color.accentColor.opacity(0.22))
                            .frame(height: effectiveTargeting ? 2.5 : 2)
                            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)

                        if effectiveTargeting {
                            Text("Move session to end")
                                .font(StyleGuide.Typography.nano)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .frame(height: 24)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Color.clear.frame(height: 8)
            }
        }
        .padding(.leading, StyleGuide.Dimensions.paddingSmall)
        .billingHubDropHandler(
            targeted: $isTargeted,
            interactionState: interactionState,
            accepts: acceptsDrop
        ) { onAdd($0) }
        .resetBillingHubTargetOnDragEnd(interactionState.isDragActive) {
            isTargeted = false
        }
        .animation(BillingHubBoardMotion.quick, value: effectiveTargeting)
        .animation(BillingHubBoardMotion.smooth, value: isVisible)
    }

    private var effectiveTargeting: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return isTargeted && acceptsDrop(dragKind)
    }
}
