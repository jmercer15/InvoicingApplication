import SwiftUI
import Charts
import SwiftData // Import SwiftData
import Data
import Core
import SharedUI

// MARK: - Price Extraction Utility

fileprivate struct PriceExtractor {
    /// Gets the most representative price from an NDIS item's regional pricing data
    /// Priority order: NATIONAL > NSW > VIC > QLD > First available > Quote Required indicator
    static func getRepresentativePrice(from item: NDISItemEntity) -> Double? {
        let prices = item.regionalPrices
        guard !prices.isEmpty else {
            return nil
        }
        
        // Priority order for price selection
        let priorityRegions = ["NATIONAL", "NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"]
        
        // Try to find price by priority order
        for region in priorityRegions {
            if let priceEntity = prices.first(where: { $0.regionIdentifier == region }), priceEntity.amount > 0 {
                return priceEntity.amount
            }
        }
        
        // If no priority regions found, try any other regions
        for priceEntity in prices {
            if priceEntity.amount > 0 {
                return priceEntity.amount
            }
        }
        
        return nil
    }
    
    /// Gets a formatted price string with fallback options
    static func getFormattedPrice(from item: NDISItemEntity) -> String {
        if let price = getRepresentativePrice(from: item) {
            return "$\(String(format: "%.2f", price))"
        }
        
        if item.quoteRequired == true {
            return "Quote Required"
        }
        
        return "No Price"
    }
    
    /// Gets the region name that was used for the representative price
    static func getRepresentativePriceRegion(from item: NDISItemEntity) -> String? {
        let prices = item.regionalPrices
        guard !prices.isEmpty else {
            return nil
        }
        
        let priorityRegions = ["NATIONAL", "NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"]
        
        for region in priorityRegions {
            if let priceEntity = prices.first(where: { $0.regionIdentifier == region }), priceEntity.amount > 0 {
                return region
            }
        }
        
        // Return first available region if no priority match
        return prices.first { $0.amount > 0 }?.regionIdentifier
    }
}

// StyleGuide moved to Components/StyleGuide.swift

// MARK: - Main Detail View
struct EnhancedSupportItemDetailView: View {
    let item: NDISItemEntity
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @State private var selectedRegion: String = ""
    
    // Available regions from the item's pricing data
    private var availableRegions: [String] {
        let prices = item.regionalPrices
        let allRegions = Array(prices.compactMap { $0.regionIdentifier }).sorted()
        
        // Prioritize common regions first
        let priorityRegions = ["NATIONAL", "NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT", "Remote", "Very Remote"]
        var sortedRegions: [String] = []
        
        // Add priority regions that exist in data
        for region in priorityRegions {
            if allRegions.contains(region) {
                sortedRegions.append(region)
            }
        }
        
        // Add any remaining regions
        for region in allRegions {
            if !sortedRegions.contains(region) {
                sortedRegions.append(region)
            }
        }
        
        return sortedRegions
    }
    
    private var selectedPrice: Double? {
        let prices = item.regionalPrices
        return prices.first(where: { $0.regionIdentifier == selectedRegion })?.amount
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: StyleGuide.sectionSpacing) {
                // Hero Header Section
                HeaderView(item: item, selectedRegion: selectedRegion, selectedPrice: selectedPrice)
                
                Divider()
                    .background(Color("White10", bundle: .sharedUI))
                    .padding(.vertical, 8)
                
                // Category, Registration, and Item Details in HStack
                HStack(spacing: StyleGuide.sectionSpacing) {
                    CategoryInfoSectionView(item: item)
                    RegistrationInfoSectionView(item: item)
                    ItemDetailsSectionView(item: item)
                }
                
                Divider()
                    .background(Color("White10", bundle: .sharedUI))
                    .padding(.vertical, 8)
                
                // Provision and Service Delivery Section
                ProvisionServiceSectionView(item: item)
                
                Divider()
                    .background(Color("White10", bundle: .sharedUI))
                    .padding(.vertical, 8)
                
                // Regional pricing selector (enhanced)
                if !availableRegions.isEmpty {
                    EnhancedRegionalPricingSelectorView(
                        availableRegions: availableRegions,
                        selectedRegion: $selectedRegion,
                        selectedPrice: selectedPrice,
                        allPrices: item.regionalPrices,
                        unit: item.unit
                    )
                } else {
                    NoPricingDataView()
                }
                
                // Features section (if available)
                if let features = item.features, !features.isEmpty {
                    Divider()
                        .background(Color("White10", bundle: .sharedUI))
                        .padding(.vertical, 8)
                    
                    FeatureSectionView(features: features.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                }
                
                Divider()
                    .background(Color("White10", bundle: .sharedUI))
                    .padding(.vertical, 8)
                
                // Pricing History Section
                PricingHistorySectionView(item: item, selectedRegion: selectedRegion) // Pass modelContext
                
                // Version Comparison Section
                VersionComparisonSectionView(item: item, selectedRegion: selectedRegion) // Pass modelContext
            }
            .padding(.horizontal, StyleGuide.horizontalPadding)
            .padding(.top, StyleGuide.sectionSpacing)
            .padding(.bottom, 40)
        }
        .background(Color("Background", bundle: .sharedUI).ignoresSafeArea())
        .foregroundColor(Color("Text", bundle: .sharedUI))
        .onAppear {
            // Set initial region to the best available region
            if selectedRegion.isEmpty && !availableRegions.isEmpty {
                selectedRegion = availableRegions.first!
            }
        }
    }
}

