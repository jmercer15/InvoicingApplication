import SwiftUI
import SharedUI

struct BillingHubCardItemWrapper: View {
    let cardActions: KanbanCardActions
    let card: KanbanCardData
    @Binding var targetedCardID: UUID?
    let interactionState: BillingHubBoardInteractionState
    let showsInsertionUI: Bool
    let showsInsertionSeparator: Bool
    let shouldHighlightSeparator: Bool
    let acceptsDrop: (BillingHubBoardDragKind, UUID) -> Bool
    let onDrop: @MainActor (BillingHubBoardDragKind, UUID) -> Void
    @Binding var selectedCardID: UUID?
    let onOpenCard: (UUID) -> Void
    let searchText: String

    @State private var isItemTargeted = false
    @State private var isRejected = false

    private var acceptsCurrentDrop: Bool {
        guard let dragKind = interactionState.activeDragKind else { return false }
        return acceptsDrop(dragKind, card.id)
    }

    private var isRejectedForThisCard: Bool {
        interactionState.lastRejectedDropID == card.id && isRejected
    }

    var body: some View {
        VStack(spacing: 0) {
            DragContainerCardRow(
                cardActions: cardActions,
                card: card,
                isSelected: selectedCardID == card.id,
                isDropTargeted: acceptsCurrentDrop && isItemTargeted && !isRejectedForThisCard,
                interactionState: interactionState,
                searchText: searchText,
                onSelect: {
                    selectedCardID = card.id
                },
                onOpen: {
                    onOpenCard(card.id)
                }
            )

            if showsInsertionSeparator {
                BillingHubCardInsertionSeparator(
                    isHighlighted: acceptsCurrentDrop && shouldHighlightSeparator,
                    isVisible: showsInsertionUI
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .billingHubDropHandler(
            targeted: $isItemTargeted,
            interactionState: interactionState,
            accepts: { acceptsDrop($0, card.id) }
        ) { dragKind in
            onDrop(dragKind, card.id)
        }
        .onChange(of: isItemTargeted) { _, targeted in
            withAnimation(BillingHubBoardMotion.quick) {
                if acceptsCurrentDrop, targeted {
                    targetedCardID = card.id
                } else if targetedCardID == card.id {
                    targetedCardID = nil
                }
            }
        }
        .onChange(of: interactionState.lastRejectedDropID) { _, newValue in
            guard newValue == card.id else { return }
            isRejected = true
            withAnimation(BillingHubBoardMotion.quick) {
                targetedCardID = nil
            }
            Task { @MainActor in
                guard await Task.waitUnlessCancelled(nanoseconds: 300_000_000) else { return }
                if isRejected {
                    withAnimation(BillingHubBoardMotion.quick) {
                        isRejected = false
                    }
                }
            }
        }
        .resetBillingHubTargetOnDragEnd(interactionState.isDragActive) {
            isItemTargeted = false
            if targetedCardID == card.id {
                targetedCardID = nil
            }
            isRejected = false
        }
    }
}

struct BillingHubBottomDropZone: View {
    let isTargeted: Bool
    let isEmpty: Bool
    let isVisible: Bool
    let emptyLabel: String
    let targetedLabel: String

    var body: some View {
        Group {
            if isEmpty || isVisible || isTargeted {
                ZStack {
                    RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.columnCornerRadius - 2, style: .continuous)
                        .fill(isTargeted ? BillingHubTheme.Surfaces.dropTargetFill : (isEmpty ? BillingHubTheme.Surfaces.dropZoneBase.opacity(0.12) : .clear))

                    if isEmpty {
                        RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.columnCornerRadius - 2, style: .continuous)
                            .strokeBorder(
                                isTargeted ? BillingHubTheme.Surfaces.dropTargetStroke : BillingHubTheme.Surfaces.dropZoneStroke,
                                style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 1, dash: [6, 4])
                            )
                    }

                    VStack(spacing: isEmpty ? 8 : 0) {
                        Capsule(style: .continuous)
                            .fill(isTargeted ? BillingHubTheme.Surfaces.dropTargetStroke : .clear)
                            .frame(height: isTargeted ? 3 : 2)
                            .padding(.horizontal, isEmpty ? StyleGuide.Dimensions.paddingXXLarge : StyleGuide.Dimensions.paddingMediumLarge)

                        if isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "tray.and.arrow.down").font(.title3)
                                Text(emptyLabel)
                                    .font(.caption.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                            }
                            .foregroundStyle(isTargeted ? Color.accentColor : BillingHubTheme.Palette.textSecondary)
                        } else if isTargeted {
                            Text(targetedLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .frame(minHeight: isEmpty ? 96 : 32)
                .fixedSize(horizontal: false, vertical: isEmpty)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Color.clear.frame(height: 16)
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
        .animation(BillingHubBoardMotion.quick, value: isTargeted)
        .animation(BillingHubBoardMotion.smooth, value: isVisible)
    }
}

struct BillingHubCardInsertionSeparator: View {
    let isHighlighted: Bool
    let isVisible: Bool

    var body: some View {
        Group {
            if isVisible || isHighlighted {
                RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius, style: .continuous)
                    .fill(isHighlighted ? BillingHubTheme.Surfaces.dropTargetFill : .clear)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(isHighlighted ? BillingHubTheme.Surfaces.dropTargetStroke : .clear)
                            .frame(height: isHighlighted ? 3 : 2)
                    }
                    .frame(height: 18)
            } else {
                Color.clear.frame(height: 8)
            }
        }
        .animation(BillingHubBoardMotion.quick, value: isHighlighted)
        .animation(BillingHubBoardMotion.smooth, value: isVisible)
    }
}

struct DragContainerCardRow: View {
    let cardActions: KanbanCardActions
    let card: KanbanCardData
    let isSelected: Bool
    let isDropTargeted: Bool
    let interactionState: BillingHubBoardInteractionState
    let searchText: String
    let onSelect: () -> Void
    let onOpen: () -> Void

    @State private var isHovered = false
    @State private var isRejected = false

    private var previewItem: BillingHubBoardTransferItem {
        BillingHubBoardTransferItem.previewItem(for: card)
    }

    private var isBeingDragged: Bool {
        interactionState.activeDragKind == previewItem.dragKind
    }

    private var borderColor: Color {
        if isRejected {
            return ColorSystem.Status.error.opacity(0.7)
        }
        if isDropTargeted {
            return BillingHubTheme.Surfaces.dropTargetStroke
        }
        if isHovered {
            return Color.accentColor.opacity(0.20)
        }
        return .clear
    }

    private var backgroundFill: Color {
        if isRejected {
            return ColorSystem.Status.error.opacity(StyleGuide.Opacity.light)
        }
        if isDropTargeted {
            return BillingHubTheme.Surfaces.dropTargetFill
        }
        return .clear
    }

    var body: some View {
        KanbanCardView(
            cardActions: cardActions,
            card: card,
            isSelected: isSelected,
            onTap: onSelect,
            onOpen: onOpen,
            searchText: searchText
        )
        .equatable()
        .billingHubDragPointerStyle(isBeingDragged: isBeingDragged, interactionState: interactionState)
        .overlay {
            RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .background {
            RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius, style: .continuous)
                .fill(backgroundFill)
        }
        .opacity(isBeingDragged ? 0.55 : 1)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onSelect()
                    onOpen()
                }
        )
        .onHover { hovering in
            withAnimation(BillingHubBoardMotion.smooth) {
                isHovered = hovering
            }
        }
        .billingHubDragSource(
            interactionState: interactionState,
            dragKind: previewItem.dragKind,
            provider: {
                BillingHubBoardTransfer.provider(for: previewItem.itemID, type: previewItem.dragKind.contentType)
            }
        ) {
            BillingHubBoardDragPreview(item: previewItem)
        }
        .onChange(of: interactionState.lastRejectedDropID) { _, newValue in
            guard newValue == previewItem.itemID else { return }
            withAnimation(BillingHubBoardMotion.quick) {
                isRejected = true
            }
            Task { @MainActor in
                guard await Task.waitUnlessCancelled(nanoseconds: 300_000_000) else { return }
                withAnimation(BillingHubBoardMotion.quick) {
                    isRejected = false
                }
            }
        }
    }
}
