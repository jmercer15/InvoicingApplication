import SwiftUI
import SwiftData // Import SwiftData
import Data
import Core
import SharedUI
import Observation

struct NDISChangesSummaryView: View {
    @Bindable var viewModel: NDISContainerViewModel
    @State private var isLoading = true
    @State private var selectedItemForHistory: String?
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                        ProgressView {
                            Text("Analyzing NDIS changes...")
                                .font(StyleGuide.Typography.itemTitle)
                                .foregroundStyle(StyleGuide.Colors.textSecondary)
                        }
                        .scaleEffect(1.2)
                    }
                    .frame(width: 320, height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                            .fill(PanelShellTokens.panelSecondaryBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                            .stroke(StyleGuide.Colors.border, lineWidth: ListRowTokens.defaultStrokeWidth)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.changesError != nil || viewModel.changesSummary == nil {
                    VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(StyleGuide.Typography.hero)
                            .foregroundStyle(ColorSystem.Status.error)
                        
                        Text("Failed to Analyze NDIS Changes")
                            .font(StyleGuide.Typography.sectionTitle)
                            .foregroundStyle(StyleGuide.Colors.text)
                        
                        Text(viewModel.changesError?.localizedDescription ?? "No changes summary data found.")
                            .font(StyleGuide.Typography.caption)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                        
                        Button(action: {
                            loadChangesSummary()
                        }) {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .frame(width: 360, height: 240)
                    .background(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                            .fill(PanelShellTokens.panelSecondaryBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                            .stroke(StyleGuide.Colors.border, lineWidth: ListRowTokens.defaultStrokeWidth)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: StyleGuide.Dimensions.paddingSheetContent) {
                            summarySection
                            historicalAnalysisSection
                        }
                        .standardContentPanelListInsets()
                    }
                }
            }
            .standardPanelShell(role: .singlePanel)
            .navigationTitle("NDIS Historical Changes")
            .onAppear {
                loadChangesSummary()
            }
            .sheet(item: Binding<NDISIdentifiableString?>(
                get: { selectedItemForHistory.map(NDISIdentifiableString.init) },
                set: { selectedItemForHistory = $0?.value }
            )) { item in
                ItemHistoryDetailView(itemNumber: item.value, itemChanges: viewModel.itemChanges)
            }
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) {
            NDISChangesSectionHeader(icon: "chart.bar.fill", title: "NDIS Catalogue Overview")
            
            if let summary = viewModel.changesSummary {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: FormSectionTokens.formGroupSpacing) {
                    NDISChangesSummaryCard(
                        title: "Unique Items",
                        value: "\(summary.totalUniqueItems)",
                        subtitle: "Individual NDIS items",
                        color: ColorSystem.Primary.blue
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Total Versions",
                        value: "\(summary.totalVersions)",
                        subtitle: "All item versions",
                        color: ColorSystem.Secondary.green
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Current Items",
                        value: "\(summary.currentItems)",
                        subtitle: "Active as of today",
                        color: ColorSystem.Secondary.orange
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Historical Items",
                        value: "\(summary.historicalItems)",
                        subtitle: "Past versions",
                        color: ColorSystem.Secondary.purple
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Items with Changes",
                        value: "\(summary.itemsWithChanges)",
                        subtitle: String(format: "%.1f%% of items", summary.changesPercentage),
                        color: ColorSystem.Status.error
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Avg Versions per Item",
                        value: String(format: "%.1f", Double(summary.totalVersions) / Double(max(summary.totalUniqueItems, 1))),
                        subtitle: "Version history depth",
                        color: ColorSystem.Navigation.groupTint
                    )
                }
            }
        }
        .formSectionBackground()
    }
    
    private var historicalAnalysisSection: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) {
            NDISChangesSectionHeader(icon: "clock.arrow.circlepath", title: "Historical Analysis")
            
            VStack(alignment: .leading, spacing: FormSectionTokens.sectionStackSpacing) {
                Text("Search for an item to view its change history:")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                    
                    TextField("Enter NDIS item number...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !searchText.isEmpty {
                                loadItemHistory(for: searchText)
                            }
                        }
                    
                    Button("Analyze") {
                        if !searchText.isEmpty {
                            loadItemHistory(for: searchText)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(searchText.isEmpty)
                }
                
                Text("Example: 01_001_0103_6_1, 15_001_0101_6_1")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            
            if viewModel.isAnalyzingChanges {
                ProgressView("Analyzing...")
                    .padding(.top, StyleGuide.Dimensions.paddingMedium)
            }
        }
        .formSectionBackground()
    }
    
    private func loadChangesSummary() {
        isLoading = true
        Task {
            await viewModel.fetchChangesSummary()
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadItemHistory(for itemNumber: String) {
        Task {
            await viewModel.loadItemHistory(for: itemNumber)
            await MainActor.run {
                self.selectedItemForHistory = itemNumber
            }
        }
    }
}

struct NDISChangesSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
            Text(title)
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .multilineTextAlignment(.leading)
            
            Text(value)
                .font(StyleGuide.Typography.hero)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(StyleGuide.Typography.micro)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StyleGuide.Dimensions.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                .fill(PanelShellTokens.panelSecondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                        .stroke(color.opacity(StyleGuide.Opacity.strong), lineWidth: ListRowTokens.defaultStrokeWidth)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value). \(subtitle)")
    }
}

