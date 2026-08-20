import Core
import PersistenceModels
import SharedUI
import SwiftData
import SwiftUI
import Observation

public struct BillableDraftDetailView: View {
    let draftId: UUID
    @State private var draft: BillableDraft?
    @Bindable var viewModel: BillableDraftsViewModel
    var onAddToClaimBatch: ((UUID) -> Void)?
    var onCreateInvoice: ((UUID) -> Void)?
    @Environment(\.modelContext) private var modelContext

    private var issues: [DraftIssue] {
        guard let entity = draft, let issueEntities = entity.issues else { return [] }
        return issueEntities.sorted { ($0.createdAt) < ($1.createdAt) }
    }
    private var lines: [ClaimableLine] {
        guard let entity = draft, let itemEntities = entity.items else { return [] }
        return itemEntities.sorted { $0.serviceFrom < $1.serviceFrom }
    }

    @State private var errorMessage: String?
    @State private var isBusy = false

    public init(
        draftId: UUID,
        viewModel: BillableDraftsViewModel,
        onAddToClaimBatch: ((UUID) -> Void)? = nil,
        onCreateInvoice: ((UUID) -> Void)? = nil
    ) {
        self.draftId = draftId
        self.viewModel = viewModel
        self.onAddToClaimBatch = onAddToClaimBatch
        self.onCreateInvoice = onCreateInvoice
    }

    public var body: some View {
        Form {
            if let d = draft {
                Section("Status") {
                    Text(d.draftStatus)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                }
            }
            Section("Issues") {
                if issues.isEmpty {
                    Text("No issues")
                        .foregroundStyle(StyleGuide.Colors.textSecondary.opacity(0.6))
                } else {
                    ForEach(issues, id: \.id) { issue in
                        HStack {
                            Image(systemName: issue.severity == .blocking ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(issue.severity == .blocking ? ColorSystem.Status.error : ColorSystem.Status.warning)
                            Text(issue.message)
                        }
                    }
                }
            }
            Section("Claimable Lines") {
                ForEach(lines, id: \.id) { line in
                    Text("\(line.supportItemNumber) – \(line.claimType)")
                }
            }
        }
        .navigationTitle("Draft Detail")
        .toolbar {
            if hasToolbarActions {
                ToolbarItem(placement: .primaryAction) {
                    AppToolbarActionsMenu(help: "Draft workflow actions") {
                        if let d = draft, d.draftStatus != DraftStatus.locked.rawValue {
                            Section("Workflow") {
                                if d.draftStatus != DraftStatus.ready.rawValue {
                                    Button {
                                        markReady()
                                    } label: {
                                        Label("Mark Ready", systemImage: "checkmark.circle")
                                    }
                                    .disabled(isBusy)
                                }
                                Button {
                                    lockDraft()
                                } label: {
                                    Label("Lock Draft", systemImage: "lock.fill")
                                }
                                .disabled(isBusy)
                            }
                        }

                        if onAddToClaimBatch != nil || onCreateInvoice != nil {
                            Section("Billing") {
                                if onAddToClaimBatch != nil,
                                   draft?.draftStatus == DraftStatus.ready.rawValue
                                   || draft?.draftStatus == DraftStatus.locked.rawValue {
                                    Button {
                                        onAddToClaimBatch?(draftId)
                                    } label: {
                                        Label("Add to Claim Batch", systemImage: "tray.and.arrow.down")
                                    }
                                    .disabled(isBusy)
                                }
                                if onCreateInvoice != nil {
                                    Button {
                                        onCreateInvoice?(draftId)
                                    } label: {
                                        Label("Create Invoice", systemImage: "doc.badge.plus")
                                    }
                                    .disabled(isBusy)
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(ColorSystem.Status.error)
                    .padding(StyleGuide.Dimensions.paddingMedium)
            }
        }
        .task(id: draftId) {
            var descriptor = FetchDescriptor<BillableDraft>(predicate: #Predicate<BillableDraft> { $0.id == draftId })
            descriptor.fetchLimit = 1
            draft = try? modelContext.fetch(descriptor).first
        }
    }

    private var hasToolbarActions: Bool {
        guard let draft else { return false }
        return draft.draftStatus != DraftStatus.locked.rawValue
            || onAddToClaimBatch != nil
            || onCreateInvoice != nil
    }

    private func markReady() {
        guard let d = draft else { return }
        isBusy = true
        errorMessage = nil
        Task {
            do {
                try viewModel.markReady(draft: d)
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func lockDraft() {
        guard let d = draft else { return }
        isBusy = true
        errorMessage = nil
        Task {
            do {
                try viewModel.lockDraft(draft: d)
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }
}
