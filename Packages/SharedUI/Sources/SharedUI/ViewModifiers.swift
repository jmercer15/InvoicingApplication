import SwiftUI
import MapKit
import Data
import Core

// MARK: - Form Field Component
public struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    
    public init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            content()
        }
    }
}

// MARK: - Selection Column Style
extension View {
    func selectionColumnStyle() -> some View {
        self
            .frame(width: 40)
            .background(Color(.controlBackgroundColor))
    }
}



// MARK: - Status Badge
public struct StatusBadge: View {
    public let status: String
    public let color: Color
    
    public init(_ status: String, color: Color = .blue) {
        self.status = status
        self.color = color
    }
    
    public init(status: String, color: Color = .blue) {
        self.status = status
        self.color = color
    }
    
    // Duplicate initializer removed - redundant with synthesized memberwise initializer
    
    public var body: some View {
        Text(status)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
    }
}

// MARK: - Navigation Components
// EntityNavigationContextMenu and NavigationRowActions removed - unused structs



// NavigateToMapButton moved to NavigateToMapButton.swift

// MARK: - Address Data Type
public struct AddressData: Codable, Hashable {
    public var unitNumber: String = ""
    public var streetNumber: String = ""
    public var streetName: String = ""
    public var suburb: String = ""
    public var state: String = ""
    public var postcode: String = ""
    public var country: String = ""
    public var poBox: String = ""
    
    public init() {
        // Default initializer
    }
    
    public init(
        unitNumber: String = "",
        streetNumber: String = "",
        streetName: String = "",
        suburb: String = "",
        state: String = "",
        postcode: String = "",
        country: String = "",
        poBox: String = ""
    ) {
        self.unitNumber = unitNumber
        self.streetNumber = streetNumber
        self.streetName = streetName
        self.suburb = suburb
        self.state = state
        self.postcode = postcode
        self.country = country
        self.poBox = poBox
    }
    
    var street: String {
        [unitNumber, streetNumber, streetName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    // MARK: - Conversion Methods
    
    /// Convert from AddressEntity to AddressData
    public init(from addressEntity: AddressEntity) {
        self.init()
        self.unitNumber = addressEntity.unitNumber
        self.streetNumber = addressEntity.streetNumber
        self.streetName = addressEntity.streetName
        self.suburb = addressEntity.suburb
        self.state = addressEntity.state
        self.postcode = addressEntity.postcode
        self.country = addressEntity.country
        self.poBox = addressEntity.poBox
    }
    
    /// Convert to AddressEntity
    public func toAddressEntity() -> AddressEntity {
        let entity = AddressEntity()
        entity.unitNumber = self.unitNumber
        entity.streetNumber = self.streetNumber
        entity.streetName = self.streetName
        entity.suburb = self.suburb
        entity.state = self.state
        entity.postcode = self.postcode
        entity.country = self.country
        entity.poBox = self.poBox
        return entity
    }
    
    public var city: String {
        suburb
    }
    
    public var fullAddress: String {
        [street, suburb, state, postcode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}



// MARK: - Animation Extensions
extension Animation {
    static var easeInOut: Animation { .easeInOut(duration: StyleGuide.Animations.durationMedium) }
}





// MARK: - Custom View Modifiers (duplicates removed)

// MARK: - Border Extensions
// Custom border extension removed - unused implementation; only native SwiftUI modifier is used



// MARK: - Custom Modifiers

// Central glass background modifier used across components
// Central glass background modifier used across components
public struct GlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    public init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    private var backgroundGradientColors: [Color] {
        colorScheme == .light ? [
            Color("Background", bundle: .sharedUI).opacity(0.8),
            Color("Background", bundle: .sharedUI).opacity(0.6)
        ] : [
            Color("White15", bundle: .sharedUI),
            Color("White05", bundle: .sharedUI)
        ]
    }

    private var strokeGradientColors: [Color] {
        colorScheme == .light ? [
            Color("TextSecondary", bundle: .sharedUI).opacity(0.2),
            Color("TextSecondary", bundle: .sharedUI).opacity(0.1)
        ] : [
            Color("White30", bundle: .sharedUI),
            Color("White10", bundle: .sharedUI)
        ]
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LinearGradient(colors: backgroundGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(LinearGradient(colors: strokeGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .light ? Color("TextSecondary", bundle: .sharedUI).opacity(0.1) : Color("Black30", bundle: .sharedUI),
                radius: colorScheme == .light ? StyleGuide.Shadows.lightRadius : StyleGuide.Shadows.darkRadius,
                x: 0,
                y: colorScheme == .light ? StyleGuide.Shadows.lightOffsetY : StyleGuide.Shadows.darkOffsetY
            )
    }
}

public extension View {
    public func glassBackgroundStyle(cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusMedium) -> some View {
        self.modifier(GlassBackgroundModifier(cornerRadius: cornerRadius))
    }
}

struct GroupBoxGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.glassBackgroundStyle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
    }
}

public struct EnhancedGroupBoxStyle: GroupBoxStyle {
    @Environment(\.colorScheme) var colorScheme
    
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassBackgroundStyle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
            
            configuration.content
                .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                .padding(.vertical, 10)
        }
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == CustomGlassButtonStyle {
    static var customGlass: CustomGlassButtonStyle { CustomGlassButtonStyle() }
    static var customGlassProminent: CustomGlassProminentButtonStyle { CustomGlassProminentButtonStyle() }
}

struct CustomGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous)
        configuration.label
            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
            .background(
                shape
                    .fill(Color("White20", bundle: .sharedUI).opacity(configuration.isPressed ? 1.0 : 0.5))
                    .overlay(
                        shape
                            .stroke(Color("White30", bundle: .sharedUI), lineWidth: 1)
                    )
            )
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: configuration.isPressed)
    }
}

