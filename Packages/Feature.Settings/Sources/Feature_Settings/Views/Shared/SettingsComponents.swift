import SwiftUI
import SharedUI

// MARK: - Reusable Components

struct SectionHeader: View {
    let icon: String
    let title: String
    let description: String
    let trailingButton: (() -> AnyView)?

    init(icon: String, title: String, description: String, trailingButton: (() -> AnyView)? = nil) {
        self.icon = icon
        self.title = title
        self.description = description
        self.trailingButton = trailingButton
    }

    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .font(StyleGuide.Typography.sectionTitle)
            Text(title)
                .formSectionTitleStyle()
            InfoIcon(tooltip: description)
            Spacer()
            if let trailingButton = trailingButton {
                trailingButton()
            }
        }
        .padding(.bottom, StyleGuide.Dimensions.paddingXSmall)
    }
}

struct InfoIcon: View {
    let tooltip: String

    var body: some View {
        Image(systemName: "info.circle")
            .foregroundStyle(ColorSystem.Status.info)
            .font(StyleGuide.Typography.caption)
            .help(tooltip)
    }
}

struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    let description: String
    let content: Content
    let trailingButton: (() -> AnyView)?

    init(icon: String, title: String, description: String, trailingButton: (() -> AnyView)? = nil, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.description = description
        self.trailingButton = trailingButton
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
            SectionHeader(icon: icon, title: title, description: description, trailingButton: trailingButton)
            VStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                content
            }
        }
        .standardSectionStyle()
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            Text(title)
                .font(StyleGuide.Typography.itemTitle)
                .foregroundStyle(StyleGuide.Colors.text)

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                content
            }
        }
        .standardCardStyle()
    }
}
