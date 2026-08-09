#if DEBUG
import Data
import SwiftData
import SwiftUI

@MainActor
private enum InvoicesPreviewSupport {
    static func makeContainer() -> ModelContainer {
        try! ModelContainerFactory.makeInMemoryContainer()
    }

    static func makeViewModel(container: ModelContainer) -> InvoicesContainerViewModel {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let viewModel = InvoicesContainerViewModel(modelContext: context)
        viewModel.hasCompletedSuccessfulListLoad = true
        viewModel.isLoading = false
        return viewModel
    }
}

#Preview("Invoices Content") {
    let container = InvoicesPreviewSupport.makeContainer()
    let viewModel = InvoicesPreviewSupport.makeViewModel(container: container)

    NavigationStack {
        InvoicesContentColumn(viewModel: viewModel, onCreateInvoice: {})
    }
    .modelContainer(container)
    .frame(width: 760, height: 520)
}

#Preview("Revenue Summary") {
    RevenueAnalyticsSummaryView(
        summary: RevenueAnalyticsSummary(
            currencySummaries: [
                CurrencyAnalyticsSummary(
                    currencyCode: "AUD",
                    totalBilled: 4820,
                    totalReceived: 3160,
                    totalOutstanding: 1660,
                    totalOverdue: 420,
                    draftCount: 3,
                    totalInvoiceCount: 12
                )
            ],
            totalDraftCount: 3,
            totalInvoiceCount: 12
        )
    )
    .padding()
    .frame(width: 520)
}
#endif
