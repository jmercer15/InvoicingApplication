import SwiftUI
import AppKit
import Core
import SharedUI

// MARK: - Header & UI Helper Views

extension ComponentPropertyEditor {
    @ViewBuilder
    func header(for component: InvoiceComponent) -> some View {
        HStack(spacing: 10) {
            // Icon box
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.15),
                                Color.accentColor.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.9)
                Image(iconName(for: component), bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(Color.accentColor)
            }
            .frame(width: 28, height: 28)
            
            Text(tagTitle(for: component))
                .font(InspectorTypography.panelTitle)
                .foregroundColor(Color.primaryText)
            
            Spacer()
            
            componentCommandBar(for: component)
        }
    }
    
    private func iconName(for component: InvoiceComponent) -> String {
        if component.type.usesTableProperties { return "fluent-ic_fluent_table_20_regular" }
        if component.type.supportsTypography { return "fluent-ic_fluent_text_font_20_regular" }
        if component.type.isImageComponent { return "fluent-ic_fluent_image_20_regular" }
        if component.type.isShape { return "fluent-ic_fluent_shape_union_20_regular" }
        return "fluent-ic_fluent_grid_20_regular"
    }

    @ViewBuilder
    func componentCommandBar(for component: InvoiceComponent) -> some View {
        HStack(spacing: 4) {
            commandButton(
                icon: component.isLocked ? "fluent-ic_fluent_lock_closed_20_regular" : "fluent-ic_fluent_lock_open_20_regular",
                isActive: component.isLocked,
                help: component.isLocked ? "Unlock" : "Lock"
            ) {
                document.toggleLock(for: component.id)
            }

            commandButton(
                icon: component.isVisible ? "fluent-ic_fluent_eye_show_20_regular" : "fluent-ic_fluent_eye_hide_20_regular",
                isActive: !component.isVisible,
                help: component.isVisible ? "Hide" : "Show"
            ) {
                document.toggleVisibility(for: component.id)
            }

            commandButton(
                icon: "fluent-ic_fluent_copy_20_regular",
                isActive: false,
                help: "Duplicate"
            ) {
                editorViewModel.duplicateComponent(component)
            }

            commandButton(
                icon: "fluent-ic_fluent_delete_20_regular",
                isActive: false,
                isDestructive: true,
                help: "Delete"
            ) {
                editorViewModel.deleteComponent(component)
            }
        }
    }
    
    @ViewBuilder
    private func commandButton(
        icon: String,
        isActive: Bool,
        isDestructive: Bool = false,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                Image(icon, bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
                .frame(width: 14, height: 14)
                .foregroundColor(
                    isDestructive ? Color.red.opacity(0.8) :
                    isActive ? Color.accentColor : Color.secondaryText
                )
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(isActive ? 0.15 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .pointerStyle(.link)
        .help(help)
    }

    func tagTitle(for component: InvoiceComponent) -> String {
        if component.type.usesTableProperties { return "Table" }
        if component.type.supportsTypography { return "Text" }
        if component.type.isSection { return "Section" }
        if component.type.isImageComponent { return "Image" }
        if component.type.isShape { return "Shape" }
        return "Component"
    }

    var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.1), Color.accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.accentColor.opacity(0.08), radius: 8, x: 0, y: 2)

                Image("fluent-ic_fluent_options_20_regular", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(NSColor.secondaryLabelColor), Color(NSColor.tertiaryLabelColor)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("No Component Selected")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(NSColor.labelColor))

                Text("Select a component to edit its properties")
                    .font(.system(size: 13))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 32)
        .padding(.vertical, 48)
    }
}

// MARK: - Private Helper Views

struct InspectorHeaderStat: View {
    let icon: String?
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(icon, bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 9, height: 9)
                    .foregroundColor(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.secondaryText)
                    .tracking(0.5)

                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.primaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Previews

#Preview("Inspector Header Stat") {
    HStack(spacing: 12) {
        InspectorHeaderStat(icon: "fluent-ic_fluent_grid_20_regular", label: "Type", value: "Text")
        InspectorHeaderStat(icon: "fluent-ic_fluent_maximize_20_regular", label: "Size", value: "120 × 40")
        InspectorHeaderStat(icon: "fluent-ic_fluent_target_20_regular", label: "Pos", value: "36, 100")
        InspectorHeaderStat(icon: nil, label: "Layer", value: "3")
    }
    .padding()
}
