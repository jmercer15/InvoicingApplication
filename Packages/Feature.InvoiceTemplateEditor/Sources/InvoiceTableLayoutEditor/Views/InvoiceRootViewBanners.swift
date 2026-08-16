import SwiftUI

// MARK: - Status Banners

/// Notification anchor that disambiguates concurrent external document refresh tasks.
struct InvoiceExternalDocumentRefreshTaskID: Equatable {
    let selectedID: UUID?
    let revision: Int
}

/// Bottom-of-viewport banner surfaced when the template editor detects invalid numeric inputs.
struct InvoiceTemplateInvalidValuesBanner: View {
    let reviewFormat: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Template has invalid Format values.")
                .font(.callout.weight(.medium))

            Button("Review Format", action: reviewFormat)
                .buttonStyle(.borderless)
                .help("Open Format inspector and review highlighted values")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(.orange.opacity(0.2))
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Template contains invalid Format values")
        .accessibilityHint("Open Format inspector to review highlighted values")
    }
}

/// Bottom-of-viewport banner surfaced when an auto-save of the template fails.
struct InvoiceTemplateSaveFailureBanner: View {
    let retry: () -> Void
    let openFormat: () -> Void
    @AccessibilityFocusState private var isRetryFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text("Template changes couldn't be saved.")
                .font(.callout.weight(.medium))

            Button("Retry", action: retry)
                .buttonStyle(.borderless)
                .accessibilityFocused($isRetryFocused)

            Button("Open Format", action: openFormat)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(.red.opacity(0.16))
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Template save failed")
        .onAppear {
            isRetryFocused = true
            AccessibilityNotification.Announcement("Save failed. Template changes couldn't be saved.").post()
        }
    }
}
