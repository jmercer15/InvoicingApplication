import SwiftUI
import Charts
import SwiftData // Import SwiftData
import Data
import Core
import SharedUI

// MARK: - PreferenceKey for Label Width

fileprivate struct LabelWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Size Measurement Preference Key

fileprivate struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Intrinsic Width Measurement

fileprivate struct IntrinsicWidthMeasurer {
    /// Calculates maximum width from items
    static func calculateMaxWidth<T>(for items: [T], measure: (T) -> CGFloat) -> CGFloat {
        items.isEmpty ? 0 : items.map(measure).max() ?? 0
    }
    
    /// Calculates optimal columns for grid layout
    static func calculateOptimalColumns(
        availableWidth: CGFloat,
        itemCount: Int,
        maxItemWidth: CGFloat,
        spacing: CGFloat
    ) -> Int {
        guard availableWidth > 0, itemCount > 0, maxItemWidth > 0 else { return 1 }
        return max(1, min(Int(availableWidth / (maxItemWidth + spacing)), itemCount))
    }
}

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
    @Environment(\.modelContext) private var modelContext
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
            LazyVStack(spacing: 20) {
                ModernHeaderView(item: item, selectedRegion: selectedRegion, selectedPrice: selectedPrice)

                SingleColumnLayout(
                    item: item,
                    availableRegions: availableRegions,
                    selectedRegion: $selectedRegion,
                    selectedPrice: selectedPrice
                )
            }
            .padding()
        }
        .background(.clear)
        .foregroundColor(Color("Text", bundle: .sharedUI))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                if selectedRegion.isEmpty && !availableRegions.isEmpty {
                    selectedRegion = availableRegions.first!
                }
            }
        }
    }
}

// MARK: - Card Position Preference Key
fileprivate struct CardPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Layout Types

fileprivate enum CardLayout {
    case singleColumn
    case twoColumn
    case threeColumn
}

// MARK: - Dynamic Card Layout System

fileprivate struct SingleColumnLayout: View {
    let item: NDISItemEntity
    let availableRegions: [String]
    @Binding var selectedRegion: String
    let selectedPrice: Double?

    var body: some View {
        VStack(spacing: 24) {
            ModernCombinedInfoCard(item: item)

            ModernCombinedPricingCard(
                availableRegions: availableRegions,
                selectedRegion: $selectedRegion,
                selectedPrice: selectedPrice,
                allPrices: item.regionalPrices.sorted { ($0.regionIdentifier ?? "") < ($1.regionIdentifier ?? "") },
                unit: item.unit,
                item: item
            )

            ModernProvisionCard(item: item)

            if let features = item.features, !features.isEmpty {
                let featureList = features
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                if !featureList.isEmpty {
                    ModernFeaturesCard(features: featureList)
                }
            }
        }
    }
}

// MARK: - Height Change Modifier
fileprivate struct HeightChangeModifier: ViewModifier {
    let onHeightChange: (CGFloat) -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            onHeightChange(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            onHeightChange(newHeight)
                        }
                }
            )
    }
}

extension View {
    func onHeightChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        self.modifier(HeightChangeModifier(onHeightChange: action))
    }
}

// MARK: - Modern Header View
fileprivate struct ModernHeaderView: View {
    let item: NDISItemEntity
    let selectedRegion: String
    let selectedPrice: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.itemNumber.isEmpty {                
                Text(item.itemNumber)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            Text(item.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Divider()
        }
        .padding(.vertical)
    }
}

