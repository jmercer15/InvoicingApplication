import Core
import PersistenceModels
import SharedUI
import SwiftData
import SwiftUI
import Observation

public struct BillableDraftsHomeView: View {
    @Bindable var viewModel: BillableDraftsViewModel
    var onAddToClaimBatch: ((UUID) -> Void)?
    var onCreateInvoice: ((UUID) -> Void)?

    private var draftFilterSpec: BillableDraftFilterSpec {
        BillableDraftFilterSpec(
            status: viewModel.selectedStatus,
            dateRange: viewModel.dateRange,
            clientId: viewModel.filterClientId,
            planType: viewModel.filterPlanType,
            sectionByStatus: viewModel.selectedStatus == nil
        )
    }

    @State private var generateFrom = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var generateTo = Date()
    @State private var selectedSessionIds: Set<UUID> = []
    @State private var isGenerating = false
    @State private var generatedCount: Int?
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case generateDrafts

        var id: Self { self }
    }
    @State private var sessionWindowFrom: Date?
    @State private var sessionWindowTo: Date?

    public init(
        viewModel: BillableDraftsViewModel,
        onAddToClaimBatch: ((UUID) -> Void)? = nil,
        onCreateInvoice: ((UUID) -> Void)? = nil
    ) {
        self._viewModel = Bindable(viewModel)
        self.onAddToClaimBatch = onAddToClaimBatch
        self.onCreateInvoice = onCreateInvoice
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                filtersSection

                if let errorMsg = viewModel.errorMessage {
                    Text(errorMsg)
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(ColorSystem.Status.error)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(ColorSystem.Status.error.opacity(0.1))
                }

                BillableDraftsQueryList(filterSpec: draftFilterSpec)
            }
            .navigationTitle("Billable Drafts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    AppToolbarPrimaryCreateButton(
                        "Generate Drafts",
                        systemImage: "sparkles.rectangle.stack",
                        help: "Generate billable drafts from sessions"
                    ) {
                        activeSheet = .generateDrafts
                    }
                }
            }
            .navigationDestination(for: UUID.self) { draftId in
                BillableDraftDetailView(
                    draftId: draftId,
                    viewModel: viewModel,
                    onAddToClaimBatch: onAddToClaimBatch,
                    onCreateInvoice: onCreateInvoice
                )
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .generateDrafts:
                    generateDraftsSheet
                }
            }
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Status", selection: Binding(
                get: { viewModel.selectedStatus },
                set: { viewModel.setStatusFilter($0) }
            )) {
                Text("All").tag(DraftStatus?.none)
                ForEach(DraftStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(DraftStatus?.some(status))
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 16) {
                DatePicker("From", selection: Binding(
                    get: { viewModel.dateRange?.lowerBound ?? generateFrom },
                    set: {
                        viewModel.dateRange = $0 ... (viewModel.dateRange?.upperBound ?? generateTo)
                    }
                ), displayedComponents: .date)
                DatePicker("To", selection: Binding(
                    get: { viewModel.dateRange?.upperBound ?? generateTo },
                    set: {
                        viewModel.dateRange = (viewModel.dateRange?.lowerBound ?? generateFrom) ... $0
                    }
                ), displayedComponents: .date)
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
        .background(BillingHubTheme.Surfaces.panelBase)
    }

    private var generateDraftsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generate Drafts")
                .font(StyleGuide.Typography.sectionTitle)
            Text("Select a date range and sessions that don't have a draft yet.")
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
            HStack(spacing: 16) {
                DatePicker("From", selection: $generateFrom, displayedComponents: .date)
                DatePicker("To", selection: $generateTo, displayedComponents: .date)
                Button("Fetch sessions") {
                    sessionWindowFrom = generateFrom
                    sessionWindowTo = generateTo
                    selectedSessionIds.removeAll()
                    generatedCount = nil
                }
                .buttonStyle(.borderedProminent)
            }
            if let windowFrom = sessionWindowFrom, let windowTo = sessionWindowTo {
                BillableDraftSessionPickerList(
                    rangeFrom: windowFrom,
                    rangeTo: windowTo,
                    selectedSessionIds: $selectedSessionIds
                ) { sessions in
                    viewModel.applySessionsWithoutDraft(sessions)
                }
            }
            if let msg = viewModel.errorMessage {
                Text(msg)
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(ColorSystem.Status.error)
            }
            if generatedCount != nil {
                Text("Created \(generatedCount!) draft(s).")
                    .foregroundStyle(ColorSystem.Status.success)
            }
            HStack {
                if generatedCount != nil {
                    Button("Done") { activeSheet = nil }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Generate selected") {
                        Task { await runGenerate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSessionIds.isEmpty || isGenerating)
                }
                Spacer(minLength: 0)
                Button("Cancel") { activeSheet = nil }
            }
        }
        .padding()
        .frame(minWidth: BillingHubTheme.Dimensions.draftHomeMinWidth, minHeight: BillingHubTheme.Dimensions.draftHomeMinHeight)
    }

    private func runGenerate() async {
        isGenerating = true
        viewModel.errorMessage = nil
        defer { isGenerating = false }
        do {
            let count = try await viewModel.generateDrafts(forSessionIDs: Array(selectedSessionIds))
            generatedCount = count
            selectedSessionIds.removeAll()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
