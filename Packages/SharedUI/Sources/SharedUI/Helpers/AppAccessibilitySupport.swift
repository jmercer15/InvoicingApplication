import Accessibility
import SwiftUI

/// Shared accessibility behavior for transient workflow feedback.
public enum AppAccessibilityAnnouncement {
    @MainActor
    public static func post(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        AccessibilityNotification.Announcement(trimmed).post()
    }
}

private struct ReduceMotionTransactionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transaction { transaction in
            guard reduceMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}

public extension View {
    /// Removes non-essential transitions while preserving the resulting state change.
    func appRespectsReduceMotion() -> some View {
        modifier(ReduceMotionTransactionModifier())
    }
}