// MARK: - Modern Card Components
fileprivate struct ModernCombinedPricingCard: View {
    let availableRegions: [String]
    @Binding var selectedRegion: String
    let selectedPrice: Double?
    let allPrices: [RegionalPriceEntity]
    let unit: String?
    let item: NDISItemEntity
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var availableWidth: CGFloat = 400
    @Namespace private var priceChipNamespace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("Primary", bundle: .sharedUI))
                
                Text("Regional Pricing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Spacer()
                
                Text("\(allPrices.count) regions")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            // Price cards grid with intrinsic width measurement
            if !allPrices.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: optimalColumns),
                    spacing: 6
                ) {
                    ForEach(sortedPricesByValue, id: \.region) { item in
                        ModernPriceChip(
                            region: item.region,
                            price: item.price,
                            isSelected: item.region == selectedRegion,
                            namespace: priceChipNamespace
                        )
                        .frame(minWidth: maxPriceChipWidth)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: selectedRegion)
                .animation(.easeInOut(duration: 0.5), value: optimalColumns)
                .animation(.easeInOut(duration: 0.5), value: availableWidth)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                availableWidth = geometry.size.width
                            }
                            .onChange(of: geometry.size.width) { _, newWidth in
                                availableWidth = newWidth
                            }
                    }
                )
        } else {
                NoPriceCard()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("White10", bundle: .sharedUI), lineWidth: 1)
                )
        )
        .shadow(color: Color("Shadow", bundle: .sharedUI).opacity(0.2), radius: 4, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pricing information for \(allPrices.count) regions")
        .accessibilityHint("Tap to view pricing details")
    }
    
    private var sortedPricesByValue: [(region: String, price: Double)] {
        return allPrices.compactMap { price in
            guard let region = price.regionIdentifier, price.amount > 0 else { return nil }
            return (region: region, price: price.amount)
        }.sorted { $0.price > $1.price }
    }
    
    private var maxPriceChipWidth: CGFloat {
        // Use a reasonable minimum width - actual sizing will be handled by GeometryReader
        return 120
    }
    
    private var optimalColumns: Int {
        IntrinsicWidthMeasurer.calculateOptimalColumns(
            availableWidth: availableWidth,
            itemCount: sortedPricesByValue.count,
            maxItemWidth: maxPriceChipWidth,
            spacing: 8
        )
    }
}

