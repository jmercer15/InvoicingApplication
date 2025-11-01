import SwiftUI
import SharedUI

// MARK: - Styling Modifiers

extension View {
    func formDescriptionStyle() -> some View {
        self
            .font(.footnote)
            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            .padding(.leading, 20)
            .lineSpacing(1.5)
    }
    
    func formErrorStyle() -> some View {
        self
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundColor(.red)
            .padding(.leading, 20)
    }
    
    func formSectionTitleStyle() -> some View {
        self
            .font(.title3)
            .fontWeight(.bold)
            .padding(.bottom, 2)
    }
    
    func glassCardStyle() -> some View {
        self
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }
    
    func sectionStyle() -> some View {
        self
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }
}

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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.title2)
            Text(title)
                .formSectionTitleStyle()
            InfoIcon(tooltip: description)
            Spacer()
            if let trailingButton = trailingButton {
                trailingButton()
            }
        }
        .padding(.bottom, 4)
    }
}

struct InfoIcon: View {
    let tooltip: String
    
    var body: some View {
        Image(systemName: "info.circle")
            .foregroundColor(.blue)
            .font(.caption)
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
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: icon, title: title, description: description, trailingButton: trailingButton)
            VStack(spacing: 12) {
                content
            }
        }
        .sectionStyle()
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color("Text", bundle: .sharedUI))
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
        .glassCardStyle()
    }
}