// MARK: - Enhanced Regional Pricing Selector
fileprivate struct EnhancedRegionalPricingSelectorView: View {
    let availableRegions: [String]
    @Binding var selectedRegion: String
    let selectedPrice: Double?
    let allPrices: [RegionalPriceEntity]
    let unit: String?
    
    @State private var showingAllPrices = false
    
    var sortedPricesByValue: [(region: String, price: Double)] {
        return allPrices.compactMap { price in
            guard let region = price.regionIdentifier, price.amount > 0 else { return nil }
            return (region: region, price: price.amount)
        }.sorted { $0.price > $1.price }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with selector
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Regional Pricing")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(allPrices.count) regions available")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                
                Spacer()
                
                // Region selector with enhanced styling
                Menu {
                    ForEach(availableRegions, id: \.self) { region in
                        Button(action: {
                            selectedRegion = region
                        }) {
                            HStack {
                                Text(region)
                                Spacer()
                                if let price = allPrices.first(where: { $0.regionIdentifier == region })?.amount {
                                    Text("$\(String(format: "%.2f", price))")
                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                }
                                if region == selectedRegion {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color("Primary", bundle: .sharedUI))
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedRegion)
                            .fontWeight(.medium)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(Color("Primary", bundle: .sharedUI))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            
            // Featured price display
            if let price = selectedPrice {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("$\(String(format: "%.2f", price))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        if !(unit ?? "").isEmpty {
                            Text("per \(unit ?? "")")
                                .font(.subheadline)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                .padding(.leading, 4)
                        }
                        
                        Spacer()
                        
                        // Show all prices toggle
                        if allPrices.count > 1 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingAllPrices.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(showingAllPrices ? "Hide" : "Show All")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Image(systemName: showingAllPrices ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundColor(Color("Primary", bundle: .sharedUI))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("White05", bundle: .sharedUI))
                )
            }
            
            // Show all prices grid when expanded
            if showingAllPrices && allPrices.count > 1 {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(sortedPricesByValue, id: \.region) { item in
                        PriceGridItem(
                            region: item.region,
                            price: item.price,
                            isSelected: item.region == selectedRegion,
                            onTap: {
                                selectedRegion = item.region
                            }
                        )
                    }
                }
                .fluidModalTransition()
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color("White10", bundle: .sharedUI), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
    }
    
    private func getPriceRank() -> Int? {
        guard let selectedPrice = selectedPrice else { return nil }
        let sortedPrices = allPrices.map { $0.amount }.sorted(by: >)
        return sortedPrices.firstIndex(of: selectedPrice).map { $0 + 1 }
    }
    
    private func getPriceComparison() -> String? {
        guard let selectedPrice = selectedPrice, allPrices.count > 1 else { return nil }
        let allPricesArray = allPrices.map { $0.amount }
        let avgPrice = allPricesArray.reduce(0, +) / Double(allPricesArray.count)
        let difference = selectedPrice - avgPrice
        let percentDiff = abs(difference / avgPrice) * 100
        
        if abs(difference) < 0.01 {
            return "At average price"
        } else if difference > 0 {
            return "\(String(format: "%.1f", percentDiff))% above average"
        } else {
            return "\(String(format: "%.1f", percentDiff))% below average"
        }
    }
}

fileprivate struct PriceGridItem: View {
    let region: String
    let price: Double
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(region)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? Color("Primary", bundle: .sharedUI) : Color("Text", bundle: .sharedUI))
                    .lineLimit(1)
                
                Text("$\(String(format: "%.2f", price))")
                    .font(.caption2)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .glassEffect(.regular, in: .rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color("Primary", bundle: .sharedUI) : Color("White15", bundle: .sharedUI), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - No Pricing Data View
fileprivate struct NoPricingDataView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(Color("Inactive", bundle: .sharedUI))
            
            Text("No Pricing Data Available")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("This item may require a quote or have pricing determined by individual service providers.")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("Black30", bundle: .sharedUI))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("Orange", bundle: .sharedUI).opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 4)
    }
}

// MARK: - Header Components
fileprivate struct HeaderView: View {
    let item: NDISItemEntity // Change to NDISItem
    let selectedRegion: String
    let selectedPrice: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(StyleGuide.Header.titleFont)
                        .kerning(1.0)
                        .shadow(color: StyleGuide.shadowColor, radius: 2, x: 0, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    if !item.itemNumber.isEmpty {
                        InfoRow(label: "Item Number", value: item.itemNumber)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, StyleGuide.horizontalPadding)
        .padding(.vertical, 20)
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
    }
}

fileprivate struct BadgeRow: View {
    let item: NDISItemEntity // Change to NDISItem
    
    var body: some View {
        HStack(spacing: 8) {
            if let category = item.category, !category.isEmpty {
                HeaderBadge(text: category)
            }
            if let registrationGroup = item.registrationGroup, !registrationGroup.isEmpty {
                HeaderBadge(text: registrationGroup)
            }

            if item.quoteRequired == true {
                HeaderBadge(text: "Quote Required")
            }
            
            // Version status badge
            if !item.isCurrent {
                HeaderBadge(text: "Historical")
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("Orange", bundle: .sharedUI), lineWidth: 1)
                    )
            } else {
                HeaderBadge(text: "Current")
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("Green", bundle: .sharedUI), lineWidth: 1)
                    )
            }
            
            Spacer() // Pushes badges to the left
        }
    }
}

fileprivate struct HeaderBadge: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color("White20", bundle: .sharedUI), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            .shadow(color: StyleGuide.shadowColor, radius: 1, x: 0, y: 1)
    }
}

