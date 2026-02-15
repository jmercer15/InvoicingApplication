import SwiftUI
import Core
import SharedUI

struct LayoutPropertyEditor: View {
    let context: SectionSplitLeafContext
    @Binding var expandedSections: Set<AnyHashable>
    
    @EnvironmentObject private var document: InvoiceDocument

    @State private var labelText: String = ""
    @State private var showingSplitDialog = false
    @State private var dialogDirection: SectionSplit.SplitDirection = .horizontal
    @State private var dialogSplitCount = 2
    @FocusState private var isLabelFocused: Bool
    @State private var showAdvancedLayout = false

    private var currentChildPadding: SectionSplit.PaddingInsets {
        context.parentSplit.childPaddings[safe: context.childIndex] ?? .zero
    }

    var body: some View {
        InspectorContentLayout(
            header: header,
            descriptors: sectionDescriptors.filter { $0.isVisible },
            expandedSections: $expandedSections
        )
        .onAppear {
            labelText = context.label
        }
        .onChange(of: context.selection) { _ in
            labelText = context.label
        }
        .onChange(of: context.label) { newValue in
            if !isLabelFocused {
                labelText = newValue
            }
        }
        .sheet(isPresented: $showingSplitDialog) {
            SplitConfigurationDialog(
                direction: $dialogDirection,
                splitCount: $dialogSplitCount,
                onConfirm: { direction, count, rows, columns in
                    performSplit(direction: direction, count: count, rows: rows, columns: columns)
                    showingSplitDialog = false
                },
                onCancel: {
                    showingSplitDialog = false
                }
            )
        }
        .onChange(of: isLabelFocused) { focused in
            if !focused {
                commitLabelChanges()
            }
        }
    }
    

    // MARK: - Header
    
