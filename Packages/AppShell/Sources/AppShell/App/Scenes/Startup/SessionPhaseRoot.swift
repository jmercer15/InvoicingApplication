import SwiftUI
import SharedUI

struct SessionPhaseRoot<ReadyContent: View, LoadingContent: View>: View {
    let phase: AppSession.Phase
    let retry: () async -> Void
    @ViewBuilder let loading: () -> LoadingContent
    @ViewBuilder let ready: (AppRuntime) -> ReadyContent

    var body: some View {
        switch phase {
        case .ready(let runtime):
            ready(runtime)
        case .starting:
            loading()
        case .failed(let error):
            StartupFailureView(error: error, retry: retry)
        }
    }
}

struct WorkspaceStartupLoadingView: View {
    var body: some View {
        VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 40))
                .foregroundStyle(StyleGuide.Colors.primary)
            
            ProgressView("Loading Application...")
            
            Text("Initializing Data Layer...")
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Material.ultraThin)
    }
}

struct SettingsStartupLoadingView: View {
    var body: some View {
        VStack(spacing: FormSectionTokens.sectionStackSpacing) {
            ProgressView()
            Text("Initializing settings...")
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StartupFailureView: View {
    let error: AppStartupError
    let retry: () async -> Void

    var body: some View {
        VStack {
            VStack(spacing: FormSectionTokens.sectionStackSpacing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(ColorSystem.Status.warning)
                
                Text(error.localizedDescription)
                    .font(.headline)
                    .foregroundStyle(StyleGuide.Colors.text)
                    .multilineTextAlignment(.center)
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(StyleGuide.Typography.caption)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }
                
                Button(action: {
                    Task { await retry() }
                }) {
                    Text("Retry")
                }
                .buttonStyle(.borderedProminent)
            }
            .standardCardStyle()
            .frame(maxWidth: 400)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StyleGuide.Colors.background.opacity(0.5))
    }

    private var accessibilityText: String {
        var text = "Application Startup Failed: \(error.localizedDescription)"
        if let suggestion = error.recoverySuggestion {
            text += ". \(suggestion)"
        }
        return text
    }
}
