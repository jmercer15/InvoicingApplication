import AppKit
import Core
import Data
import SwiftData
import SwiftUI
import SharedUI
import UniformTypeIdentifiers
import Observation

public struct ClaimBatchBuildWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ClaimBatchesViewModel
    @Environment(\.dismiss) var dismiss

    private struct DraftTaskId: Equatable {
        let from: Date
        let to: Date
        let planType: String?
        let clientId: UUID?
        let draftCount: Int
        let clientCount: Int
    }
    private var draftTaskId: DraftTaskId {
        DraftTaskId(
            from: fromDate,
            to: toDate,
            planType: planManagementType,
            clientId: clientId,
            draftCount: drafts.count,
            clientCount: allClients.count
        )
    }

    private func filteredDrafts(from draftEntities: [BillableDraft], clientEntities: [Client]) -> [BillableDraft] {
        var list: [BillableDraft] = draftEntities
        let range = fromDate ... toDate
        list = list.filter({ range.contains($0.computedAt) })
        if let cid = clientId {
            list = list.filter({ $0.clientId == cid })
        }
        if let planType = planManagementType, !planType.isEmpty {
            let allowedClientIds = Set(clientEntities.filter { $0.planManagementType == planType }.map(\.id))
            list = list.filter({ allowedClientIds.contains($0.clientId) })
        }
        return list.filter({ $0.draftStatus == DraftStatus.ready.rawValue || $0.draftStatus == DraftStatus.locked.rawValue })
    }

    @State private var step: WizardStep = .configure
    @State private var fromDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var toDate = Date()
    @State private var planManagementType: String?
    @State private var clientId: UUID?
    @State private var drafts: [BillableDraft] = []
    @State private var allClients: [Client] = []
    @State private var allUnbilledDrafts: [BillableDraft] = []
    @State private var selectedDraftIds: Set<UUID> = []
    @State private var createdBatch: BulkClaimBatch?
    @State private var isBuilding = false
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var exportFileName: String?
    /// When true, `WizardBatchExportCoordinator` runs CSV export using its `@Query` line snapshot.
    @State private var exportPending = false

    private let initialDraftIds: Set<UUID>?

    private enum WizardStep: Int, CaseIterable {
        case configure = 0
        case selectDrafts
        case build
        case export
    }

    public init(viewModel: ClaimBatchesViewModel, initialDraftIds: Set<UUID>? = nil) {
        self.viewModel = viewModel
        self.initialDraftIds = initialDraftIds
    }

    public var body: some View {
        VStack(spacing: 0) {
            stepIndicator
            Divider()
            Group {
                switch step {
                case .configure: configureStep
                case .selectDrafts: selectDraftsStep
                case .build: buildStep
                case .export: exportStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            Divider()
            footer
        }
        .frame(minWidth: StyleGuide.Dimensions.settingsSheetMinWidth, minHeight: StyleGuide.Dimensions.settingsSheetMinHeight)
        .navigationTitle("New Claim Batch")
        .task {
            do {
                // Yield to ensure UI layout finishes before database work
                try? await Task.sleep(for: .milliseconds(50))
                
                var clientDescriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.fullName)])
                clientDescriptor.propertiesToFetch = [\.fullName]
                allClients = try modelContext.fetch(clientDescriptor)
                
                let readyStatus = "ready"
                let lockedStatus = "locked"
                let predicate = #Predicate<BillableDraft> {
                    $0.draftStatus == readyStatus || $0.draftStatus == lockedStatus
                }
                var draftDescriptor = FetchDescriptor<BillableDraft>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.computedAt, order: .reverse)]
                )
                // Minimally fetch properties needed for wizard filtering
                draftDescriptor.propertiesToFetch = [\.draftStatus]
                allUnbilledDrafts = try modelContext.fetch(draftDescriptor)
                
                if let ids = initialDraftIds, !ids.isEmpty {
                    await applyInitialDrafts(ids: ids)
                }
            } catch {
                print("Failed to load reference data for wizard: \(error)")
            }
        }
        .task(id: draftTaskId) {
            drafts = filteredDrafts(from: allUnbilledDrafts, clientEntities: allClients)
            selectedDraftIds = Set(drafts.map(\.id))
        }
        .background {
            if let batch = createdBatch {
                WizardBatchExportCoordinator(
                    batch: batch,
                    viewModel: viewModel,
                    pendingExport: $exportPending,
                    isExporting: $isExporting,
                    exportFileName: $exportFileName,
                    errorMessage: $errorMessage,
                    presentSavePanel: { data, suggestedName, completion in
                        presentSavePanel(data: data, suggestedName: suggestedName, completion: completion)
                    }
                )
            }
        }
    }

    private func applyInitialDrafts(ids: Set<UUID>) async {
        let fetched = allUnbilledDrafts.filter { ids.contains($0.id) }
        guard !fetched.isEmpty else { return }
        let dates = fetched.map(\.computedAt)
        if let minDate = dates.min(), let maxDate = dates.max() {
            fromDate = Calendar.current.startOfDay(for: minDate)
            toDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: maxDate)) ?? maxDate
        }
        selectedDraftIds = ids
        step = .selectDrafts
    }

    private var stepIndicator: some View {
        HStack(spacing: FormSectionTokens.fieldStackSpacing) {
            ForEach(Array(WizardStep.allCases.enumerated()), id: \.element.rawValue) { index, s in
                let isActive = s.rawValue == step.rawValue
                let isPast = s.rawValue < step.rawValue
                Text(stepTitle(s))
                    .font(.caption)
                    .foregroundColor(isActive ? Color(NSColor.controlAccentColor) : (isPast ? Color(NSColor.secondaryLabelColor) : Color(NSColor.tertiaryLabelColor)))
                if index < WizardStep.allCases.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                }
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingXMedium)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func stepTitle(_ s: WizardStep) -> String {
        switch s {
        case .configure: return "Date range"
        case .selectDrafts: return "Select drafts"
        case .build: return "Build"
        case .export: return "Export"
        }
    }

    private var configureStep: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) {
            Text("Set the date range for sessions included in the batch.")
                .font(.body)
                .foregroundColor(Color(NSColor.secondaryLabelColor))
            HStack(spacing: FormSectionTokens.formGroupSpacing) {
                DatePicker("From", selection: $fromDate, displayedComponents: .date)
                DatePicker("To", selection: $toDate, displayedComponents: .date)
            }
            Spacer(minLength: 0)
        }
    }

    private var selectDraftsStep: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
            Text("Select drafts to include. Only ready or locked drafts are listed.")
                .font(.body)
                .foregroundColor(Color(NSColor.secondaryLabelColor))
            if drafts.isEmpty {
                Text("No drafts in range.")
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(drafts) { draft in
                        Toggle(isOn: Binding(
                            get: { selectedDraftIds.contains(draft.id) },
                            set: { if $0 { selectedDraftIds.insert(draft.id) } else { selectedDraftIds.remove(draft.id) } }
                        )) {
                            Text("Draft \(draft.id.uuidString.prefix(8))... · \(draft.draftStatus)")
                        }
                    }
                }
                .listStyle(.inset)
            }
            Spacer(minLength: 0)
        }
    }

    private var buildStep: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.sectionStackSpacing) {
            if let batch = createdBatch {
                Label("Batch created: \(batch.rowCount) lines.", systemImage: "checkmark.circle.fill")
                    .foregroundColor(Color(NSColor.systemGreen))
            } else if isBuilding {
                ProgressView("Building batch…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Build the batch from the selected drafts.")
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
            Spacer(minLength: 0)
        }
    }

    private var exportStep: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.sectionStackSpacing) {
            if let name = exportFileName {
                Label("Exported as \(name)", systemImage: "checkmark.circle.fill")
                    .foregroundColor(Color(NSColor.systemGreen))
            } else if isExporting {
                ProgressView("Preparing export…")
            } else if createdBatch != nil {
                Text("Export the batch as a CSV file for submission.")
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack {
            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(Color(NSColor.systemRed))
            }
            Spacer(minLength: 0)
            if step.rawValue > 0 {
                Button("Back") {
                    errorMessage = nil
                    if step == .export { exportFileName = nil }
                    if step == .build { createdBatch = nil }
                    step = WizardStep(rawValue: step.rawValue - 1) ?? .configure
                }
            }
            Button(step == .export && exportFileName != nil ? "Done" : "Next") {
                handleNext()
            }
            .buttonStyle(.borderedProminent)
            .disabled(nextDisabled)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingXMedium)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var nextDisabled: Bool {
        switch step {
        case .configure: return false
        case .selectDrafts: return selectedDraftIds.isEmpty
        case .build: return isBuilding || createdBatch == nil
        case .export: return isExporting
        }
    }

    private func handleNext() {
        errorMessage = nil
        switch step {
        case .configure:
            step = .selectDrafts
        case .selectDrafts:
            step = .build
            runBuild()
        case .build:
            step = .export
        case .export:
            if exportFileName != nil {
                dismiss()
                return
            }
            exportPending = true
        }
    }

    private func runBuild() {
        guard createdBatch == nil else { return }
        isBuilding = true
        let selected = drafts.filter { selectedDraftIds.contains($0.id) }
        Task {
            do {
                let batch = try await viewModel.createBatch(from: selected, fromDate: fromDate, toDate: toDate)
                await MainActor.run {
                    createdBatch = batch
                    isBuilding = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isBuilding = false
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

// MARK: - Export coordinator
private struct WizardBatchExportCoordinator: View {
    let batch: BulkClaimBatch
    @Bindable var viewModel: ClaimBatchesViewModel
    @Binding var pendingExport: Bool
    @Binding var isExporting: Bool
    @Binding var exportFileName: String?
    @Binding var errorMessage: String?
    let presentSavePanel: (Data, String, @escaping (String?) -> Void) -> Void

    init(
        batch: BulkClaimBatch,
        viewModel: ClaimBatchesViewModel,
        pendingExport: Binding<Bool>,
        isExporting: Binding<Bool>,
        exportFileName: Binding<String?>,
        errorMessage: Binding<String?>,
        presentSavePanel: @escaping (Data, String, @escaping (String?) -> Void) -> Void
    ) {
        self.batch = batch
        self.viewModel = viewModel
        _pendingExport = pendingExport
        _isExporting = isExporting
        _exportFileName = exportFileName
        _errorMessage = errorMessage
        self.presentSavePanel = presentSavePanel
    }

    var body: some View {
        Color.clear
            .frame(
                width: StyleGuide.Dimensions.hiddenFrameWidth,
                height: StyleGuide.Dimensions.hiddenFrameHeight
            )
            .accessibilityHidden(true)
            .onChange(of: pendingExport) { _, shouldExport in
                guard shouldExport else { return }
                pendingExport = false
                runExportUsingQuerySnapshot()
            }
    }

    private func runExportUsingQuerySnapshot() {
        isExporting = true
        Task { @MainActor in
            do {
                let lines = await viewModel.fetchLines(forBatch: batch.id)
                let (data, fileName, checksum) = try viewModel.prepareExport(lines: lines)
                presentSavePanel(data, fileName) { savedName in
                    if let savedName {
                        Task { @MainActor in
                            try? await viewModel.markExported(
                                batch: batch,
                                fileName: savedName,
                                checksumSHA256: checksum,
                                lineCount: lines.count
                            )
                            exportFileName = savedName
                            isExporting = false
                        }
                    } else {
                        isExporting = false
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
                isExporting = false
            }
        }
    }
}
