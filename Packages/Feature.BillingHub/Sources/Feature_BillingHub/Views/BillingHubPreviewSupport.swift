import Foundation
import PersistenceModels
import SwiftUI
import SwiftData
import SharedUI

@MainActor
enum BillingHubPreviewSupport {
    typealias SeedData = BillingHubWorkspaceFactory.PreviewSeedData

    @MainActor
    struct Payload {
        let viewModel: BillingHubViewModel
        let seedData: SeedData

        var projection: BillingHubBoardProjection {
            BillingHubProjectionBuilder.project(
                sessions: seedData.sessions,
                invoices: seedData.invoices,
                clients: seedData.clients,
                clientServices: seedData.clientServices,
                searchText: viewModel.searchText,
                selectedClientID: viewModel.selectedClientID,
                sortOptions: viewModel.columnSortOptions
            )
        }
    }

    @MainActor
    struct DraftsPayload {
        let container: ModelContainer
        let viewModel: BillableDraftsViewModel
        let seedData: SeedData
    }

    struct PreviewLoader<Content: View>: View {
        let minHeight: CGFloat
        @ViewBuilder let content: (Payload) -> Content

        @State private var payload: Payload?
        @State private var errorMessage: String?

        var body: some View {
            Group {
                if let payload {
                    content(payload)
                } else if let errorMessage {
                    PreviewErrorView(message: errorMessage)
                } else {
                    ProgressView("Loading Billing Hub Preview...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(minHeight: minHeight)
                        .task {
                            await loadIfNeeded()
                        }
                }
            }
        }

        private func loadIfNeeded() async {
            guard payload == nil, errorMessage == nil else { return }
            do {
                let factoryPayload = try BillingHubWorkspaceFactory.makePreviewPayload()
                payload = Payload(
                    viewModel: factoryPayload.viewModel,
                    seedData: factoryPayload.seedData
                )
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }

    struct DraftsPreviewLoader<Content: View>: View {
        let minHeight: CGFloat
        @ViewBuilder let content: (DraftsPayload) -> Content

        @State private var payload: DraftsPayload?
        @State private var errorMessage: String?

        var body: some View {
            Group {
                if let payload {
                    content(payload)
                } else if let errorMessage {
                    PreviewErrorView(message: errorMessage)
                } else {
                    ProgressView("Loading Billing Drafts Preview...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(minHeight: minHeight)
                        .task {
                            await loadIfNeeded()
                        }
                }
            }
        }

        private func loadIfNeeded() async {
            guard payload == nil, errorMessage == nil else { return }
            do {
                let factoryPayload = try BillingHubWorkspaceFactory.makeDraftsPreviewPayload()
                payload = DraftsPayload(
                    container: factoryPayload.container,
                    viewModel: factoryPayload.viewModel,
                    seedData: factoryPayload.seedData
                )
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }

    private struct PreviewErrorView: View {
        let message: String

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Label("Billing Hub Preview Failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(StyleGuide.Dimensions.paddingXLarge)
        }
    }
}