// MARK: - Modern Card Components
fileprivate struct ModernCombinedInfoCard: View {
    let item: NDISItemEntity
    @State private var maxLabelWidth: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let headerSpacing: CGFloat = 16
    private let sectionSpacing: CGFloat = 16
    private let rowSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            combinedInfoGrid
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color("White20", bundle: .sharedUI),
                                    Color("White05", bundle: .sharedUI)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color("Shadow", bundle: .sharedUI).opacity(0.25), radius: 6, x: 0, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.category)
        .onPreferenceChange(LabelWidthPreferenceKey.self) { width in
            maxLabelWidth = width
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Item information with classification, registration, and service details")
        .accessibilityHint("Contains detailed information about the NDIS support item")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("Primary", bundle: .sharedUI))
            
            Text("Item Information")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("Text", bundle: .sharedUI))
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
        //.padding(.bottom, headerSpacing)
    }



    
    private var combinedInfoGrid: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            // PACE information (moved to top)
            if let categoryNamePACE = item.categoryNamePACE, !categoryNamePACE.isEmpty {
                GridRow {
                    infoRow(label: "Category (PACE)", value: categoryNamePACE, dividerPadding: 1)
                        .gridCellColumns(horizontalSizeClass == .compact ? 1 : 2)
                }
            }
            
            if let categoryNumberPACE = item.categoryNumberPACE, !categoryNumberPACE.isEmpty {
                GridRow {
                    infoRow(label: "Category # (PACE)", value: categoryNumberPACE)
                        .gridCellColumns(horizontalSizeClass == .compact ? 1 : 2)
                }
            }
            
            // Classification information
            GridRow {
                infoRow(label: "Category", value: item.category ?? "N/A", dividerPadding: 1)
                    .gridCellColumns(horizontalSizeClass == .compact ? 1 : 2)
            }
            
            if let categoryNumber = item.categoryNumber, !categoryNumber.isEmpty {
                GridRow {
                    infoRow(label: "Category #", value: categoryNumber)
                        .gridCellColumns(horizontalSizeClass == .compact ? 1 : 2)
                }
            }
            
            // Registration information
            GridRow {
                infoRow(label: "Group", value: item.registrationGroup ?? "N/A", dividerPadding: 1)
                    .gridCellColumns(horizontalSizeClass == .compact ? 1 : 2)
            }
            
            if let registrationGroupNumber = item.registrationGroupNumber, !registrationGroupNumber.isEmpty {
                GridRow {
                    infoRow(label: "Group #", value: registrationGroupNumber)
                        .gridCellColumns(horizontalSizeClass == .compact ? 1 : 2)
                }
            }
            
            // Service details information
            if let type = item.type, !type.isEmpty {
                GridRow {
                    infoRow(label: "Type", value: type, dividerPadding: 1)
                        .gridCellColumns(horizontalSizeClass == .compact ? 1 : 2)
                }
            }
            
            GridRow {
                let quoteColor = item.quoteRequired == true ? Color("Orange", bundle: .sharedUI) : Color("Active", bundle: .sharedUI)
                infoRow(
                    label: "Quote Required",
                    value: item.quoteRequired == true ? "Yes" : "No",
                    valueColor: quoteColor
                )
                .gridCellColumns(horizontalSizeClass == .compact ? 1 : 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("White05", bundle: .sharedUI))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("White20", bundle: .sharedUI), lineWidth: 1)
        )
        .padding()

    }

    private func sectionHeader(title: String, icon: String, color: Color, topPadding: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color("Text", bundle: .sharedUI))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color("White05", bundle: .sharedUI))
                .overlay(
                    Rectangle()
                        .stroke(Color("White10", bundle: .sharedUI), lineWidth: 1)
                )
        )
        //.padding(.top, topPadding)
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, valueColor: Color? = nil, dividerPadding: CGFloat = 0) -> some View {
        let resolvedValueColor = valueColor ?? Color("Text", bundle: .sharedUI)

        HStack(spacing: 0) {
            // Label section
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: maxLabelWidth > 0 ? maxLabelWidth : nil, alignment: .leading)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: LabelWidthPreferenceKey.self, value: geometry.size.width)
                    }
                )

            Divider()
                .padding(.vertical, dividerPadding)

            // Value section with full background coverage
            ZStack {
                // Background that covers the entire value cell area
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Value text on top
                Text(value)
                    .font(.system(size: 12))
                    .minimumScaleFactor(0.8)
                    .foregroundColor(resolvedValueColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Rectangle()
                .fill(Color("White10", bundle: .sharedUI))
        )
        .overlay(
            Rectangle()
                .stroke(Color("White10", bundle: .sharedUI), lineWidth: 1)
        )
    }
}


fileprivate struct ModernProvisionCard: View {
    let item: NDISItemEntity
    
    var body: some View {
        InfoCard(
            title: "Service Delivery",
            icon: "gearshape.fill",
            iconColor: Color("Primary", bundle: .sharedUI)
        ) {
            ProvisionDeliveryView(item: item)
        }
    }
}

fileprivate struct ModernFeaturesCard: View {
    let features: [String]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var featureChipNamespace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("Green", bundle: .sharedUI))
                
                Text("Features")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Spacer()
                
                Text("\(features.count) features")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            // Content
            LazyVGrid(columns: adaptiveFeatureRows, spacing: 12) {
                ForEach(features, id: \.self) { feature in
                    ModernFeatureChip(feature: feature, namespace: featureChipNamespace)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.5), value: features.count)
            .animation(.easeInOut(duration: 0.5), value: adaptiveFeatureRows.count)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("White10", bundle: .sharedUI), lineWidth: 1)
                )
        )
        .shadow(color: Color("Shadow", bundle: .sharedUI).opacity(0.2), radius: 4, x: 0, y: 1)
    }
    
    private var adaptiveFeatureRows: [GridItem] {
        let featureCount = features.count
        
        switch horizontalSizeClass {
        case .compact:
            // On compact screens, use 1 column for better readability
            return [
                GridItem(.flexible(), spacing: 12)
            ]
        case .regular:
            // On regular screens, use 1-2 columns based on content
            return featureCount <= 4 ? [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ] : [
                GridItem(.flexible(), spacing: 12)
            ]
        default:
            return [
                GridItem(.flexible(), spacing: 12)
            ]
        }
    }
}

