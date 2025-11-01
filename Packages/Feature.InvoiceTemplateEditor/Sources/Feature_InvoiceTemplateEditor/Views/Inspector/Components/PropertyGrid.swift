import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Foundation

// MARK: - Property Grid Container

/// Container for property control/input rows using LabeledContent.
/// 
/// **Important**: Only use PropertyGrid to wrap LabeledContent elements.
/// Each LabeledContent should contain only one control/input element.
/// Do NOT use for sections, containers, or non-control UI elements.
/// 
/// This ensures consistent layout and alignment across control rows.
public struct PropertyGrid<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}


// MARK: - Modern Property Section

struct ModernPropertySection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Color.secondaryText)
                .tracking(0.5)

            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color.primarySurface.opacity(0.03))
                .overlay(
                    Rectangle()
                        .stroke(Color.primaryOutline.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Expandable Property Section

struct ExpandablePropertySection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let content: Content
    let onToggle: () -> Void
    
    init(title: String, isExpanded: Bool, onToggle: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header with indentation
            HStack(alignment: .center) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryText)

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Rectangle()
                    .fill(Color.primarySurface.opacity(0.02))
                    .overlay(
                        Rectangle()
                            .stroke(Color.primaryOutline.opacity(0.12), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    onToggle()
                }
            }
            // Section Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .background(
                    Rectangle()
                        .fill(Color.primarySurface.opacity(0.01))
                        .overlay(
                            Rectangle()
                                .stroke(Color.primaryOutline.opacity(0.08), lineWidth: 0.5)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Modern Property Field

struct ModernPropertyField: View {
    let title: String
    let value: String
    let onValueChange: ((String) -> Void)?
    @State private var text: String
    
    init(title: String, value: String, onValueChange: ((String) -> Void)? = nil) {
        self.title = title
        self.value = value
        self.onValueChange = onValueChange
        self._text = State(initialValue: value)
    }
    
    var body: some View {
        LabeledContent(title) {
            if let onValueChange = onValueChange {
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.mini)
                    .pointerStyle(.horizontalText)
                    .onSubmit {
                        onValueChange(text)
                    }
                    .onChange(of: text) { _, newValue in
                        onValueChange(newValue)
                    }
                    .onChange(of: value) { _, newValue in
                        text = newValue
                    }
            } else {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryText)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Modern Text Field

struct ModernTextField: View {
    let title: String
    let value: String
    let onValueChange: (String) -> Void
    @State private var text: String
    
    init(title: String, value: String, onValueChange: @escaping (String) -> Void) {
        self.title = title
        self.value = value
        self.onValueChange = onValueChange
        self._text = State(initialValue: value)
    }
    
    var body: some View {
        LabeledContent(title) {
            TextField("", text: $text)
                .pointerStyle(.horizontalText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.mini)
                .onSubmit {
                    onValueChange(text)
                }
                .onChange(of: text) { _, newValue in
                    onValueChange(newValue)
                }
                .onChange(of: value) { _, newValue in
                    text = newValue
                }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Modern Color Picker

struct ModernColorPicker: View {
    let title: String
    let color: Color
    let onColorChange: (Color) -> Void
    @State private var selectedColor: Color
    
    init(title: String, color: Color, onColorChange: @escaping (Color) -> Void) {
        self.title = title
        self.color = color
        self.onColorChange = onColorChange
        self._selectedColor = State(initialValue: color)
    }
    
    var body: some View {
        LabeledContent(title) {
            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
                .controlSize(.mini)
                .onChange(of: selectedColor) { _, newColor in
                    onColorChange(newColor)
                }
                .onChange(of: color) { _, newColor in
                    selectedColor = newColor
                }
        }
    }
}

// MARK: - Modern Color Field

struct ModernColorField: View {
    let title: String
    let color: Color

    var body: some View {
        LabeledContent(title) {
            Circle()
                .fill(color)
                .frame(minWidth: 16, minHeight: 16)
                .overlay(
                    Circle()
                        .stroke(Color.primaryText.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Modern Section Header

/// Subsection heading for PropertyGrid
struct ModernSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(Color.secondaryText)
            .padding(.vertical, 4)
    }
}

// MARK: - Modern Divider

/// Divider for PropertyGrid
struct ModernDivider: View {
    var body: some View {
        Divider()
            .background(Color.secondaryText.opacity(0.3))
            .padding(.vertical, 4)
    }
}

// MARK: - Modern Help Text

struct ModernHelpText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(Color.secondaryText)
            .padding(.top, 4)
    }
}

// MARK: - Modern Tab Label

struct ModernTabLabel: View {
    let title: String
    let icon: String
    let index: Int

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(Color.primaryText)
    }
}

// MARK: - Modern Value Display

struct ModernValueDisplay: View {
    let value: String
    let unit: String?

    init(_ value: String, unit: String? = nil) {
        self.value = value
        self.unit = unit
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color.primaryText)
                .monospacedDigit()

            if let unit = unit {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(Color.secondaryText)
            }
        }
    }
}

// MARK: - Modern Range Display

struct ModernRangeDisplay: View {
    let min: String
    let max: String
    let unit: String?

    init(min: String, max: String, unit: String? = nil) {
        self.min = min
        self.max = max
        self.unit = unit
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(min)
                .font(.caption2)
                .foregroundColor(Color.secondaryText)
                .monospacedDigit()

            Text("–")
                .font(.caption2)
                .foregroundColor(Color.secondaryText)

            Text(max)
                .font(.caption2)
                .foregroundColor(Color.secondaryText)
                .monospacedDigit()

            if let unit = unit {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(Color.secondaryText)
            }
        }
    }
}

// MARK: - Modern Status Indicator

struct ModernStatusIndicator: View {
    let isActive: Bool
    let activeText: String
    let inactiveText: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.accentColor : Color.secondaryText.opacity(0.5))
                .frame(minWidth: 6, minHeight: 6)

            Text(isActive ? activeText : inactiveText)
                .font(.caption2)
                .foregroundColor(Color.secondaryText)
        }
    }
}

// MARK: - Modern Icon Button

struct ModernIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color.accentColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modern Info Button

struct ModernInfoButton: View {
    let helpText: String

    var body: some View {
        Button(action: {}) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(Color.secondaryText)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}

// MARK: - Modern Expandable Section

struct ModernExpandableSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: Content

    init(title: String, isExpanded: Bool, onToggle: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    onToggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.primaryText)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isExpanded)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.primarySurface)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Modern Tab View

struct ModernTabView<Content: View>: View {
    let selection: Binding<Int>
    let content: Content

    init(selection: Binding<Int>, @ViewBuilder content: () -> Content) {
        self.selection = selection
               self.content = content()
    }

    var body: some View {
        TabView(selection: selection) {
            content
        }
        .tabViewStyle(.automatic)
    }
}

// MARK: - Modern Scroll View

struct ModernScrollView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
        }
    }
}

// MARK: - Modern Grid Layout

struct ModernGrid<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: Content

    init(columns: Int, spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.columns = columns
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            content
        }
    }
}

