import SwiftUI
import SharedUI

// MARK: - Inspector Typography System

/// Centralized typography definitions for consistent inspector styling
enum InspectorTypography {
    /// Panel title (e.g., "Properties")
    static let panelTitle = Font.system(size: 14, weight: .semibold, design: .rounded)
    
    /// Panel subtitle (e.g., component type)
    static let panelSubtitle = Font.system(size: 12, weight: .medium, design: .rounded)
    
    /// Main section headers (e.g., "Text", "Appearance", "Layout")
    static let sectionHeader = Font.system(size: 13, weight: .semibold, design: .default)
    
    /// GroupBox headers (e.g., "Font", "Style", "Decoration")
    static let groupHeader = Font.system(size: 12, weight: .medium, design: .default)
    
    /// Control labels (e.g., "Size", "Weight", "Color")
    static let label = Font.system(size: 11, weight: .regular, design: .default)
    
    /// Secondary/subtitle text
    static let caption = Font.system(size: 10, weight: .regular, design: .default)
    
    /// Icon sizes
    static let sectionChevronSize: CGFloat = 12
    static let groupIconSize: CGFloat = 14
    static let groupChevronSize: CGFloat = 11
    static let controlIconSize: CGFloat = 16
    
    /// Spacing
    static let cellPadding: CGFloat = 6
    static let groupBoxPadding: CGFloat = 10
    static let groupBoxSpacing: CGFloat = 8
    static let dividerPadding: CGFloat = 3
    
    /// Button sizing
    static let actionButtonSize: CGFloat = 28
    static let actionButtonIconSize: CGFloat = 16
    static let actionButtonCornerRadius: CGFloat = 8
    
    /// Animation timing
    static let hoverAnimationDuration: Double = 0.15
    static let expandAnimationDuration: Double = 0.2
    static let hoverScaleEffect: CGFloat = 1.05
    
    /// Hover colors
    static let hoverBackgroundOpacity: Double = 0.3
    static let subtleHoverBackgroundOpacity: Double = 0.12
}

// MARK: - Inspector Stepper with TextField

/// A stepper control with an editable text field for numeric input
struct InspectorStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String
    let formatStyle: FormatStyle
    
    enum FormatStyle {
        case integer
        case decimal(places: Int)
    }
    
    @State private var textValue: String = ""
    @FocusState private var isEditing: Bool
    
    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        suffix: String = "pt",
        format: FormatStyle = .integer
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.suffix = suffix
        self.formatStyle = format
    }
    
    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack(spacing: 4) {
                TextField("", text: $textValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 40)
                    .focused($isEditing)
                    .onAppear { updateTextFromValue() }
                    .onChange(of: value) { _, _ in
                        if !isEditing {
                            updateTextFromValue()
                        }
                    }
                    .onSubmit { commitTextValue() }
                    .onChange(of: isEditing) { _, editing in
                        if !editing {
                            commitTextValue()
                        }
                    }
                
                Text(suffix)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
    
    private func updateTextFromValue() {
        switch formatStyle {
        case .integer:
            textValue = "\(Int(value))"
        case .decimal(let places):
            textValue = String(format: "%.\(places)f", value)
        }
    }
    
    private func commitTextValue() {
        if let newValue = Double(textValue) {
            value = min(max(newValue, range.lowerBound), range.upperBound)
        }
        updateTextFromValue()
    }
}

// MARK: - Label Width Alignment System

/// PreferenceKey to collect label widths from all InspectorGridCells
struct LabelWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Environment key to share the maximum label width
private struct InspectorLabelWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var inspectorLabelWidth: CGFloat? {
        get { self[InspectorLabelWidthKey.self] }
        set { self[InspectorLabelWidthKey.self] = newValue }
    }
}