struct ItemHistoryDetailView: View {
    let itemNumber: String
    let itemChanges: [NDISItemChange]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: FormSectionTokens.formGroupSpacing) {
            // Header
            HStack {
                Text("Item History: \(itemNumber)")
                    .font(StyleGuide.Typography.hero)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.glass)
            }
            .standardPanelContentPadding()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) {
                    if itemChanges.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Changes Found",
                            message: "This item has no recorded change history, or the item number wasn't found."
                        )
                        .frame(maxWidth: .infinity)
                        .standardPanelContentPadding()
                    } else {
                        ForEach(itemChanges.indices, id: \.self) { index in
                            ChangeCard(change: itemChanges[index])
                        }
                    }
                }
                .standardContentPanelListInsets()
            }
        }
    }
}

struct ChangeCard: View {
    let change: NDISItemChange
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.sectionStackSpacing) {
            HStack {
                Text(change.changeType.rawValue)
                    .font(StyleGuide.Typography.sectionTitle)
                    .foregroundColor(colorForChangeType(change.changeType))
                
                Spacer()
                
                Text(formatDate(change.changeDate))
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                // Use non-optional properties directly
                if change.previousVersion.name != change.newVersion.name {
                    ChangeRow(label: "Name", oldValue: change.previousVersion.name, newValue: change.newVersion.name)
                }
                
                if change.previousVersion.registrationGroup != change.newVersion.registrationGroup {
                    ChangeRow(label: "Category", oldValue: change.previousVersion.registrationGroup ?? "", newValue: change.newVersion.registrationGroup ?? "")
                }
                
                if change.previousVersion.unit != change.newVersion.unit {
                    ChangeRow(label: "Unit", oldValue: change.previousVersion.unit ?? "", newValue: change.newVersion.unit ?? "")
                }
                
                if change.previousVersion.quoteRequired != change.newVersion.quoteRequired {
                    ChangeRow(
                        label: "Quote Required",
                        oldValue: (change.previousVersion.quoteRequired == true) ? "Yes" : "No",
                        newValue: (change.newVersion.quoteRequired == true) ? "Yes" : "No"
                    )
                }
                
                // Add other attribute comparisons from NDISItem
                // Note: itemDescription is not available in NDISItemSnapshot
                
                // Note: type property is not available in NDISItemSnapshot
                
                // Note: categoryNumber property is not available in NDISItemSnapshot
                
                // Note: categoryNamePACE property is not available in NDISItemSnapshot
                
                // Note: categoryNumberPACE property is not available in NDISItemSnapshot
                
                if change.previousVersion.registrationGroup != change.newVersion.registrationGroup {
                    ChangeRow(label: "Registration Group", oldValue: change.previousVersion.registrationGroup ?? "", newValue: change.newVersion.registrationGroup ?? "")
                }
                
                // Note: registrationGroupNumber property is not available in NDISItemSnapshot
                
                // Note: nonFaceToFaceProvision property is not available in NDISItemSnapshot
                
                // Note: providerTravel property is not available in NDISItemSnapshot
                
                // Note: shortNoticeCancellations property is not available in NDISItemSnapshot
                
                // Note: ndiaRequestedReports property is not available in NDISItemSnapshot
                
                // Note: irregularSILSupports property is not available in NDISItemSnapshot
                
                // Handle features changes (string comparison)
                let oldFeatures = (change.previousVersion.features ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let newFeatures = (change.newVersion.features ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if oldFeatures != newFeatures {
                    ChangeRow(label: "Features", oldValue: oldFeatures, newValue: newFeatures)
                }

                // Effective Date Changes
                let oldStartDate = change.previousVersion.effectiveStartDate
                let newStartDate = change.newVersion.effectiveStartDate
                if oldStartDate != newStartDate {
                    ChangeRow(label: "Effective Start Date", oldValue: formatDate(oldStartDate ?? Date.distantPast), newValue: formatDate(newStartDate ?? Date.distantPast))
                }
                
                let oldEndDate = change.previousVersion.effectiveEndDate
                let newEndDate = change.newVersion.effectiveEndDate
                if oldEndDate != newEndDate {
                    let oldEndDateString = oldEndDate.map(formatDate) ?? "Present"
                    let newEndDateString = newEndDate.map(formatDate) ?? "Present"
                    ChangeRow(label: "Effective End Date", oldValue: oldEndDateString, newValue: newEndDateString)
                }
            }
        }
        .padding(StyleGuide.Dimensions.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                .fill(StyleGuide.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                        .stroke(colorForChangeType(change.changeType).opacity(StyleGuide.Opacity.strong), lineWidth: ListRowTokens.defaultStrokeWidth)
                )
        )
        .accessibilityElement(children: .combine)
    }
    
    private func colorForChangeType(_ type: NDISChangeType) -> Color {
        switch type {
        case .nameChanged: return ColorSystem.Primary.blue
        case .categoryChanged: return ColorSystem.Secondary.orange
        case .unitChanged: return ColorSystem.Secondary.green
        case .quoteRequirementChanged: return ColorSystem.Secondary.purple
        
        case .priceChanged: return ColorSystem.Status.highlight
        case .newItem: return ColorSystem.Status.new
        case .discontinued: return ColorSystem.Status.inactive
        case .removed: return ColorSystem.Status.error
        case .registrationChanged: return ColorSystem.Navigation.groupTint
        case .descriptionChanged, .typeChanged, .categoryNumberChanged, .categoryNamePACEChanged, .categoryNumberPACEChanged, .registrationGroupChanged, .registrationGroupNumberChanged, .nonFaceToFaceProvisionChanged, .providerTravelChanged, .shortNoticeCancellationsChanged, .ndiaRequestedReportsChanged, .irregularSILSupportsChanged, .regionalPricesChanged, .featuresChanged, .effectiveDateRangeChanged: return ColorSystem.Status.groupChange
        }
    }
    
    private static let changeCardFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private func formatDate(_ date: Date) -> String {
        return Self.changeCardFormatter.string(from: date)
    }
}

