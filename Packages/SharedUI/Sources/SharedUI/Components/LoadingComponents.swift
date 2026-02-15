import SwiftUI

/// A standardized loading indicator with optional text.
public struct LoadingView: View {
    let message: String?
    
    public init(_ message: String? = nil) {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2) // Slightly larger for better visibility
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Color.secondary)
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

/// A view modifier that overlays a loading indicator when `isLoading` is true.
public struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    public func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading) // Prevent interaction while loading
                .blur(radius: isLoading ? 2 : 0) // Optional: blur background slightly
                .animation(.easeInOut, value: isLoading)
            
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