/// View modifier that measures child label widths and provides the max to all children
struct InspectorLabelWidthModifier: ViewModifier {
    @State private var maxLabelWidth: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .onPreferenceChange(LabelWidthPreferenceKey.self) { width in
                maxLabelWidth = width
            }
            .environment(\.inspectorLabelWidth, maxLabelWidth > 0 ? maxLabelWidth : nil)
    }
}

extension View {
    /// Enables label width alignment for all InspectorGridCell children
    func inspectorLabelAlignment() -> some View {
        modifier(InspectorLabelWidthModifier())
    }
}

// MARK: - Inspector Grid Components

/// A row in the inspector grid with a label on the leading edge and content on the trailing edge.
struct InspectorGridCell<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    
    @Environment(\.inspectorLabelWidth) private var alignedWidth
    @State private var isHovered = false
    
    init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label()
        self.content = content()
    }
    
    var body: some View {
        HStack {
            // Label with width measurement
            label
                .fixedSize()
                .overlay(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: LabelWidthPreferenceKey.self,
                            value: geometry.size.width
                        )
                    }
                )
                .frame(width: alignedWidth, alignment: .leading)
                .padding(.trailing, 8)
            Spacer()
            content
        }
        .padding(.vertical, InspectorTypography.cellPadding)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.3) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

/// A Fluent UI icon with optional text label for use in inspector controls.
struct InspectorIcon: View {
    let name: String
    let label: String?
    let showLabel: Bool
    
    init(_ name: String, tooltip: String? = nil, showLabel: Bool = true) {
        self.name = name
        self.label = tooltip
        self.showLabel = showLabel
    }
    
    var body: some View {
        HStack(spacing: 4) {
                Image(name, bundle: .module)
                    .resizable()
                    .renderingMode(.template) 
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    .frame(width: InspectorTypography.controlIconSize, height: InspectorTypography.controlIconSize)
            if showLabel, let label = label {
                Text(label)
                    .font(InspectorTypography.label)
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    .padding(.leading, 4)
            }
        }
        .help(label ?? "")
    }
}

/// A single-column layout for inspector controls with dividers between items.
struct InspectorGrid<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        _VariadicView.Tree(DividedVStackLayout()) {
            content
        }
        .inspectorLabelAlignment()
    }
}

/// A layout that arranges views vertically with dividers between them.
struct DividedVStackLayout: _VariadicView_UnaryViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                child
                if index < children.count - 1 {
                    Divider()
                        .foregroundColor(Color(NSColor.separatorColor))
                        .opacity(0.65)
                        .padding(.vertical, InspectorTypography.dividerPadding)
                }
            }
        }
    }
}
// MARK: - Section Containers

/// Observable class that coordinates accordion state across multiple group boxes
@MainActor
class InspectorAccordionContext: ObservableObject {
    @Published var expandedID: String? = nil
    private var nextIndex = 0
    private var registrations: [(id: String, index: Int)] = []
    private var expansionScheduled = false
    
    /// Get the next visual index for a group box. Must be called during view initialization (not onAppear).
    func getNextIndex() -> Int {
        let index = nextIndex
        nextIndex += 1
        return index
    }
    
    /// Register a group box with its visual index
    func register(_ id: String, index: Int) {
        // Remove any existing registration for this ID
        registrations.removeAll { $0.id == id }
        registrations.append((id: id, index: index))
        
        // Schedule expansion of the first item (by index) after initial registration wave
        if !expansionScheduled {
            expansionScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.expandFirstItem()
            }
        }
    }
    
    private func expandFirstItem() {
        guard expandedID == nil else { return }
        // Find the item with the lowest index and expand it
        if let first = registrations.sorted(by: { $0.index < $1.index }).first {
            expandedID = first.id
        }
    }
    
    func toggle(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedID = (expandedID == id) ? nil : id
        }
    }
    
    func isExpanded(_ id: String) -> Bool {
        expandedID == id
    }
}

private struct InspectorAccordionContextKey: EnvironmentKey {
    static let defaultValue: InspectorAccordionContext? = nil
}

