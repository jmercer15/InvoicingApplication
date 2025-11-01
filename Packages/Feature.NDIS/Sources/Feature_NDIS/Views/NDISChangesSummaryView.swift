import SwiftUI
import SwiftData // Import SwiftData
import Data
import Core
import SharedUI

struct NDISChangesSummaryView: View {
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @State private var changesSummary: NDISChangesSummary?
    @State private var isLoading = true
    @State private var selectedItemForHistory: String?
    @State private var itemChanges: [NDISItemChange] = []
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Analyzing NDIS changes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            summarySection
                            historicalAnalysisSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("NDIS Historical Changes")
            .onAppear {
                loadChangesSummary()
            }
            .sheet(item: Binding<NDISIdentifiableString?>(
                get: { selectedItemForHistory.map(NDISIdentifiableString.init) },
                set: { selectedItemForHistory = $0?.value }
            )) { item in
                ItemHistoryDetailView(itemNumber: item.value, itemChanges: itemChanges)
            }
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            NDISChangesSectionHeader(icon: "chart.bar.fill", title: "NDIS Catalogue Overview")
            
            if let summary = changesSummary {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    NDISChangesSummaryCard(
                        title: "Unique Items",
                        value: "\(summary.totalUniqueItems)",
                        subtitle: "Individual NDIS items",
                        color: .blue
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Total Versions",
                        value: "\(summary.totalVersions)",
                        subtitle: "All item versions",
                        color: .green
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Current Items",
                        value: "\(summary.currentItems)",
                        subtitle: "Active as of today",
                        color: .orange
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Historical Items",
                        value: "\(summary.historicalItems)",
                        subtitle: "Past versions",
                        color: .purple
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Items with Changes",
                        value: "\(summary.itemsWithChanges)",
                        subtitle: String(format: "%.1f%% of items", summary.changesPercentage),
                        color: .red
                    )
                    
                    NDISChangesSummaryCard(
                        title: "Avg Versions per Item",
                        value: String(format: "%.1f", Double(summary.totalVersions) / Double(max(summary.totalUniqueItems, 1))),
                        subtitle: "Version history depth",
                        color: .indigo
                    )
                }
            }
        }
        .formSectionBackground()
    }
    
    private var historicalAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            NDISChangesSectionHeader(icon: "clock.arrow.circlepath", title: "Historical Analysis")
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Search for an item to view its change history:")
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    
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
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
        }
        .formSectionBackground()
    }
    
    private func loadChangesSummary() {
        Task {
            do {
                let summary = try NDISVersioningService.getChangesSummary(in: modelContext)
                await MainActor.run {
                    self.changesSummary = summary
                    self.isLoading = false
                }
            } catch {
                print("Error loading changes summary: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadItemHistory(for itemNumber: String) {
        Task {
            do {
                let changes = try NDISVersioningService.analyzeItemChanges(itemNumber: itemNumber, in: modelContext)
                await MainActor.run {
                    self.itemChanges = changes
                    self.selectedItemForHistory = itemNumber
                }
            } catch {
                print("Error loading item history: \(error)")
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                .multilineTextAlignment(.leading)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ItemHistoryDetailView: View {
    let itemNumber: String
    let itemChanges: [NDISItemChange]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Item History: \(itemNumber)")
                    .font(.title2.bold())
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if itemChanges.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            Text("No Changes Found")
                                .font(.title2)
                            Text("This item has no recorded change history, or the item number wasn't found.")
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(itemChanges.indices, id: \.self) { index in
                            ChangeCard(change: itemChanges[index])
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct ChangeCard: View {
    let change: NDISItemChange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(change.changeType.rawValue)
                    .font(.headline)
                    .foregroundColor(colorForChangeType(change.changeType))
                
                Spacer()
                
                Text(formatDate(change.changeDate))
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            VStack(alignment: .leading, spacing: 8) {
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
                    ChangeRow(label: "Quote Required", oldValue: change.previousVersion.quoteRequired ? "Yes" : "No", newValue: change.newVersion.quoteRequired ? "Yes" : "No")
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
                
                // Handle features changes (array comparison)
                let oldFeatures = change.previousVersion.features
                let newFeatures = change.newVersion.features
                if oldFeatures.sorted() != newFeatures.sorted() {
                    ChangeRow(label: "Features", oldValue: oldFeatures.joined(separator: ", "), newValue: newFeatures.joined(separator: ", "))
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
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorForChangeType(change.changeType).opacity(0.3), lineWidth: 1)
        )
    }
    
    private func colorForChangeType(_ type: NDISChangeType) -> Color {
        switch type {
        case .nameChanged: return .blue
        case .categoryChanged: return .orange
        case .unitChanged: return .green
        case .quoteRequirementChanged: return .purple
        
        case .priceChanged: return .yellow
        case .newItem: return .mint
        case .discontinued: return .gray
        case .removed: return .red
        case .registrationChanged: return .indigo
        case .descriptionChanged, .typeChanged, .categoryNumberChanged, .categoryNamePACEChanged, .categoryNumberPACEChanged, .registrationGroupChanged, .registrationGroupNumberChanged, .nonFaceToFaceProvisionChanged, .providerTravelChanged, .shortNoticeCancellationsChanged, .ndiaRequestedReportsChanged, .irregularSILSupportsChanged, .regionalPricesChanged, .featuresChanged, .effectiveDateRangeChanged: return .teal // Group new changes under teal
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatPrices(_ prices: [String: Double]) -> String {
        return prices.map { key, value in "\(key): $\(String(format: "%.2f", value))" }.joined(separator: "; ")
    }
}

struct ChangeRow: View {
    let label: String
    let oldValue: String
    let newValue: String
    let showDiff: Bool = true // Always show diff in this context
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            
            HStack {
                Text(oldValue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("Red70", bundle: .sharedUI).opacity(0.29))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(Text("OLD").font(.caption2).foregroundColor(Color("Red", bundle: .sharedUI)), alignment: .topTrailing)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                
                Text(newValue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("Green20", bundle: .sharedUI))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(Text("NEW").font(.caption2).foregroundColor(Color("Green", bundle: .sharedUI)), alignment: .topTrailing)
            }
        }
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
                    .foregroundColor(Color("Primary", bundle: .sharedUI))
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

extension View {
    func formSectionBackground() -> some View {
        self
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let container = try! ModelContainer(for: NDISItemEntity.self)
    NDISChangesSummaryView()
        .environment(\.modelContext, container.mainContext)
} 