// MARK: - Feature Section
fileprivate struct FeatureSectionView: View {
    let features: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Features")
                .font(StyleGuide.Section.titleFont)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(features, id: \.self) { featureText in
                        FeatureCard(feature: featureText)
                    }
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color("White10", bundle: .sharedUI), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
    }
}

fileprivate struct FeatureCard: View {
    let feature: String
    private static let iconMapping: [String: String] = [
        "travel": "car.fill", "support": "person.2.fill", "therapy": "cross.case.fill",
        "equipment": "wrench.and.screwdriver.fill", "training": "graduationcap.fill",
        "plan": "doc.text.fill", "community": "person.3.fill", "communication": "bubble.left.and.bubble.right.fill",
        "transport": "bus.fill", "home": "house.fill", "care": "heart.fill",
        "assistive": "figure.walk", "consumable": "cart.fill", "interpreter": "mic.fill",
        "building": "building.2.fill", "education": "book.fill", "employment": "briefcase.fill",
        "assessment": "checkmark.seal.fill", "coordination": "arrow.triangle.branch",
        "management": "gearshape.fill"
    ]

    var iconName: String {
        let lowercasedFeature = feature.lowercased()
        for (key, icon) in Self.iconMapping {
            if lowercasedFeature.contains(key) {
                return icon
            }
        }
        return "star.fill" // Default icon
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundColor(Color("Text", bundle: .sharedUI))
            Text(feature)
                .font(.caption.weight(.medium))
                .foregroundColor(Color("Text", bundle: .sharedUI))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color("Green", bundle: .sharedUI), Color("Green", bundle: .sharedUI).opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}


// MARK: - Pricing Section
fileprivate struct PricingSectionView: View {
    let prices: [String: Double]
    let unit: String
    
    // Defines a canonical order for Australian states/territories
    private var sortedPrices: [(key: String, value: Double)] {
        let stateOrder = ["NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"]
        let statePrices = stateOrder.compactMap { state in
            prices[state].map { (key: state, value: $0) }
        }
        let otherPrices = prices
            .filter { !stateOrder.contains($0.key) }
            .sorted { $0.key < $1.key }
        
        return statePrices + otherPrices
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pricing")
                .font(StyleGuide.Section.titleFont)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 14)], spacing: 14) {
                ForEach(sortedPrices, id: \.key) { region, price in
                    PricingChip(region: region, price: price, unit: unit)
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
    }
}