    private var header: some View {
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
                Image(isSplitSelection ? "fluent-ic_fluent_split_horizontal_20_regular" : "fluent-ic_fluent_square_20_regular", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(Color.accentColor)
            }
            .frame(width: 28, height: 28)
            
            Text(isSplitSelection ? "Split" : "Leaf")
                .font(InspectorTypography.panelTitle)
                .foregroundColor(Color.primaryText)
            
            Text("· \(context.label)")
                .font(InspectorTypography.panelSubtitle)
                .foregroundColor(Color.secondaryText)
            
            Spacer()
        }
    }

    private var selectionSummary: String {
        let total = context.parentSplit.children.count
        return "Child \(context.childIndex + 1)/\(total)"
    }

    private var ratioLabel: String? {
        guard context.parentSplit.direction != .grid,
              let ratio = context.ratio else { return nil }
        let percent = Int((ratio * 100).rounded())
        return "\(percent)%"
    }

    private var gridPositionLabel: String? {
        context.gridPositionDescription
    }

    private var gridSizeLabel: String? {
        context.gridSizeDescription
    }

    // MARK: - Sections Definition
    
    private enum SplitInspectorSection: Hashable {
        case dimensions
        case layout
        case structure
    }
    
    private var sectionDescriptors: [InspectorSectionDescriptor<SplitInspectorSection>] {
        [
            InspectorSectionDescriptor(
                section: .dimensions,
                title: "Dimensions",
                alwaysExpanded: false,
                isVisible: true,
                buildContent: { AnyView(dimensionsSection) }
            ),
            InspectorSectionDescriptor(
                section: .layout,
                title: "Layout",
                alwaysExpanded: false,
                isVisible: true,
                buildContent: { AnyView(layoutSection) }
            ),
            InspectorSectionDescriptor(
                section: .structure,
                title: "Structure",
                alwaysExpanded: false,
                isVisible: isSplitSelection,
                buildContent: { AnyView(structureSection) }
            )
        ]
    }

    // MARK: - Section Content
    
    @ViewBuilder
    private var dimensionsSection: some View {
        InspectorGroupBox(title: "Dimensions", icon: "fluent-ic_fluent_arrow_expand_20_regular") {
            InspectorGrid {
                InspectorControl.text("label", icon: "fluent-ic_fluent_text_case_title_20_regular", tooltip: "Label", text: $labelText)
            }

            // Alignment (custom component - kept as-is)
            InspectorAlignmentGridRow(
                label: "Alignment",
                horizontalAlignment: horizontalTextAlignmentBinding,
                verticalAlignment: verticalAlignmentBinding
            ) { hAlign, vAlign in
                let h: SectionSplit.LeafAlignment.HorizontalAlignment
                switch hAlign {
                case .leading: h = .leading
                case .center: h = .center
                case .trailing: h = .trailing
                default: h = .leading
                }
                
                let v: SectionSplit.LeafAlignment.VerticalAlignment
                switch vAlign {
                case .top: v = .top
                case .center: v = .center
                case .bottom: v = .bottom
                default: v = .top
                }
                
                let alignment = SectionSplit.LeafAlignment(horizontal: h, vertical: v)
                document.setSplitAlignment(for: context.selection, alignment: alignment)
            }
        }
    }
    
    @ViewBuilder
    private var layoutSection: some View {
        InspectorGroupBox(title: "Layout", icon: "fluent-ic_fluent_match_app_layout_20_regular") {
            InspectorGrid {
                // Padding
                InspectorControl.stepper("padding", icon: "fluent-ic_fluent_border_all_20_regular",
                                        tooltip: "All Edges", value: uniformPaddingBinding, range: 0...64, step: 4)
                
                InspectorControl.stepper("horizontal", icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                        tooltip: "Horizontal", value: horizontalPaddingBinding, range: 0...64, step: 4)
                
                InspectorControl.stepper("vertical", icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                                        tooltip: "Vertical", value: verticalPaddingBinding, range: 0...64, step: 4)
                
                // Allocation
                if canAdjustRatio {
                    InspectorControl.stepper("allocation", icon: "fluent-ic_fluent_resize_image_20_regular",
                                            tooltip: "Allocation", value: ratioPercentBinding, range: ratioPercentRange, step: 5, suffix: "%")
                }
                
                // Sizing modes
                if context.parentSplit.direction == .horizontal || context.parentSplit.direction == .grid {
                    sizingPicker("widthSizing", icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                tooltip: "Width", binding: widthSizingBinding)
                }

                if context.parentSplit.direction == .vertical || context.parentSplit.direction == .grid {
                    sizingPicker("heightSizing", icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                                tooltip: "Height", binding: heightSizingBinding)
                }
                
                // Children settings (splits only)
                if isSplitSelection {
                    InspectorControl.stepper("spacing", icon: "fluent-ic_fluent_row_triple_20_regular",
                                            tooltip: "Child Spacing", value: parentSpacingBinding, range: 0...64, step: 4)
                }
            }
            
            if canAdjustRatio {
                Button("Equalize Siblings") { equalizeSiblingRatios() }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .contentShape(Rectangle())
                    .padding(.top, 4)
            }
        }
    }
    
    /// Helper for sizing mode pickers
    @ViewBuilder
    private func sizingPicker(_ id: String, icon: String, tooltip: String, binding: Binding<SectionSplit.SizingMode>) -> some View {
        InspectorControl.picker(id, icon: icon, tooltip: tooltip, selection: binding) {
            ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
    }

    @ViewBuilder
    private var structureSection: some View {
        InspectorGroupBox(title: "Split Tools", icon: "fluent-ic_fluent_grid_20_regular") {
            LazyVGrid(columns: splitToolColumns, spacing: 8) {
                ForEach(splitToolPresets) { preset in
                    SplitToolButton(preset: preset)
                }
            }
            .padding(.vertical, 2)

            if canMergeParentSplit {
                InspectorGrid {
                    InspectorControl.button("mergeSplit", icon: "fluent-ic_fluent_delete_20_regular",
                                           tooltip: "Merge Split", title: "Merge Parent Split", action: {
                                            mergeParentSplit()
                                           })
                                           .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Computed Helpers

    private var canAdjustRatio: Bool {
        context.parentSplit.splitCount > 1
    }

    private var ratioBounds: ClosedRange<Double> {
        0.05...0.95
    }

    private var ratioBinding: Binding<Double> {
        Binding(
            get: {
                let raw = Double(context.ratio ?? 1.0)
                if context.parentSplit.splitCount > 1 {
                    return min(max(raw, 0.05), 0.95)
                }
                return raw
            },
            set: { newValue in
                document.setSplitRatio(for: context.selection, ratio: CGFloat(newValue))
            }
        )
    }

    private var ratioPercentBinding: Binding<Double> {
        Binding(
            get: { ratioBinding.wrappedValue * 100 },
            set: { newPercent in
                let normalized = max(ratioBounds.lowerBound, min(ratioBounds.upperBound, newPercent / 100))
                ratioBinding.wrappedValue = normalized
            }
        )
    }

    private var horizontalTextAlignmentBinding: Binding<TextAlignment> {
        Binding(
            get: {
                switch context.alignment.horizontal {
                case .leading: return .leading
                case .center: return .center
                case .trailing: return .trailing
                }
            },
            set: { newValue in
                let hAlign: SectionSplit.LeafAlignment.HorizontalAlignment
                switch newValue {
                case .leading: hAlign = .leading
                case .center: hAlign = .center
                case .trailing: hAlign = .trailing
                default: hAlign = .leading
                }
                
                let alignment = SectionSplit.LeafAlignment(
                    horizontal: hAlign,
                    vertical: context.alignment.vertical
                )
                document.setSplitAlignment(for: context.selection, alignment: alignment)
            }
        )
    }

    private var verticalAlignmentBinding: Binding<VerticalAlignment> {
        Binding(
            get: {
                switch context.alignment.vertical {
                case .top: return .top
                case .center: return .center
                case .bottom: return .bottom
                }
            },
            set: { newValue in
                let vAlign: SectionSplit.LeafAlignment.VerticalAlignment
                switch newValue {
                case .top: vAlign = .top
                case .center: vAlign = .center
                case .bottom: vAlign = .bottom
                default: vAlign = .top
                }
                
                let alignment = SectionSplit.LeafAlignment(
                    horizontal: context.alignment.horizontal,
                    vertical: vAlign
                )
                document.setSplitAlignment(for: context.selection, alignment: alignment)
            }
        )
    }

    private var widthSizingBinding: Binding<SectionSplit.SizingMode> {
        Binding(
            get: {
                if context.parentSplit.direction == .grid {
                    return getGridColumnSizingMode()
                } else {
                    return context.parentSplit.childWidthSizingModes[safe: context.childIndex] ?? .fixed
                }
            },
            set: { setWidthSizingMode($0) }
        )
    }

    private var heightSizingBinding: Binding<SectionSplit.SizingMode> {
        Binding(
            get: {
                if context.parentSplit.direction == .grid {
                    return getGridRowSizingMode()
                } else {
                    return context.parentSplit.childHeightSizingModes[safe: context.childIndex] ?? .fixed
                }
            },
            set: { setHeightSizingMode($0) }
        )
    }

    private var ratioPercentRange: ClosedRange<Double> {
        0...100
    }

    // Unified Padding Binding
    private var uniformPaddingBinding: Binding<Double> {
        Binding(
            get: {
                // Use top padding as representative
                Double(currentChildPadding.top)
            },
            set: { newValue in
                document.setUniformChildPadding(for: context.selection, value: CGFloat(newValue))
            }
        )
    }
    
    // Horizontal padding (leading + trailing)
    private var horizontalPaddingBinding: Binding<Double> {
        Binding(
            get: {
                Double(currentChildPadding.leading)
            },
            set: { newValue in
                let current = currentChildPadding
                let newPadding = SectionSplit.PaddingInsets(
                    top: current.top,
                    leading: CGFloat(newValue),
                    bottom: current.bottom,
                    trailing: CGFloat(newValue)
                )
                document.setChildPadding(for: context.selection, value: newPadding)
            }
        )
    }
    
    // Vertical padding (top + bottom)
    private var verticalPaddingBinding: Binding<Double> {
        Binding(
            get: {
                Double(currentChildPadding.top)
            },
            set: { newValue in
                let current = currentChildPadding
                let newPadding = SectionSplit.PaddingInsets(
                    top: CGFloat(newValue),
                    leading: current.leading,
                    bottom: CGFloat(newValue),
                    trailing: current.trailing
                )
                document.setChildPadding(for: context.selection, value: newPadding)
            }
        )
    }

    private var childPaddingTopBinding: Binding<Double> {
        childPaddingBinding(get: { $0.top }) { current, newValue in
            SectionSplit.PaddingInsets(top: CGFloat(newValue), leading: current.leading, bottom: current.bottom, trailing: current.trailing)
        }
    }

    private var childPaddingLeadingBinding: Binding<Double> {
        childPaddingBinding(get: { $0.leading }) { current, newValue in
            SectionSplit.PaddingInsets(top: current.top, leading: CGFloat(newValue), bottom: current.bottom, trailing: current.trailing)
        }
    }

    private var childPaddingBottomBinding: Binding<Double> {
        childPaddingBinding(get: { $0.bottom }) { current, newValue in
            SectionSplit.PaddingInsets(top: current.top, leading: current.leading, bottom: CGFloat(newValue), trailing: current.trailing)
        }
    }

    private var childPaddingTrailingBinding: Binding<Double> {
        childPaddingBinding(get: { $0.trailing }) { current, newValue in
            SectionSplit.PaddingInsets(top: current.top, leading: current.leading, bottom: current.bottom, trailing: CGFloat(newValue))
        }
    }

    private func childPaddingBinding(
        get: @escaping (SectionSplit.PaddingInsets) -> CGFloat,
        update: @escaping (SectionSplit.PaddingInsets, Double) -> SectionSplit.PaddingInsets
    ) -> Binding<Double> {
        Binding(
            get: { Double(get(currentChildPadding)) },
            set: { newValue in
                let newPadding = update(currentChildPadding, newValue)
                document.setChildPadding(for: context.selection, value: newPadding)
            }
        )
    }

    private var splitToolColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 50), spacing: 8)]
    }

    private var splitToolPresets: [SplitToolPreset] {
        [
            SplitToolPreset(
                icon: "tool-split-vertical",
                badge: nil,
                title: "2 Columns",
                helpText: "Split into two equal columns",
                style: .normal,
                useSystemIcon: false
            ) {
                performSplit(direction: .horizontal, count: 2)
            },
            SplitToolPreset(
                icon: "tool-split-vertical-3",
                badge: nil,
                title: "3 Columns",
                helpText: "Split into three columns",
                style: .normal,
                useSystemIcon: false
            ) {
                performSplit(direction: .horizontal, count: 3)
            },
            SplitToolPreset(
                icon: "tool-split-horizontal",
                badge: nil,
                title: "2 Rows",
                helpText: "Split into two rows",
                style: .normal,
                useSystemIcon: false
            ) {
                performSplit(direction: .vertical, count: 2)
            },
            SplitToolPreset(
                icon: "tool-split-horizontal-3",
                badge: nil,
                title: "3 Rows",
                helpText: "Split into three rows",
                style: .normal,
                useSystemIcon: false
            ) {
                performSplit(direction: .vertical, count: 3)
            },
            SplitToolPreset(
                icon: "tool-split-grid",
                badge: nil,
                title: "2 × 2 Grid",
                helpText: "Split into a 2×2 grid",
                style: .normal,
                useSystemIcon: false
            ) {
                performSplit(direction: .grid, count: 4, rows: 2, columns: 2)
            },
            SplitToolPreset(
                icon: "tool-split-custom",
                badge: nil,
                title: "Custom…",
                helpText: "Open custom split options",
                style: .normal,
                useSystemIcon: false
            ) {
                dialogDirection = context.parentSplit.direction
                dialogSplitCount = max(2, context.parentSplit.splitCount)
                showingSplitDialog = true
            }
        ]
    }

    private var defaultChildLabel: String {
        context.parentSplit.getDefaultLabel(forChild: context.childIndex)
    }

    // MARK: - Actions

    private func commitLabelChanges() {
        document.setSplitLabel(for: context.selection, label: labelText)
    }

    // True when the selected slot holds a split (not a leaf)
    private var isSplitSelection: Bool {
        context.parentSplit.children[safe: context.childIndex] != nil
    }
    
    private func performSplit(direction: SectionSplit.SplitDirection, count: Int, rows: Int? = nil, columns: Int? = nil) {
        document.splitSelection(
            context.selection,
            direction: direction,
            splitCount: count,
            gridRows: rows,
            gridColumns: columns
        )

        var newPath = context.selection.path
        newPath.append(0)
        let newSelection = SectionSplitSelection(sectionIndex: context.selection.sectionIndex, path: newPath)
        document.selectSplitSelection(newSelection)
    }
    
    // MARK: - Parent Sizing Helpers
    
    private func getGridColumnSizingMode() -> SectionSplit.SizingMode {
        let (_, column) = context.parentSplit.rowColumn(for: context.childIndex)
        return context.parentSplit.columnSizingModes[safe: column] ?? .fixed
    }
    
    private func getGridRowSizingMode() -> SectionSplit.SizingMode {
        let (row, _) = context.parentSplit.rowColumn(for: context.childIndex)
        return context.parentSplit.rowSizingModes[safe: row] ?? .fixed
    }
    
    private func setWidthSizingMode(_ mode: SectionSplit.SizingMode) {
        if context.parentSplit.direction == .grid {
            let (_, column) = context.parentSplit.rowColumn(for: context.childIndex)
            document.setGridColumnSizingMode(for: context.selection, column: column, mode: mode)
        } else {
            document.setWidthSizingMode(for: context.selection, mode: mode)
        }
    }
    
    private func setHeightSizingMode(_ mode: SectionSplit.SizingMode) {
        if context.parentSplit.direction == .grid {
            let (row, _) = context.parentSplit.rowColumn(for: context.childIndex)
            document.setGridRowSizingMode(for: context.selection, row: row, mode: mode)
        } else {
            document.setHeightSizingMode(for: context.selection, mode: mode)
        }
    }

    private var canMergeParentSplit: Bool {
        context.selection.path.count >= 2
    }

    private func mergeParentSplit() {
        guard canMergeParentSplit else { return }
        document.removeSplitContainingSelection(context.selection)
        let newPath = Array(context.selection.path.dropLast())
        document.selectSplitSelection(SectionSplitSelection(sectionIndex: context.selection.sectionIndex, path: newPath))
    }

    private func equalizeSiblingRatios() {
        document.equalizeSplitRatios(for: context.selection)
    }

    private var parentPaddingBinding: Binding<Double> {
        numericBinding(
            get: { $0.padding },
            set: document.setSplitPadding
        )
    }

    private var parentMarginBinding: Binding<Double> {
        numericBinding(
            get: { $0.margin },
            set: document.setSplitMargin
        )
    }

    private var parentSpacingBinding: Binding<Double> {
        numericBinding(
            get: { $0.childSpacing },
            set: document.setSplitSpacing
        )
    }

    private func numericBinding(
        get: @escaping (SectionSplit) -> CGFloat,
        set: @escaping (SectionSplitSelection, CGFloat) -> Void
    ) -> Binding<Double> {
        Binding(
            get: { Double(get(context.parentSplit)) },
            set: { set(context.selection, CGFloat($0)) }
        )
    }

}
    

// MARK: - Local Components

private struct SplitToolPreset: Identifiable {
    let id = UUID()
    let icon: String
    let badge: String?
    let title: String
    let helpText: String
    let style: InspectorActionButton.Style
    let useSystemIcon: Bool
    let action: () -> Void
}

private struct SplitToolButton: View {
    let preset: SplitToolPreset

    var body: some View {
        VStack(spacing: 6) {
            InspectorActionButton(
                icon: preset.icon,
                title: preset.title,
                isActive: false,
                style: preset.style,
                useSystemIcon: preset.useSystemIcon,
                help: preset.helpText,
                action: preset.action
            )
            .overlay(alignment: .topTrailing) {
                if let badge = preset.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .padding(3)
                        .foregroundColor(Color(NSColor.controlAccentColor))
                        .offset(x: 6, y: -6)
                }
            }

            Text(preset.title)
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(NSColor.labelColor))
        }
        .frame(maxWidth: .infinity)
    }
}