struct ChangeRow: View {
    let label: String
    let oldValue: String
    let newValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
            Text(label)
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
            
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                    Text("OLD")
                        .font(StyleGuide.Typography.nano)
                        .foregroundStyle(.white)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                        .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                        .background(ColorSystem.Status.error)
                        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall))
                    
                    Text(oldValue)
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(StyleGuide.Colors.text)
                }
                .padding(StyleGuide.Dimensions.paddingSmall)
                .background(ColorSystem.Status.error.opacity(StyleGuide.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
                
                Image(systemName: "arrow.right")
                    .foregroundColor(StyleGuide.Colors.textSecondary)
                
                HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                    Text("NEW")
                        .font(StyleGuide.Typography.nano)
                        .foregroundStyle(.white)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                        .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                        .background(ColorSystem.Status.success)
                        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall))
                    
                    Text(newValue)
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(StyleGuide.Colors.text)
                }
                .padding(StyleGuide.Dimensions.paddingSmall)
                .background(ColorSystem.Status.success.opacity(StyleGuide.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) changed from \(oldValue) to \(newValue)")
    }
}

struct NDISIdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct NDISChangesSectionHeader: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
                            Image(systemName: icon)
                    .foregroundStyle(ColorSystem.Primary.blue)
            Text(title)
                .font(StyleGuide.Typography.sectionTitle)
        }
    }
}

