//
//  KanbanBoardView+Preview.swift
//  InvoicingApplication
//
//  Preview helpers for KanbanBoardView.
//

import SwiftUI
import SharedUI

#Preview("Billing Hub – Full Kanban Board") {
    FullKanbanBoardPreview()
}

private struct FullKanbanBoardPreview: View {
    @State private var selectedCardID: UUID? = nil

    var body: some View {
        BillingHubPreviewSupport.PreviewLoader(minHeight: 680) { payload in
            KanbanBoardView(
                displayState: KanbanBoardDisplayState(
                    searchText: payload.viewModel.searchText,
                    hasActiveFilters: payload.viewModel.hasActiveFilters
                ),
                actions: payload.viewModel.kanbanBoardActionsForCurrentSortOptions(),
                cardActions: payload.viewModel.kanbanCardActionsForCurrentSortOptions(),
                projection: payload.projection,
                boardRevision: payload.viewModel.dataRevision,
                selectedCardID: $selectedCardID,
                onOpenCard: { _ in }
            )
            .frame(minHeight: 680)
            .padding()
            .background(StyleGuide.Colors.secondary)
        }
    }
}
