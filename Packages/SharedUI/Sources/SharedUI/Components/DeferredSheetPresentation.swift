import Core
import SwiftUI

/// Shared timing for deferring heavy sheet content until presentation animation settles.
public enum DeferredSheetPresentation {
    public static let revealDelay: Duration = .milliseconds(150)
    public static let revealAnimation = Animation.easeOut(duration: 0.15)

    /// Waits for ``revealDelay``. Returns `false` if cancelled.
    @MainActor
    public static func waitForReveal() async -> Bool {
        await Task.waitUnlessCancelled(for: revealDelay)
    }

    @MainActor
    public static func reveal(_ update: () -> Void) {
        withAnimation(revealAnimation, update)
    }
}

/// Soft background gradient used by sheet chrome (deferred loaders and session forms).
public struct AppSheetBackdrop: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [
                StyleGuide.Colors.background,
                StyleGuide.Colors.background.opacity(0.95),
                StyleGuide.Colors.background.opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Gradient + spinner chrome shown while deferred sheet content loads.
public struct DeferredSheetPlaceholder: View {
    public let minWidth: CGFloat
    public let minHeight: CGFloat

    public init(minWidth: CGFloat, minHeight: CGFloat) {
        self.minWidth = minWidth
        self.minHeight = minHeight
    }

    public var body: some View {
        ZStack {
            AppSheetBackdrop()
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(.circular)
        }
        .frame(minWidth: minWidth, minHeight: minHeight)
    }
}

/// Defers building `content` until after sheet presentation animation (~150ms).
public struct DeferredSheetContent<Content: View>: View {
    private let minWidth: CGFloat
    private let minHeight: CGFloat
    private let content: () -> Content
    @State private var isReady = false

    public init(
        minWidth: CGFloat,
        minHeight: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.content = content
    }

    public var body: some View {
        Group {
            if isReady {
                content()
            } else {
                DeferredSheetPlaceholder(minWidth: minWidth, minHeight: minHeight)
                    .task {
                        guard await DeferredSheetPresentation.waitForReveal() else { return }
                        DeferredSheetPresentation.reveal { isReady = true }
                    }
            }
        }
    }
}
