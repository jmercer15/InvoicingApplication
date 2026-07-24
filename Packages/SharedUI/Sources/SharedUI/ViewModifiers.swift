import SwiftUI
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
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
            Text(label)
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
            content()
        }
    }
}

// MARK: - Status Badge
public struct StatusBadge: View {
    public let status: String
    public let color: Color
    public let icon: String?

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var paddingMedium: CGFloat = StyleGuide.Dimensions.paddingMedium
    @ScaledMetric(relativeTo: .body) private var paddingSmall: CGFloat = StyleGuide.Dimensions.paddingSmall
    @ScaledMetric(relativeTo: .body) private var cornerRadiusSmall: CGFloat = StyleGuide.Dimensions.cornerRadiusSmall

    public init(_ status: String, color: Color = ColorSystem.Primary.blue, icon: String? = nil) {
        self.status = status
        self.color = color
        self.icon = icon
    }
    
    public init(status: String, color: Color = ColorSystem.Primary.blue, icon: String? = nil) {
        self.status = status
        self.color = color
        self.icon = icon
    }
    
    public var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
            if let icon {
                Image(systemName: icon)
            }
            Text(status)
        }
        .font(StyleGuide.Typography.caption)
        .padding(.horizontal, paddingMedium)
        .padding(.vertical, paddingSmall)
        .background(color.opacity(colorScheme == .dark ? StyleGuide.Opacity.medium : StyleGuide.Opacity.light + 0.02))
        .foregroundStyle(colorScheme == .dark ? color.opacity(0.9) : color)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadiusSmall, style: .continuous))
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
    
    public var city: String {
        suburb
    }
    
    public var fullAddress: String {
        [street, suburb, state, postcode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Copies search / geocode components into editable properties (e.g. view models). Uses ``AddressData/city`` for the city field so it stays aligned with suburb for MapKit-style data.
    public func copyToStructuredAddressFields(
        unitNumber: inout String,
        streetNumber: inout String,
        streetName: inout String,
        suburb: inout String,
        city: inout String,
        state: inout String,
        postcode: inout String,
        country: inout String,
        poBox: inout String
    ) {
        unitNumber = self.unitNumber
        streetNumber = self.streetNumber
        streetName = self.streetName
        suburb = self.suburb
        city = self.city
        state = self.state
        postcode = self.postcode
        country = self.country
        poBox = self.poBox
    }
}









// MARK: - Custom View Modifiers (duplicates removed)

// MARK: - Border Extensions
// Custom border extension removed - unused implementation; only native SwiftUI modifier is used



// MARK: - Custom Modifiers

public struct EnhancedGroupBoxStyle: GroupBoxStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        EnhancedGroupBoxView(configuration: configuration)
    }
}

private struct EnhancedGroupBoxView: View {
    let configuration: GroupBoxStyleConfiguration

    @ScaledMetric(relativeTo: .body) private var paddingMedium: CGFloat = StyleGuide.Dimensions.paddingMedium
    @ScaledMetric(relativeTo: .body) private var cornerRadiusMedium: CGFloat = StyleGuide.Dimensions.cornerRadiusMedium

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            configuration.label
                .font(StyleGuide.Typography.label)
                .foregroundStyle(StyleGuide.Colors.text)
                .padding(.horizontal, paddingMedium)
                .padding(.top, paddingMedium)
            
            configuration.content
                .padding(.horizontal, paddingMedium)
                .padding(.bottom, paddingMedium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadiusMedium)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
        )
    }
}





// MARK: - Form Section Background
public extension View {
    /// Bordered section container for grouped form or summary content.
    func formSectionBackground() -> some View {
        padding(StyleGuide.Dimensions.paddingLarge)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .fill(StyleGuide.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                            .stroke(StyleGuide.Colors.border, lineWidth: 0.6)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
    }
}

// MARK: - Fluid Transition Modifiers
public extension View {
    /// Fluid transition with smooth animations
    func fluidTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

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
            insertion: .opacity.animation(.easeInOut(duration: StyleGuide.Animations.durationMedium)),
            removal: .opacity.combined(with: .scale(scale: 0.9)).animation(.easeInOut(duration: StyleGuide.Animations.durationShort))
        ))
    }
}
