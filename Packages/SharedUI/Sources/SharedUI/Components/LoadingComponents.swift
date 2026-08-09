import SwiftUI

/// A standardized loading indicator with optional text.
public struct LoadingView: View {
    let message: String?
    
    public init(_ message: String? = nil) {
        self.message = message
    }
    
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusMedium

    public var body: some View {
        VStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
            ProgressView()
                .scaleEffect(1.2)

            if let message = message {
                Text(message)
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
        }
        .padding(StyleGuide.Dimensions.paddingLarge)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(
            color: Color.black.opacity(StyleGuide.Opacity.light),
            radius: StyleGuide.Shadows.darkRadius + 2,
            x: 0,
            y: StyleGuide.Shadows.darkOffsetY + 1
        )
    }
}

/// A view modifier that overlays a loading indicator when `isLoading` is true.
public struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading) // Prevent interaction while loading
                .blur(radius: isLoading ? 2 : 0) // Optional: blur background slightly
                .animation(reduceMotion ? nil : .easeInOut, value: isLoading)
            
            if isLoading {
                LoadingView(message)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
    }
}

public extension View {
    /// Overlays a standard loading spinner when `isLoading` is true.
    /// - Parameters:
    ///   - isLoading: Binding or Boolean to control visibility.
    ///   - message: Optional text to display below the spinner.
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        self.modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}