fileprivate struct PricingChip: View {
    let region: String
    let price: Double
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(region)
                .font(.caption.weight(.medium))
            Text(price, format: .currency(code: "AUD"))
                .font(.headline.weight(.semibold))
            Text(unit)
                .font(.footnote)
                .opacity(0.7)
        }
        .frame(width: 90)
        .padding(.vertical, 8)
        .background(Color("Background", bundle: .sharedUI).opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Pricing History Section
fileprivate struct PricingHistorySectionView: View {
    let item: NDISItemEntity // Change to NDISItem
    let selectedRegion: String
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @State private var allVersions: [NDISItemEntity] = [] // Change to NDISItem
    @State private var isLoadingVersions = false
    
    var sortedVersions: [NDISItemEntity] { // Change to NDISItem
        allVersions.sorted { version1, version2 in
            let date1 = version1.effectiveStartDate ?? Date.distantPast
            let date2 = version2.effectiveStartDate ?? Date.distantPast
            return date1 > date2 // Newest first
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pricing History")
                .font(StyleGuide.Section.titleFont)
            
            VStack(alignment: .leading, spacing: 8) {
                if !item.isCurrent {
                    Text("⚠️ This is a historical version. It may not reflect current NDIS pricing or availability.")
                        .font(.caption)
                        .foregroundColor(Color("Inactive", bundle: .sharedUI))
                        .padding(.top, 4)
                }
            }
            
            // Price trend chart
            if allVersions.count > 1 {
                PriceTrendChartView(
                    versions: sortedVersions,
                    selectedRegion: selectedRegion,
                    currentItemId: item.id
                )
            } else {
                Text("No pricing history available")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
        .onAppear {
            loadVersionHistory()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentPrice(_ item: NDISItemEntity) -> Double? { // Change to NDISItem
        if selectedRegion.isEmpty {
            return PriceExtractor.getRepresentativePrice(from: item)
        }
        return item.regionalPrices.first(where: { $0.regionIdentifier == selectedRegion })?.amount
    }
    
    private func getPreviousPrice() -> Double? {
        let currentIndex = sortedVersions.firstIndex(where: { $0.id == item.id }) ?? 0
        guard currentIndex + 1 < sortedVersions.count else { return nil }
        let previousVersion = sortedVersions[currentIndex + 1]
        
        if selectedRegion.isEmpty {
            return PriceExtractor.getRepresentativePrice(from: previousVersion)
        }
        return previousVersion.regionalPrices.first(where: { $0.regionIdentifier == selectedRegion })?.amount
    }
    
    private func loadVersionHistory() {
        isLoadingVersions = true
        Task {
            do {
                // Use FetchDescriptor without predicate to avoid complex predicate issues
                let descriptor = FetchDescriptor<NDISItemEntity>(
                    sortBy: [SortDescriptor(\.effectiveStartDate, order: .reverse)]
                )
                
                let allVersions = try modelContext.fetch(descriptor)
                // Filter by itemNumber and name in memory to avoid complex predicate
                let versions = allVersions.filter { $0.itemNumber == item.itemNumber && $0.name == item.name }
                
                await MainActor.run {
                    self.allVersions = versions
                    self.isLoadingVersions = false
                }
            } catch {
                print("Error loading version history: \(error)")
                await MainActor.run {
                    self.isLoadingVersions = false
                }
            }
        }
    }
}

// MARK: - Version Comparison Section
fileprivate struct VersionComparisonSectionView: View {
    let item: NDISItemEntity // Change to NDISItem
    let selectedRegion: String
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @State private var allVersions: [NDISItemEntity] = [] // Change to NDISItem
    @State private var isLoadingVersions = false
    @State private var showingVersionHistory = false
    @State private var comparisonVersion: NDISItemEntity? // Change to NDISItemEntity
    
    var sortedVersions: [NDISItemEntity] { // Change to NDISItem
        allVersions.sorted { version1, version2 in
            let date1 = version1.effectiveStartDate ?? Date.distantPast
            let date2 = version2.effectiveStartDate ?? Date.distantPast
            return date1 > date2 // Newest first
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Version Comparison")
                    .font(StyleGuide.Section.titleFont)
                
                Spacer()
                
                if allVersions.count > 1 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingVersionHistory.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: showingVersionHistory ? "chevron.down" : "chevron.right")
                                .font(.caption)
                            Text("Compare (\(allVersions.count) versions)")
                        }
                        .font(.caption)
                        .foregroundColor(Color("Primary", bundle: .sharedUI))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Version comparison view
            if showingVersionHistory && allVersions.count > 1 {
                VersionComparisonView(
                    currentVersion: item,
                    versions: sortedVersions,
                    selectedComparisonId: $comparisonVersion,
                    selectedRegion: selectedRegion
                )
            } else if allVersions.count > 1 {
                Text("Tap 'Compare' to view detailed version differences")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .padding(.vertical, 20)
            } else {
                Text("No version history available for comparison")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
        .onAppear {
            loadVersionHistory()
        }
    }
    
    private func loadVersionHistory() {
        isLoadingVersions = true
        Task {
            do {
                // Use FetchDescriptor without predicate to avoid complex predicate issues
                let descriptor = FetchDescriptor<NDISItemEntity>(
                    sortBy: [SortDescriptor(\.effectiveStartDate, order: .reverse)]
                )
                
                let allVersions = try modelContext.fetch(descriptor)
                // Filter by itemNumber and name in memory to avoid complex predicate
                let versions = allVersions.filter { $0.itemNumber == item.itemNumber && $0.name == item.name }
                
                await MainActor.run {
                    self.allVersions = versions
                    self.isLoadingVersions = false
                }
            } catch {
                print("Error loading version history: \(error)")
                await MainActor.run {
                    self.isLoadingVersions = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentPrice(_ item: NDISItemEntity) -> Double? { // Change to NDISItem
        if selectedRegion.isEmpty {
            return PriceExtractor.getRepresentativePrice(from: item)
        }
        return item.regionalPrices.first(where: { $0.regionIdentifier == selectedRegion })?.amount
    }
    
    private func getPreviousPrice() -> Double? {
        let currentIndex = sortedVersions.firstIndex(where: { $0.id == item.id }) ?? 0
        guard currentIndex + 1 < sortedVersions.count else { return nil }
        let previousVersion = sortedVersions[currentIndex + 1]
        
        if selectedRegion.isEmpty {
            return PriceExtractor.getRepresentativePrice(from: previousVersion)
        }
        return previousVersion.regionalPrices.first(where: { $0.regionIdentifier == selectedRegion })?.amount
    }
    
    private func exportVersionHistory() {
        let summary = generateVersionSummary()
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(item.itemNumber)_version_history.txt"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                try? summary.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func copyVersionSummary() {
        let summary = generateVersionSummary()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }
    
    private func generateVersionSummary() -> String {
        var summary = "NDIS Item Version History\n"
        summary += "========================\n\n"
        summary += "Item: \(item.name)\n"
        summary += "Number: \(item.itemNumber)\n"
        summary += "Category: \(item.category ?? "N/A")\n"
        if !selectedRegion.isEmpty {
            summary += "Pricing Region: \(selectedRegion)\n"
        }
        summary += "\n"
        
        for (index, version) in sortedVersions.enumerated() {
            summary += "Version \(index + 1):\n"
            summary += "  Effective: \(version.effectiveDateRange)\n"
            summary += "  Status: \(version.isCurrent ? "Current" : "Historical")\n"
            
            if let price = getCurrentPrice(version) {
                if !selectedRegion.isEmpty {
                    summary += "  Price (\(selectedRegion)): $\(String(format: "%.2f", price))\n"
                } else {
                    summary += "  Price: $\(String(format: "%.2f", price))\n"
                }
            }
            
            if !version.versionIdentifier.isEmpty { // Use non-optional versionIdentifier
                summary += "  Version ID: \(version.versionIdentifier)\n"
            }
            
            summary += "\n"
        }
        
        return summary
    }
}

// MARK: - Item Details Section
fileprivate struct ItemDetailsSectionView: View {
    let item: NDISItemEntity // Change to NDISItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Item Details")
                .font(StyleGuide.Section.titleFont)
            
            VStack(alignment: .leading, spacing: 8) {
                if let type = item.type, !type.isEmpty { // Use non-optional type
                    InfoRow(label: "Type", value: type)
                }
                InfoRow(label: "Quote Required", value: item.quoteRequired == true ? "Yes" : "No")
            }
            
            Spacer()
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Category Information Section
fileprivate struct CategoryInfoSectionView: View {
    let item: NDISItemEntity // Change to NDISItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category Information")
                .font(StyleGuide.Section.titleFont)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Category", value: item.category ?? "N/A")
                if let categoryNumber = item.categoryNumber, !categoryNumber.isEmpty {
                    InfoRow(label: "Category Number", value: categoryNumber)
                }
                if let categoryNamePACE = item.categoryNamePACE, !categoryNamePACE.isEmpty {
                    InfoRow(label: "PACE Category", value: categoryNamePACE)
                }
                if let categoryNumberPACE = item.categoryNumberPACE, !categoryNumberPACE.isEmpty {
                    InfoRow(label: "PACE Category #", value: categoryNumberPACE)
                }
            }
            
            Spacer()
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Registration Information Section
fileprivate struct RegistrationInfoSectionView: View {
    let item: NDISItemEntity // Change to NDISItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Registration Information")
                .font(StyleGuide.Section.titleFont)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Registration Group", value: item.registrationGroup ?? "N/A")
                if let registrationGroupNumber = item.registrationGroupNumber, !registrationGroupNumber.isEmpty {
                    InfoRow(label: "Group Number", value: registrationGroupNumber)
                }
            }
            
            Spacer()
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Provision and Service Delivery Section
fileprivate struct ProvisionServiceSectionView: View {
    let item: NDISItemEntity // Change to NDISItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Provision & Service Delivery")
                .font(StyleGuide.Section.titleFont)
            
            HStack(alignment: .top, spacing: 16) {
                // Yes Group
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color("Active", bundle: .sharedUI))
                            .font(.caption)
                        Text("Enabled")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("Active", bundle: .sharedUI))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if item.nonFaceToFaceProvision == true {
                            ProvisionItem(label: "Non-Face-to-Face Provision", description: "Can be provided remotely")
                        }
                        if item.providerTravel == true {
                            ProvisionItem(label: "Provider Travel", description: "Travel costs included")
                        }
                        if item.shortNoticeCancellations == true {
                            ProvisionItem(label: "Short Notice Cancellations", description: "Allows short notice cancellation")
                        }
                        if item.ndiaRequestedReports == true {
                            ProvisionItem(label: "NDIA Requested Reports", description: "Requires NDIA reporting")
                        }
                        if item.irregularSILSupports == true {
                            ProvisionItem(label: "Irregular SIL Supports", description: "Supports irregular SIL arrangements")
                        }
                        
                        let hasAnyTrue = (item.nonFaceToFaceProvision == true) || 
                                       (item.providerTravel == true) || 
                                       (item.shortNoticeCancellations == true) || 
                                       (item.ndiaRequestedReports == true) || 
                                       (item.irregularSILSupports == true)
                        
                        if !hasAnyTrue {
                            Text("None")
                                .font(.caption2)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                .italic()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // No Group
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color("Cancelled", bundle: .sharedUI))
                            .font(.caption)
                        Text("Disabled")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("Cancelled", bundle: .sharedUI))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if item.nonFaceToFaceProvision == false {
                            ProvisionItem(label: "Non-Face-to-Face Provision", description: "Can be provided remotely")
                        }
                        if item.providerTravel == false {
                            ProvisionItem(label: "Provider Travel", description: "Travel costs included")
                        }
                        if item.shortNoticeCancellations == false {
                            ProvisionItem(label: "Short Notice Cancellations", description: "Allows short notice cancellation")
                        }
                        if item.ndiaRequestedReports == false {
                            ProvisionItem(label: "NDIA Requested Reports", description: "Requires NDIA reporting")
                        }
                        if item.irregularSILSupports == false {
                            ProvisionItem(label: "Irregular SIL Supports", description: "Supports irregular SIL arrangements")
                        }
                        
                        let hasAnyFalse = (item.nonFaceToFaceProvision == false) || 
                                        (item.providerTravel == false) || 
                                        (item.shortNoticeCancellations == false) || 
                                        (item.ndiaRequestedReports == false) || 
                                        (item.irregularSILSupports == false)
                        
                        if !hasAnyFalse {
                            Text("None")
                                .font(.caption2)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                .italic()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Provision Item Component
fileprivate struct ProvisionItem: View {
    let label: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color("Text", bundle: .sharedUI))
            
            Text(description)
                .font(.caption2)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
        }
    }
}

fileprivate struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Enhanced Version History Components

fileprivate struct PriceTrendIndicator: View {
    let currentPrice: Double
    let previousPrice: Double
    
    var priceChange: Double {
        currentPrice - previousPrice
    }
    
    var percentageChange: Double {
        guard previousPrice > 0 else { return 0 }
        return (priceChange / previousPrice) * 100
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priceChange > 0 ? "arrow.up" : priceChange < 0 ? "arrow.down" : "minus")
                .font(.caption2)
                .foregroundColor(priceChange > 0 ? Color("Red", bundle: .sharedUI) : priceChange < 0 ? Color("Green", bundle: .sharedUI) : Color("TextSecondary", bundle: .sharedUI))
            
            Text("$\(String(format: "%.2f", abs(priceChange)))")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(priceChange > 0 ? Color("Red", bundle: .sharedUI) : priceChange < 0 ? Color("Green", bundle: .sharedUI) : Color("TextSecondary", bundle: .sharedUI))
            
            if abs(percentageChange) > 0.01 {
                Text("(\(priceChange > 0 ? "+" : "")\(String(format: "%.1f", percentageChange))%)")
                    .font(.caption2)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
        }
    }
}

// MARK: - Price Trend Chart
fileprivate struct PriceTrendChartView: View {
    let versions: [NDISItemEntity] // Change to NDISItem
    let selectedRegion: String
    let currentItemId: UUID
    
    // Data model for chart points
    private struct PriceDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let price: Double
        let version: NDISItemEntity // Change to NDISItem
        let isCurrent: Bool
    }
    
    private var chartData: [PriceDataPoint] {
        return versions.compactMap { version in
            guard let startDate = version.effectiveStartDate else { return nil }
            
            let price: Double?
            if selectedRegion.isEmpty {
                price = PriceExtractor.getRepresentativePrice(from: version)
            } else {
                price = version.regionalPrices.first(where: { $0.regionIdentifier == selectedRegion })?.amount
            }
            
            guard let priceValue = price else { return nil }
            
            return PriceDataPoint(
                date: startDate,
                price: priceValue,
                version: version,
                isCurrent: version.id == currentItemId
            )
        }.sorted { $0.date < $1.date } // Sort chronologically for line chart
    }
    
    private var priceRange: (min: Double, max: Double) {
        guard !chartData.isEmpty else { return (0, 100) }
        let prices = chartData.map { $0.price }
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 100
        
        // Add some padding to the range
        let padding = (maxPrice - minPrice) * 0.1
        return (max(0, minPrice - padding), maxPrice + padding)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Price History")
                    .font(.headline)
                
                Spacer()
                
                if !selectedRegion.isEmpty {
                    Text(selectedRegion)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color("Primary", bundle: .sharedUI))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color("Primary", bundle: .sharedUI).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            if !chartData.isEmpty {
                Chart(chartData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Price", dataPoint.price)
                    )
                    .foregroundStyle(Color("Primary", bundle: .sharedUI))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Price", dataPoint.price)
                    )
                    .foregroundStyle(dataPoint.isCurrent ? Color("Active", bundle: .sharedUI) : Color("Primary", bundle: .sharedUI))
                    .symbolSize(dataPoint.isCurrent ? 60 : 40)
                    
                    // Add annotation for current version
                    if dataPoint.isCurrent {
                        RuleMark(x: .value("Date", dataPoint.date))
                            .foregroundStyle(Color.green.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: priceRange.min...priceRange.max)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(DateFormatter.chartFormatter.string(from: date))
                                    .font(.caption2)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let price = value.as(Double.self) {
                                Text("$\(String(format: "%.0f", price))")
                                    .font(.caption2)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            }
                        }
                    }
                }
                .chartBackground { chartProxy in
                    Color.clear
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                
                // Chart legend and summary
                HStack {
                    if let firstPoint = chartData.first, let lastPoint = chartData.last {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Price Change")
                                .font(.caption2)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            
                            let priceChange = lastPoint.price - firstPoint.price
                            let changePercent = firstPoint.price > 0 ? (priceChange / firstPoint.price) * 100 : 0
                            
                            HStack(spacing: 4) {
                                Image(systemName: priceChange >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                    .foregroundColor(priceChange >= 0 ? Color("Active", bundle: .sharedUI) : Color("Cancelled", bundle: .sharedUI))
                                
                                Text("$\(String(format: "%.2f", abs(priceChange))) (\(String(format: "%.1f", abs(changePercent)))%)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(priceChange >= 0 ? Color("Active", bundle: .sharedUI) : Color("Cancelled", bundle: .sharedUI))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Versions")
                            .font(.caption2)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        
                        Text("\(chartData.count) data points")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(.top, 8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    
                    Text("No pricing data available")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    
                    if !selectedRegion.isEmpty {
                        Text("No prices found for \(selectedRegion) region")
                            .font(.caption2)
                            .foregroundColor(Color("Inactive", bundle: .sharedUI))
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
            }
        }
        .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: StyleGuide.shadowColor, radius: 8, x: 0, y: 2)
    }
}

// Extension for date formatting in charts
extension DateFormatter {
    static let chartFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

fileprivate struct VersionTimelineView: View {
    let versions: [NDISItemEntity] // Change to NDISItem
    let currentItemId: UUID
    @Binding var selectedVersionId: UUID?
    let selectedRegion: String
    let onVersionSelect: (NDISItemEntity) -> Void // Change to NDISItem
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(versions.enumerated()), id: \.element.id) { index, version in
                HStack(spacing: 12) {
                    // Timeline connector
                    VStack(spacing: 0) {
                        if index > 0 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 20)
                        }
                        
                        // Status indicator
                        Circle()
                            .fill(version.isCurrent ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        
                        if index < versions.count - 1 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 20)
                        }
                    }
                    
                    // Version content
                    InteractiveVersionCard(
                        version: version,
                        isCurrentItem: version.id == currentItemId,
                        isSelected: selectedVersionId == version.id,
                        previousVersion: index < versions.count - 1 ? versions[index + 1] : nil,
                        selectedRegion: selectedRegion,
                        onTap: {
                            selectedVersionId = version.id
                            onVersionSelect(version)
                        }
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .fluidModalTransition()
    }
}

fileprivate struct InteractiveVersionCard: View {
    let version: NDISItemEntity
    let isCurrentItem: Bool
    let isSelected: Bool
    let previousVersion: NDISItemEntity?
    let selectedRegion: String
    let onTap: () -> Void
    
    private func getCurrentPrice(_ item: NDISItemEntity) -> Double? {
        if selectedRegion.isEmpty {
            return PriceExtractor.getRepresentativePrice(from: item)
        }
        return item.regionalPrices.first(where: { $0.regionIdentifier == selectedRegion })?.amount
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(version.effectiveDateRange)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        if !version.versionIdentifier.isEmpty {
                            Text("Version: \(version.versionIdentifier)")
                                .font(.caption2)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            if version.isCurrent {
                                Text("CURRENT")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("Active", bundle: .sharedUI))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color("Active", bundle: .sharedUI).opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            
                            if isCurrentItem {
                                Text("VIEWING")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("Draft", bundle: .sharedUI))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color("Draft", bundle: .sharedUI).opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            if let currentPrice = getCurrentPrice(version) {
                                Text("$\(String(format: "%.2f", currentPrice))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                
                                if !selectedRegion.isEmpty {
                                    Text("(\(selectedRegion))")
                                        .font(.caption2)
                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                }
                            } else if version.quoteRequired == true {
                                Text("Quote Req.")
                                    .font(.caption2)
                                    .foregroundColor(Color("Inactive", bundle: .sharedUI))
                            }
                        }
                    }
                }
                
                // Show changes from previous version
                if let previous = previousVersion {
                    VersionChangesIndicator(current: version, previous: previous, selectedRegion: selectedRegion)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        getStrokeColor(),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
    
    // Glass replaces color backgrounds; selection is indicated by overlay stroke
    
    private func getStrokeColor() -> Color {
        if isSelected {
            return Color("Primary", bundle: .sharedUI)
        } else if isCurrentItem {
            return Color("Draft", bundle: .sharedUI).opacity(0.3)
        } else if version.isCurrent {
            return Color("Active", bundle: .sharedUI).opacity(0.3)
        } else {
            return Color("Archived", bundle: .sharedUI).opacity(0.2)
        }
    }
}

fileprivate struct VersionChangesIndicator: View {
    let current: NDISItemEntity // Change to NDISItem
    let previous: NDISItemEntity // Change to NDISItem
    let selectedRegion: String
    
    private func getCurrentPrice(_ item: NDISItemEntity) -> Double? { // Change to NDISItem
        if selectedRegion.isEmpty {
            return PriceExtractor.getRepresentativePrice(from: item)
        }
        return item.regionalPrices.first(where: { $0.regionIdentifier == selectedRegion })?.amount
    }
    
    var body: some View {
        let changes = getChanges()
        
        if !changes.isEmpty {
            HStack {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(Color("Inactive", bundle: .sharedUI))
                
                Text(changes.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(Color("Inactive", bundle: .sharedUI))
                    .lineLimit(1)
            }
        }
    }
    
    private func getChanges() -> [String] {
        var changes: [String] = []
        
        // Check price changes
        let currentPrice = getCurrentPrice(current)
        let previousPrice = getCurrentPrice(previous)
        
        if let curr = currentPrice, let prev = previousPrice, curr != prev {
            let change = curr - prev
            changes.append(change > 0 ? "Price ↑" : "Price ↓")
        }
        
        // Check other changes
        if current.category != previous.category {
            changes.append("Category")
        }
        
        if current.registrationGroup != previous.registrationGroup {
            changes.append("Group")
        }
        
        if current.quoteRequired != previous.quoteRequired {
            changes.append("Quote Req.")
        }
        
        return changes
    }
}

fileprivate struct VersionComparisonView: View {
    let currentVersion: NDISItemEntity // Change to NDISItem
    let versions: [NDISItemEntity] // Change to NDISItem
    @Binding var selectedComparisonId: NDISItemEntity? // Change to NDISItem
    let selectedRegion: String
    @State private var selectedVersion: NDISItemEntity? // Change to NDISItem
    
    var body: some View {
        VStack(spacing: 12) {
            // Version selector
            HStack {
                Text("Compare with:")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                
                Picker("Compare Version", selection: $selectedVersion) {
                    Text("Select version...").tag(nil as NDISItemEntity?)
                    ForEach(versions.filter { $0.id != currentVersion.id }, id: \.id) { version in
                        Text(version.effectiveDateRange).tag(version as NDISItemEntity?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            
            if let compareVersion = selectedVersion {
                ComparisonTableView(current: currentVersion, comparison: compareVersion, selectedRegion: selectedRegion)
            } else {
                Text("Select a version to compare with the current item")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .padding(.vertical, 20)
            }
        }
    }
}

fileprivate struct ComparisonTableView: View {
    let current: NDISItemEntity // Change to NDISItem
    let comparison: NDISItemEntity // Change to NDISItem
    let selectedRegion: String
    
    private func getCurrentPrice(_ item: NDISItemEntity) -> String { // Change to NDISItem
        if selectedRegion.isEmpty {
            return PriceExtractor.getFormattedPrice(from: item)
        }
        
        if let price = item.regionalPrices.first(where: { $0.regionIdentifier == selectedRegion })?.amount {
            return "$\(String(format: "%.2f", price))"
        }
        return "N/A"
    }
    
    private func getPriceWithRegion(_ item: NDISItemEntity) -> String {
        if selectedRegion.isEmpty {
            if let price = PriceExtractor.getRepresentativePrice(from: item),
               let region = PriceExtractor.getRepresentativePriceRegion(from: item) {
                return "$\(String(format: "%.2f", price)) (\(region))"
            }
            return PriceExtractor.getFormattedPrice(from: item)
        }
        
        if let price = item.regionalPrices.first(where: { $0.regionIdentifier == selectedRegion })?.amount {
            return "$\(String(format: "%.2f", price)) (\(selectedRegion))"
        }
        return "N/A (\(selectedRegion))"
    }
    
    private func getAvailableRegions(_ item: NDISItemEntity) -> String {
        let prices = item.regionalPrices
        guard !prices.isEmpty else {
            return "None"
        }
        
        let regions = prices.compactMap { $0.regionIdentifier }.sorted()
        return regions.isEmpty ? "None" : regions.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Property")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Current")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text(comparison.effectiveDateRange)
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect())
            
            // Comparison rows
            ComparisonRow(
                property: "Effective Period",
                currentValue: current.effectiveDateRange,
                comparisonValue: comparison.effectiveDateRange,
                hasChanged: current.effectiveDateRange != comparison.effectiveDateRange
            )
            
                         ComparisonRow(
                 property: "Price",
                 currentValue: getPriceWithRegion(current),
                 comparisonValue: getPriceWithRegion(comparison),
                 hasChanged: getCurrentPrice(current) != getCurrentPrice(comparison)
             )
            
            ComparisonRow(
                property: "Category",
                currentValue: current.category ?? "N/A",
                comparisonValue: comparison.category ?? "N/A",
                hasChanged: current.category != comparison.category
            )
            
            ComparisonRow(
                property: "Registration Group",
                currentValue: current.registrationGroup ?? "N/A",
                comparisonValue: comparison.registrationGroup ?? "N/A",
                hasChanged: current.registrationGroup != comparison.registrationGroup
            )
            
                                     ComparisonRow(
                property: "Quote Required",
                currentValue: current.quoteRequired == true ? "Yes" : "No",
                comparisonValue: comparison.quoteRequired == true ? "Yes" : "No",
                hasChanged: current.quoteRequired != comparison.quoteRequired
            )
            
            // New attribute comparisons
            ComparisonRow(
                property: "Type",
                currentValue: current.type ?? "N/A",
                comparisonValue: comparison.type ?? "N/A",
                hasChanged: current.type != comparison.type
            )
            
            ComparisonRow(
                property: "Category Number",
                currentValue: current.categoryNumber ?? "N/A",
                comparisonValue: comparison.categoryNumber ?? "N/A",
                hasChanged: current.categoryNumber != comparison.categoryNumber
            )
            
            ComparisonRow(
                property: "PACE Category",
                currentValue: current.categoryNamePACE ?? "N/A",
                comparisonValue: comparison.categoryNamePACE ?? "N/A",
                hasChanged: current.categoryNamePACE != comparison.categoryNamePACE
            )
            
            ComparisonRow(
                property: "Registration Group #",
                currentValue: current.registrationGroupNumber ?? "N/A",
                comparisonValue: comparison.registrationGroupNumber ?? "N/A",
                hasChanged: current.registrationGroupNumber != comparison.registrationGroupNumber
            )
            
            // Boolean field comparisons
            ComparisonRow(
                property: "Non-Face-to-Face",
                currentValue: current.nonFaceToFaceProvision == true ? "Yes" : "No",
                comparisonValue: comparison.nonFaceToFaceProvision == true ? "Yes" : "No",
                hasChanged: current.nonFaceToFaceProvision != comparison.nonFaceToFaceProvision
            )
            
            ComparisonRow(
                property: "Provider Travel",
                currentValue: current.providerTravel == true ? "Yes" : "No",
                comparisonValue: comparison.providerTravel == true ? "Yes" : "No",
                hasChanged: current.providerTravel != comparison.providerTravel
            )
            
            ComparisonRow(
                property: "Short Notice Cancellations",
                currentValue: current.shortNoticeCancellations == true ? "Yes" : "No",
                comparisonValue: comparison.shortNoticeCancellations == true ? "Yes" : "No",
                hasChanged: current.shortNoticeCancellations != comparison.shortNoticeCancellations
            )
            
            ComparisonRow(
                property: "NDIA Reports",
                currentValue: current.ndiaRequestedReports == true ? "Yes" : "No",
                comparisonValue: comparison.ndiaRequestedReports == true ? "Yes" : "No",
                hasChanged: current.ndiaRequestedReports != comparison.ndiaRequestedReports
            )
            
            ComparisonRow(
                property: "Irregular SIL",
                currentValue: current.irregularSILSupports == true ? "Yes" : "No",
                comparisonValue: comparison.irregularSILSupports == true ? "Yes" : "No",
                hasChanged: current.irregularSILSupports != comparison.irregularSILSupports
            )
            
            // Debug: Show available pricing regions
            ComparisonRow(
                property: "Available Regions",
                currentValue: getAvailableRegions(current),
                comparisonValue: getAvailableRegions(comparison),
                hasChanged: getAvailableRegions(current) != getAvailableRegions(comparison)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

fileprivate struct ComparisonRow: View {
    let property: String
    let currentValue: String
    let comparisonValue: String
    let hasChanged: Bool
    
    var body: some View {
        HStack {
            Text(property)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(currentValue)
                .font(.caption)
                .fontWeight(hasChanged ? .medium : .regular)
                .foregroundColor(hasChanged ? Color("Text", bundle: .sharedUI) : Color("TextSecondary", bundle: .sharedUI))
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text(comparisonValue)
                .font(.caption)
                .fontWeight(hasChanged ? .medium : .regular)
                .foregroundColor(hasChanged ? Color("Text", bundle: .sharedUI) : Color("TextSecondary", bundle: .sharedUI))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(hasChanged ? Color.orange.opacity(0.1) : Color("Background", bundle: .sharedUI).opacity(0.1))
    }
}

// MARK: - NDISItemEntity Extension for computed properties
extension NDISItemEntity {
    var effectiveDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let startDate = effectiveStartDate ?? Date.distantPast
        let endDate = effectiveEndDate
        
        if let endDate = endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            return "\(formatter.string(from: startDate)) - Present"
        }
    }
}
