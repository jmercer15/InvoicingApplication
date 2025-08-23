import SwiftUI

// MARK: - Reusable Button Styles & Controls

// --- Standard Toolbar Button Style ---
struct StandardToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    var tintColor: Color = .accentColor // Default accent color

    func makeBody(configuration: Configuration) -> some View {
        // Determine the primary color for the gradient based on enabled state and tintColor
        let primaryFillColor = isEnabled ? tintColor : Color.gray.opacity(0.2)
        let secondaryFillColor = isEnabled ? tintColor.opacity(0.8) : Color.gray.opacity(0.1)

        // Determine the border color
        let borderColor = isEnabled ? tintColor.opacity(0.2) : Color.gray.opacity(0.2)

        // Determine the foreground color
        let foreground = isEnabled ? .white : Color.gray // Default to white, change to gray if disabled

        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(height: 28)
            .font(.system(size: 12))
            .foregroundColor(foreground) // Apply the determined foreground color
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [primaryFillColor, secondaryFillColor]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                    RoundedRectangle(cornerRadius: 6)
                                .stroke(borderColor, lineWidth: 1)
                        )
                }
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : (isHovering ? 0.85 : 1.0)) : 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

// --- Toolbar Segment Button Style ---
struct ToolbarSegmentButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .font(.system(size: 12))
            .foregroundColor(isEnabled ? (isSelected ? .white : Color.accentColor) : .gray)
            .background(
                Group {
                    if isSelected {
                        Color.accentColor
                    } else if isHovering {
                        Color.accentColor.opacity(0.1)
                    } else {
                        Color.clear
                    }
                }
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1.0) : 0.5)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

// --- Filter Button Style (Used in Sidebar) ---
struct FilterButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                         RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(configuration.isPressed ? 0.3 : 0.2))
                         RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor, lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(configuration.isPressed ? 0.2 : 0.1))
                    }
                }
            )
            .foregroundColor(isSelected ? .accentColor : .primary.opacity(0.8))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// --- Custom Segmented Control ---
struct CustomSegmentedControl<SelectionValue, Label>: View where SelectionValue: Hashable & Identifiable, Label: View {
    let options: [SelectionValue]
    @Binding var selection: SelectionValue
    let labelProvider: (SelectionValue) -> Label

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = option
                    }
                } label: {
                    labelProvider(option)
                }
                .buttonStyle(ToolbarSegmentButtonStyle(isSelected: selection == option))
                .appInteractiveCursor()
            }
        }
        .frame(height: 28)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.accentColor.opacity(0.4), lineWidth: 1))
    }
} 