struct CustomGlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous)
        configuration.label
            .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            .background(
                shape
                    .fill(Color("Blue", bundle: .sharedUI).opacity(configuration.isPressed ? 0.8 : 0.6))
                    .overlay(
                        shape
                            .stroke(Color("Blue", bundle: .sharedUI).opacity(0.8), lineWidth: 1)
                    )
            )
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: configuration.isPressed)
    }
}

// MARK: - NativeAddressSearchField Component

public struct NativeAddressSearchField: View {
    @Binding var searchText: String
    @Binding var selectedAddress: AddressData?
    
    // Address field bindings
    @Binding var unitNumber: String
    @Binding var streetNumber: String
    @Binding var streetName: String
    @Binding var suburb: String
    @Binding var postcode: String
    @Binding var state: String
    @Binding var country: String
    @Binding var poBox: String
    
    // Search state managed by service
    @StateObject private var service = AddressSearchService()
    @State private var showResults = false
    @State private var isProgrammaticallyUpdatingSearchText = false
    
    public init(searchText: Binding<String>, selectedAddress: Binding<AddressData?>, unitNumber: Binding<String>, streetNumber: Binding<String>, streetName: Binding<String>, suburb: Binding<String>, postcode: Binding<String>, state: Binding<String>, country: Binding<String>, poBox: Binding<String>) {
        self._searchText = searchText
        self._selectedAddress = selectedAddress
        self._unitNumber = unitNumber
        self._streetNumber = streetNumber
        self._streetName = streetName
        self._suburb = suburb
        self._postcode = postcode
        self._state = state
        self._country = country
        self._poBox = poBox
        
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Search:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("White", bundle: .sharedUI))
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TextField("Search for an address", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("White", bundle: .sharedUI))
                            .accentColor(service.errorMessage != nil ? Color("Cancelled", bundle: .sharedUI) : Color("Draft", bundle: .sharedUI))
                            .onChange(of: searchText) { _, newValue in
                                // Only perform search if we're not programmatically updating the text
                                if !isProgrammaticallyUpdatingSearchText {
                                    performSearch(query: newValue)
                                }
                            }
                            .onAppear {
                                // If we have existing address data, show it in the search field
                                if searchText.isEmpty && hasExistingAddressData {
                                    searchText = formatExistingAddress()
                                }
                            }
                        
