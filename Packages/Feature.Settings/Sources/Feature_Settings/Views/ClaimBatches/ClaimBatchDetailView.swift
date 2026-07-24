import AppKit
import Core
import Data
import SharedUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import Observation

public struct ClaimBatchDetailView: View {
    let batchId: UUID
    @State private var batch: BulkClaimBatch?
    @Bindable var viewModel: ClaimBatchesViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var lines: [BulkClaimLine] = []

    @State private var showBPRFImport = false
    @State private var showReconciliation = false
    @State private var preflightSummary: String?
    @State private var errorMessage: String?
    @State private var isBusy = false

    public init(batchId: UUID, viewModel: ClaimBatchesViewModel) {
        self.batchId = batchId
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(Color(NSColor.systemRed))
                    .padding(.horizontal)
            }
            if let summary = preflightSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    .padding(.horizontal)
            }
            Table(lines) {
                TableColumn("Reference") { line in Text(line.claimReference ?? "-") }
                TableColumn("Support Number") { line in Text(line.supportNumber) }
                TableColumn("NDIS Number") { line in Text(line.ndisNumber) }
                TableColumn("Hours") { line in Text(line.hours ?? "-") }
                TableColumn("Unit Price") { line in Text(String(format: "%.2f", line.unitPrice)) }
                TableColumn("Status") { line in Text(line.submissionStatus ?? "-") }
            }
        }
        .navigationTitle("Batch Detail")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AppToolbarActionsMenu(help: "Batch export, validation, and reconciliation") {
                    Section("Export") {
                        Button {
                            runPreflight()
                        } label: {
                            Label("Run Preflight", systemImage: "checkmark.shield")
                        }
                        .disabled(isBusy)

                        Button {
                            exportCSV()
                        } label: {
                            Label("Export CSV…", systemImage: "square.and.arrow.down")
                        }
                        .disabled(isBusy || lines.isEmpty)

                        Button {
                            markSubmitted()
                        } label: {
                            Label("Mark Submitted", systemImage: "paperplane.fill")
                        }
                        .disabled(isBusy)
                    }

                    Section("Reconciliation") {
                        Button {
                            showBPRFImport = true
                        } label: {
                            Label("Import BPRF…", systemImage: "doc.badge.arrow.up")
                        }

                        Button {
                            showReconciliation = true
                        } label: {
                            Label("Reconciliation", systemImage: "arrow.triangle.merge")
                        }
                        .disabled(lines.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showBPRFImport) {
            ReconcileBPRFImportView(batchId: batchId, viewModel: viewModel)
        }
        .sheet(isPresented: $showReconciliation) {
            NavigationStack {
                ReconciliationDashboardContainer(batchId: batchId, viewModel: viewModel)
            }
        }
        .task(id: batchId) {
            var descriptor = FetchDescriptor<BulkClaimBatch>(predicate: #Predicate<BulkClaimBatch> { $0.id == batchId })
            descriptor.fetchLimit = 1
            batch = try? modelContext.fetch(descriptor).first
            self.lines = await viewModel.fetchLines(forBatch: batchId)
        }
    }

    private func runPreflight() {
        isBusy = true
        errorMessage = nil
        preflightSummary = nil
        Task {
            do {
                let result = try await viewModel.runPreflight(lines: lines)
                await MainActor.run {
                    preflightSummary = "\(result.summary.validRows)/\(result.summary.totalRows) valid"
                    isBusy = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isBusy = false
                }
            }
        }
    }

    private func exportCSV() {
        isBusy = true
        errorMessage = nil
        Task {
            do {
                let (data, fileName, checksum) = try viewModel.prepareExport(lines: lines)
                guard let batchEntity = batch else {
                    await MainActor.run {
                        errorMessage = "Batch not found."
                        isBusy = false
                    }
                    return
                }
                await MainActor.run {
                    presentSavePanel(data: data, suggestedName: fileName) { savedName in
                        if let savedName = savedName {
                            Task {
                                let count = lines.count
                                try? await viewModel.markExported(
                                    batch: batchEntity,
                                    fileName: savedName,
                                    checksumSHA256: checksum,
                                    lineCount: count
                                )
                                await MainActor.run { isBusy = false }
                            }
                        } else {
                            isBusy = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isBusy = false
                }
            }
        }
    }

    private func markSubmitted() {
        isBusy = true
        errorMessage = nil
        Task {
            do {
                guard let batchEntity = batch else {
                    await MainActor.run {
                        errorMessage = "Batch not found."
                        isBusy = false
                    }
                    return
                }
                try await viewModel.markSubmitted(batch: batchEntity)
                await MainActor.run { isBusy = false }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isBusy = false
                }
            }
        }
    }

    private func presentSavePanel(data: Data, suggestedName: String, completion: @escaping (String?) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            Task {
                do {
                    try await Task.detached(priority: .userInitiated) {
                        try data.write(to: url)
                    }.value
                    completion(url.lastPathComponent)
                } catch {
                    completion(nil)
                }
            }
        }
    }
}
