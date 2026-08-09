import Core
import PersistenceModels
import SharedUI
import SwiftData
import SwiftUI
import Observation

public struct ReconciliationDashboardView: View {
    let batchId: UUID
    @Bindable var viewModel: ClaimBatchesViewModel
    var onOpenDraft: ((UUID) -> Void)?
    @State private var selectedTab: ReconciliationTab = .paid
    @State private var lines: [BulkClaimLine] = []

    public init(batchId: UUID, viewModel: ClaimBatchesViewModel, onOpenDraft: ((UUID) -> Void)? = nil) {
        self.batchId = batchId
        self.viewModel = viewModel
        self.onOpenDraft = onOpenDraft
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Result", selection: $selectedTab) {
                ForEach(ReconciliationTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            filteredTable
        }
        .navigationTitle("Reconciliation")
        .task {
            lines = await viewModel.fetchLines(forBatch: batchId)
        }
    }

    private var filteredTable: some View {
        let filtered = linesFor(selectedTab)
        return Group {
            if filtered.isEmpty {
                Text("No \(selectedTab.rawValue.lowercased()) lines.")
                    .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filtered) {
                    TableColumn("Reference") { line in Text(line.claimReference ?? "-") }
                    TableColumn("Support") { line in Text(line.supportNumber) }
                    TableColumn("Status") { line in Text(line.submissionStatus ?? "-") }
                    TableColumn("Paid") { line in Text(line.ndiaPaidAmount.map { CurrencyFormatting.display($0) } ?? "-") }
                    TableColumn("Error") { line in Text(line.ndiaErrorCode ?? line.ndiaErrorMessage ?? "-") }
                    TableColumn("") { line in
                        if let draftLineId = line.draftLineId, onOpenDraft != nil {
                            Button("Go to Draft") {
                                Task {
                                    var resolved = billableDraftId(for: line)
                                    if resolved == nil {
                                        resolved = try? await viewModel.draftId(containingClaimableLineId: draftLineId)
                                    }
                                    if let resolved {
                                        onOpenDraft?(resolved)
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .width(100)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Prefer in-memory `claimableLines` when the batch builder linked them; otherwise falls back to a one-row lookup.
    private func billableDraftId(for line: BulkClaimLine) -> UUID? {
        guard let draftLineId = line.draftLineId else { return nil }
        if let claim = line.claimableLines?.first(where: { $0.id == draftLineId }) {
            return claim.draftId
        }
        return nil
    }

    private func linesFor(_ tab: ReconciliationTab) -> [BulkClaimLine] {
        switch tab {
        case .paid:
            return lines.filter { ($0.submissionStatus?.lowercased()).map { $0 == "paid" || $0 == "accepted" || $0 == "reconciled" } ?? false }
        case .capped:
            return lines.filter { ($0.submissionStatus?.lowercased()).map { $0.contains("cap") } ?? false }
        case .rejected:
            return lines.filter { line in
                let status = line.submissionStatus?.lowercased() ?? ""
                return status == "rejected" || line.ndiaErrorCode != nil || line.ndiaErrorMessage != nil
            }
        case .unmatched:
            return lines.filter { $0.submissionStatus == nil && $0.ndiaErrorCode == nil }
        }
    }
}

public enum ReconciliationTab: String, CaseIterable {
    case paid = "Paid"
    case capped = "Capped"
    case rejected = "Rejected"
    case unmatched = "Unmatched"
}