                        // Loading indicator
                        if service.isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(Color("White", bundle: .sharedUI))
                        }
                    }
                    
                    // Error message
                    if let error = service.errorMessage {
                        Text(error)
                            .foregroundColor(Color("Cancelled", bundle: .sharedUI))
                            .font(.caption)
                            .padding(.top, 4)
                    }
                    
                    // Search Results Dropdown
                    if showResults && !service.searchResults.isEmpty {
                        searchResultsView
                    }
                }
            }
        }
        .onChange(of: service.searchResults) { _, newValue in
            showResults = !newValue.isEmpty && !searchText.isEmpty
        }
    }
    
    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<service.searchResults.count, id: \.self) { index in
                    let result = service.searchResults[index]
                    Button(action: {
                        selectAddress(result)
                    }) {
                        HStack(spacing: 12) {
                            // Location icon
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                
                                Text(result.subtitle)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color("Black30", bundle: .sharedUI))
                    .contentShape(Rectangle())
                    
                    if result != service.searchResults.last {
                        Divider()
                            .background(Color("White10", bundle: .sharedUI))
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Color("White15", bundle: .sharedUI))
        .cornerRadius(8)
        .padding(.top, 4)
    }
    
    private func performSearch(query: String) {
        service.performSearch(query: query)
    }
    
    private func selectAddress(_ result: MKLocalSearchCompletion) {
        // Set flag to prevent search trigger
        isProgrammaticallyUpdatingSearchText = true
        
        // Update search text with selected result
        searchText = result.title + ", " + result.subtitle
        showResults = false
        
        // Reset flag after a short delay to allow the text field to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isProgrammaticallyUpdatingSearchText = false
        }
        
        // Perform geocoding to get detailed address components
        Task {
            if let item = await service.fetchMapItem(for: result) {
                fillAddressFields(from: item)
            }
        }
    }
    
    private func fillAddressFields(from mapItem: MKMapItem) {
        let parsed = MapKitAddressResolver.parseAddress(from: mapItem)
        unitNumber = parsed.unitNumber
        streetNumber = parsed.streetNumber
        streetName = parsed.streetName
        suburb = parsed.suburb.isEmpty ? parsed.city : parsed.suburb
        postcode = parsed.postcode
        state = parsed.state
        country = parsed.country
        poBox = parsed.poBox

        selectedAddress = AddressData(
            unitNumber: unitNumber,
            streetNumber: streetNumber,
            streetName: streetName,
            suburb: suburb,
            state: state,
            postcode: postcode,
            country: country,
            poBox: poBox
        )
        
        // Clear the search text after populating fields (without triggering search)
        isProgrammaticallyUpdatingSearchText = true
        searchText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isProgrammaticallyUpdatingSearchText = false
        }
    }
    
    // Parsing moved into AddressSearchService
    
    private var hasExistingAddressData: Bool {
        !unitNumber.isEmpty || !streetNumber.isEmpty || !streetName.isEmpty || 
        !suburb.isEmpty || !state.isEmpty || !postcode.isEmpty || 
        !country.isEmpty || !poBox.isEmpty
    }
    
    private func formatExistingAddress() -> String {
        var parts: [String] = []
        
        if !poBox.isEmpty {
            parts.append("PO Box \(poBox)")
        } else {
            // Handle street address components
            var streetComponents: [String] = []
            
            if !unitNumber.isEmpty {
                streetComponents.append("Unit \(unitNumber)")
            }
            
            // Combine street number and name without comma
            var streetAddress = ""
            if !streetNumber.isEmpty {
                streetAddress += streetNumber
            }
            if !streetName.isEmpty {
                if !streetAddress.isEmpty {
                    streetAddress += " "
                }
                streetAddress += streetName
            }
            
            if !streetAddress.isEmpty {
                streetComponents.append(streetAddress)
            }
            
            if !streetComponents.isEmpty {
                parts.append(streetComponents.joined(separator: ", "))
            }
        }
        
        // Add locality components
        if !suburb.isEmpty { parts.append(suburb) }
        if !state.isEmpty { parts.append(state) }
        if !postcode.isEmpty { parts.append(postcode) }
        if !country.isEmpty { parts.append(country) }
        
        return parts.joined(separator: ", ")
    }
}

// SearchCompleterDelegate removed - logic moved into AddressSearchService









// MARK: - Fluid Transition Modifiers
public extension View {
    /// Fluid transition with smooth animations
    func fluidTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // fluidTransition(insertionEdge:removalEdge:) removed - unused overload
    
    /// Fluid transition for sheet presentations
    func fluidSheetTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
    
    /// Fluid transition for modal presentations
    func fluidModalTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        ))
    }
    
    /// Fluid transition for list items
    func fluidListTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
    
    /// Fluid transition for detail views
    func fluidDetailTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .opacity.animation(.easeInOut(duration: 0.2)),
            removal: .opacity.combined(with: .scale(scale: 0.9)).animation(.easeInOut(duration: 0.15))
        ))
    }
    
    // fluidAnimation() and fluidAnimation(response:dampingFraction:) removed - unused overloads
}