// MARK: - Supporting Components

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

fileprivate struct StatusBadge: View {
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isCurrent ? "checkmark.circle.fill" : "clock.fill")
                .font(.caption2)
            Text(isCurrent ? "Current" : "Historical")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(isCurrent ? Color("Active", bundle: .sharedUI) : Color("Inactive", bundle: .sharedUI))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrent ? Color("Active", bundle: .sharedUI).opacity(0.15) : Color("Inactive", bundle: .sharedUI).opacity(0.15))
        )
    }
}

fileprivate struct QuoteRequiredBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text.fill")
                .font(.caption2)
            Text("Quote Required")
                    .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(Color("Orange", bundle: .sharedUI))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color("Orange", bundle: .sharedUI).opacity(0.15))
        )
    }
}

fileprivate struct InfoChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

fileprivate struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("Text", bundle: .sharedUI))
            }
            
            content
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color("White10", bundle: .sharedUI), lineWidth: 1)
                )
        )
        .shadow(color: Color("Shadow", bundle: .sharedUI).opacity(0.2), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Additional Modern Components
fileprivate struct RegionSelectorMenu: View {
    let availableRegions: [String]
    @Binding var selectedRegion: String
    let allPrices: [RegionalPriceEntity]
    
    var body: some View {
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
                    .fill(Color("Primary", bundle: .sharedUI).opacity(0.1))
        .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("Primary", bundle: .sharedUI).opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

fileprivate struct PriceDisplayCard: View {
    let price: Double
    let unit: String?
    let region: String
    let allPrices: [RegionalPriceEntity]
    @Namespace private var priceChipNamespace
    
    var body: some View {
        VStack(spacing: 12) {
            // Main price display
            HStack(alignment: .firstTextBaseline) {
                Text("$\(String(format: "%.2f", price))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: price)
                    
                    if !(unit ?? "").isEmpty {
                        Text("per \(unit ?? "")")
                            .font(.subheadline)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .padding(.leading, 4)
                    }
                    
                    Spacer()
                }
                
                // Region info
                Text(region)
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color("Primary", bundle: .sharedUI).opacity(0.1))
                    )
                
                // All prices grid - always visible
                if allPrices.count > 1 {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(sortedPricesByValue, id: \.region) { item in
                            ModernPriceChip(
                                region: item.region,
                                price: item.price,
                                isSelected: item.region == region,
                                namespace: priceChipNamespace
                            )
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: allPrices.count)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("Primary", bundle: .sharedUI).opacity(0.05))
                            .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("Primary", bundle: .sharedUI).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        
        private var sortedPricesByValue: [(region: String, price: Double)] {
            return allPrices.compactMap { price in
                guard let region = price.regionIdentifier, price.amount > 0 else { return nil }
                return (region: region, price: price.amount)
            }.sorted { $0.price > $1.price }
        }
    }

fileprivate struct ModernPriceChip: View {
    let region: String
    let price: Double
    let isSelected: Bool
    let namespace: Namespace.ID
    
    var body: some View {
        HStack {
            Text(region)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? Color("Primary", bundle: .sharedUI) : Color("Text", bundle: .sharedUI))
                .lineLimit(1)
            
            Spacer()
            
            Text("$\(String(format: "%.2f", price))")
                .font(.caption2)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color("Primary", bundle: .sharedUI) : Color("White15", bundle: .sharedUI), lineWidth: 1)
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .matchedGeometryEffect(id: "priceChip-\(region)", in: namespace)
    }
}

fileprivate struct NoPriceCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(Color("Inactive", bundle: .sharedUI))
            
            Text("No Pricing Data Available")
                .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                
            Text("This item may require a quote or have pricing determined by individual service providers.")
                .font(.caption)
                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("Inactive", bundle: .sharedUI).opacity(0.1))
            .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("Inactive", bundle: .sharedUI).opacity(0.3), lineWidth: 1)
        )
        )
    }
}

