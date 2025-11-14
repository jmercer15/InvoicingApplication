//
//  BillingHubView.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import AppKit
import SwiftData
import SharedUI
import Core

public struct BillingHubView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: BillingHubViewModel
    
    @State private var isEditingPanelVisible = false
    @State private var selectedCard: KanbanCardData?
    @FocusState private var isSearchFocused: Bool


    // Note: BillingHubViewModel should be injected via AppAssembly factory method
    // This initializer is kept for previews/testing
    public init(viewModel: BillingHubViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            // For previews only - in production use AppAssembly.makeBillingHubViewModel()
            fatalError("BillingHubViewModel must be injected via AppAssembly")
        }
    }

    // Internal initializer to allow previews to inject a custom view model
    init(viewModel: BillingHubViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        // Precompute lightweight counts to ease SwiftUI type-checking
        let completedCount = viewModel.sessionsByStatus[.completed]?.count ?? 0
        let groupedCount = viewModel.sessionsByStatus[.grouped]?.count ?? 0
        let assignCount = viewModel.sessionsByStatus[.assignServices]?.count ?? 0
        let travelCount = viewModel.sessionsByStatus[.addTravel]?.count ?? 0
        let reviewCount = viewModel.invoicesByStatus[.reviewDrafts]?.count ?? 0
        let readyCount = viewModel.invoicesByStatus[.readyToSend]?.count ?? 0
        let pendingCount = viewModel.invoicesByStatus[.pending]?.count ?? 0
        let receivedCount = viewModel.invoicesByStatus[.received]?.count ?? 0
        let visibleSessionCount = viewModel.sessionsByStatus.values.reduce(0) { $0 + $1.count }
        let visibleInvoiceCount = viewModel.invoicesByStatus.values.reduce(0) { $0 + $1.count }

        ZStack {
            BillingHubBackground()

            KanbanBoardView(
                viewModel: viewModel,
                selectedCard: $selectedCard,
                isEditingPanelVisible: $isEditingPanelVisible
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, StyleGuide.Dimensions.paddingXXLarge)
            .padding(.vertical, StyleGuide.Dimensions.paddingLarge)
            .overlay(
                Group {
                    if isEditingPanelVisible, let card = selectedCard {
                        EditingPanel(
                            card: card,
                            isVisible: $isEditingPanelVisible
                        )
                        .transition(.move(edge: .bottom))
                        .animation(BillingHubTheme.Animations.spring, value: isEditingPanelVisible)
                    }
                },
                alignment: .bottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            toolbarContent(sessionCount: visibleSessionCount, invoiceCount: visibleInvoiceCount)
        }
        .toolbarBackground(BillingHubTheme.Gradients.toolbar, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbarColorScheme(.dark, for: .windowToolbar)
    }
}

// MARK: - Private helpers

private extension BillingHubView {
    @ToolbarContentBuilder
    func toolbarContent(sessionCount: Int, invoiceCount: Int) -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Text("Billing Hub")
                .font(BillingHubTheme.Typography.title)
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
        }

        ToolbarItemGroup(placement: .automatic) {
            searchField
                .frame(minWidth: 200, idealWidth: 240)

            clientFilter

            if viewModel.hasActiveFilters {
                clearFiltersButton
            }

        }

        ToolbarItem(placement: .automatic) {
            refreshButton
        }
    }

    var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(BillingHubTheme.Palette.textSecondary)

            TextField("Search sessions or invoices", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
                .focused($isSearchFocused)
                .disableAutocorrection(true)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(BillingHubTheme.Palette.textMuted)
                }
                .buttonStyle(.plain)
                .pointerStyle(.pointingHand)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                )
        )
    }

    var clientFilter: some View {
        Menu {
            Button {
                viewModel.selectClient(withID: nil)
            } label: {
                HStack {
                    Text("All Clients")
                    if viewModel.selectedClientID == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            if !viewModel.clientSummaries.isEmpty {
                Divider()
            }

            ForEach(viewModel.clientSummaries) { summary in
                Button {
                    viewModel.selectClient(withID: summary.id)
                } label: {
                    HStack {
                        clientBadge(clientId: summary.id)
                        Text(summary.name)
                        if viewModel.selectedClientID == summary.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            FilterPill(
                icon: "person.2.fill",
                title: viewModel.selectedClientName ?? "All Clients"
            )
        }
        .menuStyle(.borderlessButton)
    }

    func clientBadge(clientId: UUID) -> some View {
        Circle()
            .fill(ColorSystem.Client.color(for: clientId).opacity(0.85))
            .frame(width: 8, height: 8)
    }

    var clearFiltersButton: some View {
        Button {
            withAnimation(BillingHubTheme.Animations.hover) {
                viewModel.clearFilters()
            }
        } label: {
            Label("Clear", systemImage: "line.3.horizontal.decrease.circle")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textSecondary)
                .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                .background(
                    Capsule()
                        .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.6))
                        .overlay(
                            Capsule()
                                .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .pointerStyle(.pointingHand)
    }

    var refreshButton: some View {
        Button {
            withAnimation(BillingHubTheme.Animations.spring) {
                viewModel.refresh()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
                .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                .background(
                    LinearGradient(
                        colors: [
                            BillingHubTheme.Columns.processing.opacity(0.85),
                            BillingHubTheme.Palette.accentHighlight.opacity(0.85)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(BillingHubTheme.Palette.surfaceStroke.opacity(0.6), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerStyle(.pointingHand)
    }
}

// Metric chips removed per updated design.


private struct FilterPill: View {
    let icon: String
    let title: String

    public var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(BillingHubTheme.Palette.textSecondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(
            Capsule()
                .fill(BillingHubTheme.Gradients.card)
                .overlay(
                    Capsule()
                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                )
                .shadow(color: BillingHubTheme.Shadows.soft.opacity(0.15), radius: 10, x: 0, y: 8)
        )
    }
}

// Supporting Views - Moved to separate files: KanbanHeaders.swift, KanbanViews.swift, EditingPanel.swift, StatusIndicator.swift
// Preview helpers moved to BillingHubView+Preview.swift to isolate Data import
