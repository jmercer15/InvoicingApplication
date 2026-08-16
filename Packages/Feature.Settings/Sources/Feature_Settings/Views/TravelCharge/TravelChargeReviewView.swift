import SwiftUI
import SwiftData
import Core
import DataInterfaces
import SharedUI
import Observation

struct TravelChargeReviewView: View {
    @State private var viewModel: TravelChargeReviewViewModel

    @State private var selectedReviewItem: TravelChargeReviewRow?
    @State private var showingViolationDetails = false
    @State private var showingReviewSheet = false

    init(viewModel: @autoclosure @escaping () -> TravelChargeReviewViewModel) {
        _viewModel = State(initialValue: viewModel())
    }

    private var pendingReviewItems: [TravelChargeReviewRow] {
        viewModel.reviewItemEntities.filter { $0.status == "pending" }
    }

    private var filteredReviewItems: [TravelChargeReviewRow] {
        switch viewModel.filterStatus {
        case .all:
            return viewModel.reviewItemEntities
        case .pending:
            return pendingReviewItems
        case .resolved:
            return viewModel.reviewItemEntities.filter { $0.status == "resolved" }
        case .overridden:
            return viewModel.reviewItemEntities.filter { $0.status == "overridden" }
        case .skipped:
            return viewModel.reviewItemEntities.filter { $0.status == "skipped" }
        }
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VStack(spacing: FormSectionTokens.pageStackSpacing) {
                // Header
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    HStack {
                        Text("Travel Charge Review")
                            .font(.title2.bold())
                        Spacer()
                        Button("Review All Pending") {
                            showingReviewSheet = true
                        }
                        .buttonStyle(.glassProminent)
                        .pointerStyle(.link)
                        .disabled(pendingReviewItems.isEmpty)
                    }
                    
                    Text("Review and resolve travel charge compliance violations")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                .standardCardStyle()
                
                // Status Filter
                HStack {
                    Text("Filter:")
                        .font(.headline)
                    
                    Picker("Status", selection: $bindableViewModel.filterStatus) {
                        ForEach(TravelChargeReviewViewModel.ReviewStatusFilter.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Filter by status")
                    .accessibilityHint("Filter review items by their status")
                    
                    Spacer()
                    
                    Text("\(filteredReviewItems.count) items")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                .standardCardStyle()
                
                // Review Items List
                if filteredReviewItems.isEmpty {
                    VStack(spacing: FormSectionTokens.formGroupSpacing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(StyleGuide.Typography.emptyStateIcon)
                            .foregroundColor(ColorSystem.Status.success)
                        Text("No Review Items")
                            .font(.title2.bold())
                        Text("All travel charges are compliant or have been resolved.")
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: FormSectionTokens.sectionStackSpacing) {
                            ForEach(filteredReviewItems) { reviewItem in
                                ReviewItemCard(reviewItem: reviewItem) {
                                    selectedReviewItem = reviewItem
                                    showingViolationDetails = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
        }
        .sheet(isPresented: $showingViolationDetails) {
            if let reviewItem = selectedReviewItem {
                TravelChargeViolationDetailsView(viewModel: viewModel, reviewItem: reviewItem)
            }
        }
        .sheet(isPresented: $showingReviewSheet) {
            TravelChargeReviewSheetView(pendingReviews: pendingReviewItems)
        }
        .task {
            await viewModel.refreshReviews()
        }
    }
}

struct ReviewItemCard: View {
    let reviewItem: TravelChargeReviewRow
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                        Text(reviewItem.sessionTitle ?? "Unknown Session")
                            .font(.headline)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        if let clientName = reviewItem.clientName {
                            Text("Client: \(clientName)")
                                .font(.body)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        }
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: reviewItem.status)
                }
                
                if let reason = reviewItem.reason {
                    Text(reason)
                        .font(.body)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .lineLimit(2)
                }
                
                HStack {
                    if reviewItem.hasViolations {
                        Label("\(reviewItem.violationCount) violations", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(ColorSystem.Status.error)
                    }
                    
                    Spacer()
                    
                    if let timestamp = reviewItem.timestamp {
                        Text(timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    }
                }
            }
            .standardCardStyle()
            .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
}

// Note: StatusBadge is already defined in ViewStyles.swift

struct TravelChargeViolationDetailsView: View {
    @Bindable var viewModel: TravelChargeReviewViewModel
    let reviewItem: TravelChargeReviewRow
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedOverride: String = ""
    @State private var overrideReason: String = ""
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                        Text("Compliance Violations")
                            .font(.title2.bold())
                        Text("Review and resolve compliance violations for this travel charge")
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Session Information
                    GroupBox("Session Details") {
                        VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                            Text("Session: \(reviewItem.sessionTitle ?? "Unknown")")
                                .font(.headline)
                            if let clientName = reviewItem.clientName {
                                Text("Client: \(clientName)")
                                    .font(.body)
                            }
                            if let timestamp = reviewItem.timestamp {
                                Text("Date: \(DateFormatting.mediumDateTime(timestamp))")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            }
                        }
                    }
                    
                    // Violations List
                    if let violations = reviewItem.violationDetails, !violations.isEmpty {
                        GroupBox("Violations") {
                            VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                                ForEach(violations, id: \.self) { violation in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(ColorSystem.Status.error)
                                        Text(violation)
                                            .font(.body)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Override Options
                    if let overrideOptions = reviewItem.overrideOptions, !overrideOptions.isEmpty {
                        GroupBox("Override Options") {
                            VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                                Text("Select an override option if you want to proceed despite violations:")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                
                                ForEach(overrideOptions, id: \.self) { option in
                                    Button(action: {
                                        selectedOverride = option
                                    }) {
                                        HStack {
                                            Image(systemName: selectedOverride == option ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedOverride == option ? .accentColor : .secondary)
                                            Text(option)
                                                .foregroundColor(Color("Text", bundle: .sharedUI))
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if !selectedOverride.isEmpty {
                                    TextField("Reason for override (optional)", text: $overrideReason, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(3...6)
                                }
                            }
                        }
                    }
                    
                    // Suggested Actions
                    if let suggestedActions = reviewItem.suggestedActions, !suggestedActions.isEmpty {
                        GroupBox("Suggested Actions") {
                            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                                ForEach(suggestedActions, id: \.self) { action in
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundColor(ColorSystem.Status.info)
                                        Text(action)
                                            .font(.body)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Action Buttons
                    HStack(spacing: FormSectionTokens.formGroupSpacing) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.glass)
                        .pointerStyle(.link)
                        
                        Spacer()
                        
                        if !selectedOverride.isEmpty {
                            Button("Override and Create") {
                                handleOverrideAction()
                            }
                            .buttonStyle(.glassProminent)
                            .pointerStyle(.link)
                            .disabled(isProcessing)
                        }
                        
                        Button("Skip Charge") {
                            handleSkipAction()
                        }
                        .buttonStyle(.glass)
                        .pointerStyle(.link)
                        .disabled(isProcessing)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: StyleGuide.Dimensions.settingsSheetStandardMinWidth, minHeight: StyleGuide.Dimensions.settingsSheetReviewMinHeight)
    }
    
    private func handleOverrideAction() {
        isProcessing = true
        
        Task {
            await viewModel.resolveWithOverride(
                reviewModelID: reviewItem.persistentModelID,
                overrideType: selectedOverride,
                reason: overrideReason.isEmpty ? nil : overrideReason
            )
            
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        }
    }
    
    private func handleSkipAction() {
        isProcessing = true
        
        Task {
            await viewModel.resolveBySkipping(reviewModelID: reviewItem.persistentModelID)
            
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        }
    }
}

struct TravelChargeReviewSheetView: View {
    let pendingReviews: [TravelChargeReviewRow]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    HStack {
                        Text("Pending Reviews")
                            .font(.title2.bold())
                        Spacer()
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.glass)
                        .pointerStyle(.link)
                    }
                    
                    Text("\(pendingReviews.count) items require attention")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                .padding(.horizontal)
                
                // Pending Reviews List
                if pendingReviews.isEmpty {
                    VStack(spacing: FormSectionTokens.formGroupSpacing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(StyleGuide.Typography.emptyStateIcon)
                            .foregroundColor(ColorSystem.Status.success)
                        Text("No Pending Reviews")
                            .font(.title2.bold())
                        Text("All travel charge reviews have been resolved.")
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: FormSectionTokens.sectionStackSpacing) {
                            ForEach(pendingReviews) { reviewItem in
                                ReviewItemCard(reviewItem: reviewItem) {
                                    // Navigate to violation details
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .frame(minWidth: StyleGuide.Dimensions.settingsSheetLargeMinWidth, minHeight: StyleGuide.Dimensions.settingsSheetLargeMinHeight)
    }
}

// MARK: - Supporting Types
// Note: `BusinessRules`, `UserPreferences`, and related automation types ship with Core travel automation
// (`Packages/Core/Sources/Core/Services/TravelChargeAutomationService.swift`); boundary DTOs are under
// `Packages/Core/Sources/Core/Models/Snapshots/`.