fileprivate struct ProvisionDeliveryView: View {
    let item: NDISItemEntity
    @State private var availableWidth: CGFloat = 400
    @Namespace private var serviceDeliveryNamespace
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: optimalColumns),
            spacing: 6
        ) {
            ForEach(serviceDeliveryItems, id: \.title) { serviceItem in
                ProvisionCard(
                    title: serviceItem.title,
                    isAvailable: serviceItem.isAvailable,
                    namespace: serviceDeliveryNamespace
                )
                .frame(minWidth: maxServiceDeliveryCardWidth)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: optimalColumns)
        .animation(.easeInOut(duration: 0.5), value: availableWidth)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        availableWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        availableWidth = newWidth
                    }
            }
        )
    }
    
    private var serviceDeliveryItems: [(title: String, description: String, isAvailable: Bool)] {
        [
            ("Non-Face-to-Face", "Remote delivery", item.nonFaceToFaceProvision == true),
            ("Provider Travel", "Travel included", item.providerTravel == true),
            ("Short Notice", "Flexible cancellation", item.shortNoticeCancellations == true),
            ("NDIA Reports", "Reporting required", item.ndiaRequestedReports == true),
            ("Irregular SIL", "Flexible arrangements", item.irregularSILSupports == true)
        ]
    }
    
    private var maxServiceDeliveryCardWidth: CGFloat {
        // Use a reasonable minimum width - actual sizing will be handled by GeometryReader
        return 200
    }
    
    private var optimalColumns: Int {
        IntrinsicWidthMeasurer.calculateOptimalColumns(
            availableWidth: availableWidth,
            itemCount: serviceDeliveryItems.count,
            maxItemWidth: maxServiceDeliveryCardWidth,
            spacing: 6
        )
    }
}

fileprivate struct ProvisionCard: View {
    let title: String
    let isAvailable: Bool
    let namespace: Namespace.ID
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(isAvailable ? Color("Active", bundle: .sharedUI) : Color("Cancelled", bundle: .sharedUI))
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color("Text", bundle: .sharedUI))
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isAvailable ? Color("Active", bundle: .sharedUI).opacity(0.1) : Color("Cancelled", bundle: .sharedUI).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isAvailable ? Color("Active", bundle: .sharedUI).opacity(0.3) : Color("Cancelled", bundle: .sharedUI).opacity(0.3), lineWidth: 1)
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .matchedGeometryEffect(id: "serviceDelivery-\(title)", in: namespace)
    }
}

fileprivate struct ModernFeatureChip: View {
    let feature: String
    let namespace: Namespace.ID
    
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
            return "star.fill"
    }
    
    var body: some View {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundColor(Color("Green", bundle: .sharedUI))
                Text(feature)
                    .font(.caption)
                        .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
            }
            //.padding(.horizontal, 10)
            //.padding(.vertical, 6)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("Green", bundle: .sharedUI).opacity(0.15),
                                Color("Green", bundle: .sharedUI).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("Green", bundle: .sharedUI).opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color("Green", bundle: .sharedUI).opacity(0.2), radius: 2, x: 0, y: 1)
            .matchedGeometryEffect(id: "featureChip-\(feature)", in: namespace)
        }
    }
    
    // MARK: - Modern Loading Components
    fileprivate struct ShimmerEffect: View {
        @State private var isAnimating = false
    
    var body: some View {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("White10", bundle: .sharedUI),
                            Color("White20", bundle: .sharedUI),
                            Color("White10", bundle: .sharedUI)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: isAnimating ? 200 : -200)
                .animation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
        }
    }
    
    fileprivate struct ModernLoadingCard: View {
    var body: some View {
            VStack(alignment: .leading, spacing: 12) {
        HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("White10", bundle: .sharedUI))
                        .frame(width: 20, height: 20)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("White10", bundle: .sharedUI))
                        .frame(width: 100, height: 16)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("White10", bundle: .sharedUI))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("White10", bundle: .sharedUI))
                        .frame(height: 12)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("White10", bundle: .sharedUI), lineWidth: 1)
                    )
            )
        .overlay(
                ShimmerEffect()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
        }
    }
