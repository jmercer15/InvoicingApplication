import AppKit
import Core
import SwiftUI
import SharedUI
import UniformTypeIdentifiers
import Observation

public struct ReconcileBPRFImportView: View {
    let batchId: UUID
    @Bindable var viewModel: ClaimBatchesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var fileData: Data?
    @State private var parsedResults: [IdentifiableBPRFRow] = []
    @State private var parseError: String?
    @State private var isImporting = false
    @State private var importResult: (updatedLineCount: Int, unmatchedReferences: [String])?
    @State private var isParsing = false

    public init(batchId: UUID, viewModel: ClaimBatchesViewModel) {
        self.batchId = batchId
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) {
            if isParsing {
                ProgressView("Parsing file…")
            } else if fileData == nil {
                Button("Choose BPRF file…") {
                    presentOpenPanel()
                }
                .buttonStyle(.borderedProminent)
            } else {
                if let err = parseError {
                    Text(err)
                        .foregroundColor(Color(NSColor.systemRed))
                } else {
                    Text("\(parsedResults.count) result lines loaded. Review and confirm import.")
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                    Table(parsedResults) {
                        TableColumn("Claim reference") { row in Text(row.line.claimReference) }
                        TableColumn("Status") { row in Text(row.line.submissionStatus) }
                        TableColumn("Paid") { row in
                            Text(row.line.paidAmount.map(String.init(describing:)) ?? "-")
                        }
                        TableColumn("Error") { row in Text(row.line.errorCode ?? row.line.errorMessage ?? "-") }
                    }
                    .frame(minHeight: 200)
                }
            }
            if let result = importResult {
                Text("Updated \(result.updatedLineCount) lines.")
                    .foregroundColor(Color(NSColor.systemGreen))
                if !result.unmatchedReferences.isEmpty {
                    Text("Unmatched: \(result.unmatchedReferences.prefix(5).joined(separator: ", "))\(result.unmatchedReferences.count > 5 ? "…" : "")")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.orange))
                }
            }
            Spacer(minLength: 0)
            HStack {
                if importResult != nil {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                } else if fileData != nil, parseError == nil {
                    Button("Confirm import") { runImport() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isImporting)
                    Button("Choose another file") {
                        fileData = nil
                        parsedResults = []
                        parseError = nil
                        presentOpenPanel()
                    }
                }
                Spacer(minLength: 0)
                Button("Cancel") { dismiss() }
            }
        }
        .padding()
        .frame(minWidth: StyleGuide.Dimensions.settingsReconcileMinWidth, minHeight: StyleGuide.Dimensions.settingsReconcileMinHeight)
        .navigationTitle("Import BPRF")
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            isParsing = true
            Task {
                do {
                    let vm = viewModel
                    let (data, lines) = try await Task(priority: .userInitiated) {
                        let data = try Data(contentsOf: url)
                        let lines = try vm.parseBPRF(data: data)
                        return (data, lines)
                    }.value
                    await MainActor.run {
                        fileData = data
                        parseError = nil
                        parsedResults = lines.enumerated().map { IdentifiableBPRFRow(id: $0.offset, line: $0.element) }
                        isParsing = false
                    }
                } catch {
                    await MainActor.run {
                        parseError = error.localizedDescription
                        parsedResults = []
                        isParsing = false
                    }
                }
            }
        }
    }

    private func runImport() {
        guard let data = fileData else { return }
        isImporting = true
        Task {
            do {
                let result = try await viewModel.importBPRF(batchId: batchId, data: data)
                await MainActor.run {
                    importResult = result
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    parseError = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

private struct IdentifiableBPRFRow: Identifiable {
    let id: Int
    let line: BPRFResultLine
}