extension EnvironmentValues {
    var inspectorAccordionContext: InspectorAccordionContext? {
        get { self[InspectorAccordionContextKey.self] }
        set { self[InspectorAccordionContextKey.self] = newValue }
    }
}

struct InspectorGroupBox<Content: View>: View {
    let title: String?
    let icon: String?
    let subtitle: String?
    let content: () -> Content
    
    @Environment(\.inspectorAccordionContext) private var accordionContext
    
    // Fallback for when no accordion context is provided - default to collapsed
    @State private var localIsExpanded: Bool = false
    
    // Hover state for interactive feedback
    @State private var isHovered: Bool = false
    
    // Stable fallback ID for when title is nil
    @State private var stableID = UUID().uuidString
    
    // Generate stable ID from title or use fallback
    private var groupID: String {
        title ?? stableID
    }

    init(
        title: String? = nil,
        icon: String? = nil,
        subtitle: String? = nil,
        useForm: Bool = true, // kept for API compatibility, now ignored
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.content = content
    }
    
    private var isExpanded: Bool {
        if let context = accordionContext {
            return context.isExpanded(groupID)
        }
        return localIsExpanded
    }
    
    private func toggleExpansion() {
        if let context = accordionContext {
            context.toggle(groupID)
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                localIsExpanded.toggle()
            }
        }
    }

    var body: some View {
        // Capture visual index during view construction (deterministic order)
        let visualIndex = accordionContext?.getNextIndex() ?? 0
        
        VStack(alignment: .leading, spacing: InspectorTypography.groupBoxSpacing) {
            // Header (if any)
            if title != nil || icon != nil || subtitle != nil {
                collapsibleHeader
                
                if isExpanded {
                    Divider()
                        .foregroundColor(Color(NSColor.separatorColor))
                        .opacity(0.5)
                }
            }
            
            // Content (conditionally shown)
            if isExpanded {
                content()
            }
        }
        .padding(InspectorTypography.groupBoxPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
                )
        )
        .onAppear {
            // Register with accordion context for auto-expand of first group
            accordionContext?.register(groupID, index: visualIndex)
        }
    }
    
    @ViewBuilder
    private var collapsibleHeader: some View {
        Button(action: toggleExpansion) {
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            HStack(spacing: 5) {
                if let icon {
                    Image(icon, bundle: .module)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: InspectorTypography.groupIconSize, height: InspectorTypography.groupIconSize)
                        .foregroundColor(isHovered ? .primary : .secondary)
                }
                if let title {
                    Text(title)
                        .font(InspectorTypography.groupHeader)
                        .kerning(1.0)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(InspectorTypography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image("fluent-ic_fluent_chevron_right_20_regular", bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: InspectorTypography.groupChevronSize, height: InspectorTypography.groupChevronSize)
                    .foregroundColor(isHovered ? Color(NSColor.secondaryLabelColor) : Color(NSColor.tertiaryLabelColor))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(
                shape.fill(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear)
            )
            .foregroundColor(.primary)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .pointerStyle(.link)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

/// View modifier to enable accordion behavior for all InspectorGroupBox children
struct InspectorAccordionModifier: ViewModifier {
    @StateObject private var context = InspectorAccordionContext()
    let defaultExpanded: String?
    
    init(defaultExpanded: String? = nil) {
        self.defaultExpanded = defaultExpanded
    }
    
    func body(content: Content) -> some View {
        content
            .environment(\.inspectorAccordionContext, context)
            .onAppear {
                if let defaultExpanded = defaultExpanded, context.expandedID == nil {
                    context.expandedID = defaultExpanded
                }
            }
    }
}

extension View {
    /// Enables accordion behavior for all InspectorGroupBox children within this view
    func inspectorAccordion(defaultExpanded: String? = nil) -> some View {
        modifier(InspectorAccordionModifier(defaultExpanded: defaultExpanded))
    }
}

// MARK: - Control Rows

struct InspectorAlignmentGridRow: View {
    let label: String
    @Binding var horizontalAlignment: TextAlignment
    @Binding var verticalAlignment: VerticalAlignment
    var onChange: ((TextAlignment, VerticalAlignment) -> Void)? = nil

    var body: some View {
        AlignmentGridPicker(
            label: label,
            horizontalAlignment: $horizontalAlignment,
            verticalAlignment: $verticalAlignment,
            onChange: onChange
        )
        .padding(.top, 4)
    }
}

// MARK: - Action Button

struct InspectorActionButton: View {
    enum Style {
        case normal
        case accent
        case destructive
    }

    let icon: String
    let title: String
    let isActive: Bool
    var isDisabled: Bool = false
    var style: Style = .normal
    var useSystemIcon: Bool = true
    var help: String? = nil
    let action: () -> Void
    
    @State private var isHovered: Bool = false

    var body: some View {
        let button = baseButton
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .scaleEffect(isHovered && !isDisabled ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }

        if let help {
            button.help(help)
        } else {
            button
        }
    }

    private var iconColor: Color {
        if isDisabled { return Color(NSColor.tertiaryLabelColor) }
        return colorForCurrentStyle
    }

    private var colorForCurrentStyle: Color {
        switch style {
        case .accent:
            return Color.accentColor
        case .destructive:
            return Color(NSColor.systemRed)
        default:
            return isActive ? Color.accentColor : Color(NSColor.secondaryLabelColor)
        }
    }

    private var background: Color {
        switch style {
        case .destructive:
            return Color(NSColor.systemRed).opacity(isDisabled ? 0.12 : 0.18)
        case .accent:
            return Color.accentColor.opacity(isDisabled ? 0.14 : 0.22)
        default:
            return isActive ? Color.accentColor.opacity(isDisabled ? 0.12 : 0.18) : Color(NSColor.controlBackgroundColor)
        }
    }

    private var borderColor: Color {
        switch style {
        case .destructive:
            return Color(NSColor.systemRed).opacity(isDisabled ? 0.2 : 0.5)
        case .accent:
            return Color.accentColor.opacity(isDisabled ? 0.2 : 0.45)
        default:
            return Color(NSColor.separatorColor).opacity(isDisabled ? 0.25 : 0.45)
        }
    }

    @ViewBuilder
    private var baseButton: some View {
        Button(action: action) {
            Group {
                if icon.hasPrefix("fluent-") {
                    Image(icon, bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                } else {
                     // Fallback/Legacy path - ideally should not be hit if migration is complete
                     // But if we have any non-fluent string literal, treat it as a bundle asset rather than system name
                     // to prevent accidental SF Symbol usage.
                    Image(icon, bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
            }
            .font(.system(size: InspectorTypography.actionButtonIconSize, weight: .medium))
            .foregroundColor(iconColor)
            .frame(width: InspectorTypography.actionButtonSize, height: InspectorTypography.actionButtonSize)
            .background(
                RoundedRectangle(cornerRadius: InspectorTypography.actionButtonCornerRadius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: InspectorTypography.actionButtonCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .opacity(isDisabled ? 0.35 : 1.0)
            .contentShape(RoundedRectangle(cornerRadius: InspectorTypography.actionButtonCornerRadius, style: .continuous))
        .accessibilityLabel(Text(title))
        }
        .pointerStyle(.link)
    }
}

// MARK: - Previews

#Preview("InspectorStepper") {
    struct PreviewWrapper: View {
        @State private var value: Double = 12
        var body: some View {
            InspectorStepper(value: $value, in: 1...100, step: 1, suffix: "pt")
                .padding()
        }
    }
    return PreviewWrapper()
}

#Preview("InspectorGridCell") {
    InspectorGrid {
        InspectorGridCell {
            Text("Size")
                .font(InspectorTypography.label)
                .foregroundColor(.secondary)
        } content: {
            Text("120 × 40")
                .font(InspectorTypography.label)
        }
        
        InspectorGridCell {
            Text("Position")
                .font(InspectorTypography.label)
                .foregroundColor(.secondary)
        } content: {
            Text("36, 100")
                .font(InspectorTypography.label)
        }
    }
    .frame(width: 250)
    .padding()
}

#Preview("InspectorGroupBox - Expanded") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    
    VStack(spacing: 12) {
        InspectorGroupBox(title: "Font", icon: "fluent-ic_fluent_text_font_20_regular") {
            InspectorGrid {
                InspectorGridCell {
                    Text("Family")
                        .font(InspectorTypography.label)
                        .foregroundColor(.secondary)
                } content: {
                    Text("SF Pro")
                        .font(InspectorTypography.label)
                }
                
                InspectorGridCell {
                    Text("Size")
                        .font(InspectorTypography.label)
                        .foregroundColor(.secondary)
                } content: {
                    Text("14 pt")
                        .font(InspectorTypography.label)
                }
                
                InspectorGridCell {
                    Text("Weight")
                        .font(InspectorTypography.label)
                        .foregroundColor(.secondary)
                } content: {
                    Text("Regular")
                        .font(InspectorTypography.label)
                }
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        InspectorGroupBox(title: "Style", icon: "fluent-ic_fluent_paint_brush_20_regular") {
            Text("Style content here")
                .font(InspectorTypography.label)
        }
        .environment(\.inspectorAccordionContext, context)
    }
    .frame(width: 280)
    .padding()
    .onAppear {
        context.expandedID = "Font"
    }
}

#Preview("InspectorActionButton - States") {
    HStack(spacing: 12) {
        InspectorActionButton(
            icon: "fluent-ic_fluent_lock_open_20_regular",
            title: "Unlock",
            isActive: false,
            useSystemIcon: false,
            action: {}
        )
        
        InspectorActionButton(
            icon: "fluent-ic_fluent_lock_closed_20_regular",
            title: "Lock",
            isActive: true,
            useSystemIcon: false,
            action: {}
        )
        
        InspectorActionButton(
            icon: "fluent-ic_fluent_document_copy_20_regular",
            title: "Duplicate",
            isActive: false,
            style: .accent,
            useSystemIcon: false,
            action: {}
        )
        
        InspectorActionButton(
            icon: "fluent-ic_fluent_delete_20_regular",
            title: "Delete",
            isActive: false,
            style: .destructive,
            useSystemIcon: false,
            action: {}
        )
        
        InspectorActionButton(
            icon: "fluent-ic_fluent_eye_hide_20_regular",
            title: "Hide",
            isActive: false,
            isDisabled: true,
            useSystemIcon: false,
            action: {}
        )
    }
    .padding()
}

#Preview("InspectorAlignmentGridRow") {
    struct PreviewWrapper: View {
        @State private var hAlign: TextAlignment = .center
        @State private var vAlign: VerticalAlignment = .center
        
        var body: some View {
            InspectorAlignmentGridRow(
                label: "Alignment",
                horizontalAlignment: $hAlign,
                verticalAlignment: $vAlign
            )
            .frame(width: 260)
            .padding()
        }
    }
    return PreviewWrapper()
}

// MARK: - Inspector Text Field

/// A text field that only updates the binding on commit (Enter or Focus Loss)
/// to preventing flooding the undo stack with character-by-character updates.
struct InspectorTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    
    @State private var localText: String = ""
    @FocusState private var isFocused: Bool
    
    init(text: Binding<String>, placeholder: String = "") {
        self._text = text
        self.placeholder = placeholder
    }
    
    var body: some View {
        TextField(placeholder, text: $localText)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onAppear {
                localText = text
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    commit()
                } else {
                    localText = text
                }
            }
            .onSubmit {
                commit()
            }
            .onChange(of: text) { _, newValue in
                if !isFocused {
                    localText = newValue
                }
            }
    }
    
    private func commit() {
        if localText != text {
            text = localText
        }
    }
}
