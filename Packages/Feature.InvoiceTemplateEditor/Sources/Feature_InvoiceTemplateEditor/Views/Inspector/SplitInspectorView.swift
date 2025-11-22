import SwiftUI
import Core
import SharedUI

// MARK: - Array Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct SplitInspectorView: View {
    @EnvironmentObject private var document: InvoiceDocument
    let context: SectionSplitLeafContext

    @State private var labelText: String
    @State private var horizontalAlignment: SectionSplit.LeafAlignment.HorizontalAlignment
    @State private var verticalAlignment: SectionSplit.LeafAlignment.VerticalAlignment
    @State private var ratioValue: Double
    @State private var parentPadding: Double
    @State private var parentMargin: Double
    @State private var parentSpacing: Double
    @State private var childPaddingTop: Double
    @State private var childPaddingLeading: Double
    @State private var childPaddingBottom: Double
    @State private var childPaddingTrailing: Double
    @State private var showingSplitDialog = false
    @State private var dialogDirection: SectionSplit.SplitDirection = .horizontal
    @State private var dialogSplitCount = 2
    @FocusState private var isLabelFocused: Bool
    
    // MARK: - Section Expansion State
    @State private var expandedSections: Set<SplitInspectorSection> = []

    init(context: SectionSplitLeafContext) {
        self.context = context
        _labelText = State(initialValue: context.label)
        _horizontalAlignment = State(initialValue: context.alignment.horizontal)
        _verticalAlignment = State(initialValue: context.alignment.vertical)
        _ratioValue = State(initialValue: SplitInspectorView.initialRatioValue(for: context))
        _parentPadding = State(initialValue: Double(context.parentSplit.padding))
        _parentMargin = State(initialValue: Double(context.parentSplit.margin))
        _parentSpacing = State(initialValue: Double(context.parentSplit.childSpacing))
        let pad = context.parentSplit.childPaddings[safe: context.childIndex] ?? .zero
        _childPaddingTop = State(initialValue: Double(pad.top))
        _childPaddingLeading = State(initialValue: Double(pad.leading))
        _childPaddingBottom = State(initialValue: Double(pad.bottom))
        _childPaddingTrailing = State(initialValue: Double(pad.trailing))
    }

    var body: some View {
        ScrollView {
            inspectorContent
        }
        .onChange(of: context.label, perform: updateLabel)
        .onChange(of: context.alignment.horizontal, perform: updateHorizontalAlignment)
        .onChange(of: context.alignment.vertical, perform: updateVerticalAlignment)
        .onChange(of: context.ratio, perform: updateRatio)
        .onAppear(perform: syncLayoutState)
        .onChange(of: document.selectedSplitSelection?.path) { _ in syncLayoutState() }
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
        .onChange(of: isSplitSelection) { _ in
            rebuildExpandedSections()
        }
        .onChange(of: document.selectedSplitSelection?.path) { _ in
            rebuildExpandedSections()
        }
    }
    
    private var inspectorContent: some View {
        let descriptors = sectionDescriptors
        return VStack(alignment: .leading, spacing: 10) {
            header
            
            Divider()
                .background(Color(NSColor.separatorColor).opacity(0.3))
            
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(descriptors) { descriptor in
                    inspectorSection(
                        title: descriptor.title,
                        section: descriptor.section,
                        alwaysExpanded: descriptor.alwaysExpanded,
                        isVisible: descriptor.isVisible
                    ) {
                        descriptor.buildContent()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Split Properties")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color(NSColor.labelColor))

            Text(context.directionName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Sections Definition
    
    private enum SplitInspectorSection: Hashable {
        case labelAndAlignment
        case parentSizing
        case layoutSpacingAndPadding
        case layoutAndRatio
        case structureTools
    }
    
    private struct SplitInspectorSectionDescriptor: Identifiable {
        let section: SplitInspectorSection
        let title: String
        let alwaysExpanded: Bool
        let isVisible: Bool
        let buildContent: () -> AnyView

        var id: SplitInspectorSection { section }
    }
    
    private var sectionDescriptors: [SplitInspectorSectionDescriptor] {
        [
            SplitInspectorSectionDescriptor(
                section: .labelAndAlignment,
                title: "Label & Alignment",
                alwaysExpanded: false,
                isVisible: true,
                buildContent: { AnyView(labelAlignmentSection) }
            ),
            SplitInspectorSectionDescriptor(
                section: .parentSizing,
                title: "Parent Sizing",
                alwaysExpanded: false,
                isVisible: isSplitSelection,
                buildContent: { AnyView(parentSizingSection) }
            ),
            SplitInspectorSectionDescriptor(
                section: .layoutSpacingAndPadding,
                title: "Spacing & Padding",
                alwaysExpanded: false,
                isVisible: true, // always show (split controls gated inside)
                buildContent: { AnyView(layoutPaddingSection) }
            ),
            SplitInspectorSectionDescriptor(
                section: .layoutAndRatio,
                title: "Layout & Ratio",
                alwaysExpanded: false,
                isVisible: isSplitSelection,
                buildContent: { AnyView(layoutSection) }
            ),
            SplitInspectorSectionDescriptor(
                section: .structureTools,
                title: "Structure Tools",
                alwaysExpanded: false,
                isVisible: isSplitSelection,
                buildContent: { AnyView(structureToolsSection) }
            )
        ]
    }

    // MARK: - Section Content
    
    @ViewBuilder
    private var labelAlignmentSection: some View {
        controlGroupBox {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Label")
                        .controlLabelStyle()
                    TextField("", text: $labelText)
                        .textFieldStyle(.roundedBorder)
                        .controlValueStyle()
                        .focused($isLabelFocused)
                        .onSubmit(commitLabelChanges)
                }
                
                InspectorActionButton(
                    icon: "arrow.counterclockwise",
                    title: "",
                    isActive: false,
                    help: "Reset Label"
                ) {
                    labelText = defaultChildLabel
                    commitLabelChanges()
                }
                .padding(.bottom, 2)
            }
            
            Divider().padding(.vertical, 2)

            InspectorAlignmentGridRow(
                label: "Alignment",
                horizontalAlignment: horizontalTextAlignmentBinding,
                verticalAlignment: verticalAlignmentBinding
            )
        }
    }
    
    @ViewBuilder
    private var parentSizingSection: some View {
        controlGroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("How the parent split sizes this section:")
                    .font(.system(size: 11))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                
                // Show width sizing for horizontal splits or grid columns
                if context.parentSplit.direction == .horizontal || context.parentSplit.direction == .grid {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width Sizing")
                            .controlLabelStyle()
                        
                        let currentWidthMode = context.parentSplit.direction == .grid
                            ? getGridColumnSizingMode()
                            : context.parentSplit.childWidthSizingModes[safe: context.childIndex] ?? .fixed
                        
                        HStack(spacing: 8) {
                            ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                                InspectorActionButton(
                                    icon: mode.icon,
                                    title: mode.displayName,
                                    isActive: currentWidthMode == mode,
                                    help: mode.displayName
                                ) {
                                    setWidthSizingMode(mode)
                                }
                            }
                        }
                    }
                }
                
                // Show height sizing for vertical splits or grid rows
                if context.parentSplit.direction == .vertical || context.parentSplit.direction == .grid {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Height Sizing")
                            .controlLabelStyle()
                        
                        let currentHeightMode = context.parentSplit.direction == .grid
                            ? getGridRowSizingMode()
                            : context.parentSplit.childHeightSizingModes[safe: context.childIndex] ?? .fixed
                        
                        HStack(spacing: 8) {
                            ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                                InspectorActionButton(
                                    icon: mode.icon,
                                    title: mode.displayName,
                                    isActive: currentHeightMode == mode,
                                    help: mode.displayName
                                ) {
                                    setHeightSizingMode(mode)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var layoutSection: some View {
        controlGroupBox {
            if canAdjustRatio {
                VStack(alignment: .leading, spacing: 12) {
                    // Header with Label and Percentage
                    HStack {
                        Text("Allocation")
                            .controlLabelStyle()
                        Spacer()
                        
                        HStack(spacing: 4) {
                            TextField(
                                "",
                                value: ratioPercentBinding,
                                format: .number.precision(.fractionLength(1))
                            )
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .controlValueStyle(numeric: true)
                            
                            Text("%")
                                .controlLabelStyle()
                        }
                    }

                    // Slider and Fine Tune Stepper
                    HStack(spacing: 12) {
                        Slider(value: ratioBinding, in: ratioBounds)
                            .controlSize(.small)
                        
                        Stepper(value: ratioBinding, in: ratioBounds, step: 0.01) {
                            EmptyView()
                        }
                        .labelsHidden()
                        .controlSize(.small)
                    }

                    // Quick Actions
                    HStack(spacing: 8) {
                        InspectorActionButton(
                            icon: "circle.grid.2x2",
                            title: "Even",
                            isActive: false,
                            help: "Even split"
                        ) {
                            equalizeSiblingRatios()
                        }

                        Spacer()

                        InspectorActionButton(
                            icon: "minus.circle",
                            title: "-5%",
                            isActive: false,
                            help: "Decrease by 5%"
                        ) {
                            adjustRatio(by: -0.05)
                        }

                        InspectorActionButton(
                            icon: "plus.circle",
                            title: "+5%",
                            isActive: false,
                            help: "Increase by 5%"
                        ) {
                            adjustRatio(by: 0.05)
                        }
                    }
                }
            } else {
                Text("Ratio adjustments are disabled because this split only contains one leaf.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    .padding(.vertical, 4)
            }
        }
    }
    
    @ViewBuilder
    private var layoutPaddingSection: some View {
        controlGroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if isSplitSelection {
                    HStack {
                        Text("Spacing between siblings")
                            .controlLabelStyle()
                        Spacer()
                        Stepper("", value: $parentSpacing, in: 0...200, step: 2)
                            .labelsHidden()
                            .controlSize(.small)
                        Text("\(Int(parentSpacing)) pt")
                            .controlValueStyle(numeric: true)
                    }
                    .onChange(of: parentSpacing) { newValue in
                        document.setSplitSpacing(for: context.selection, value: CGFloat(newValue))
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    HStack {
                        Text("Parent padding (inside split)")
                            .controlLabelStyle()
                        Spacer()
                        Stepper("", value: $parentPadding, in: 0...200, step: 2)
                            .labelsHidden()
                            .controlSize(.small)
                        Text("\(Int(parentPadding)) pt")
                            .controlValueStyle(numeric: true)
                    }
                    .onChange(of: parentPadding) { newValue in
                        document.setSplitPadding(for: context.selection, value: CGFloat(newValue))
                    }
                    
                    HStack {
                        Text("Parent margin (outside split)")
                            .controlLabelStyle()
                        Spacer()
                        Stepper("", value: $parentMargin, in: 0...200, step: 2)
                            .labelsHidden()
                            .controlSize(.small)
                        Text("\(Int(parentMargin)) pt")
                            .controlValueStyle(numeric: true)
                    }
                    .onChange(of: parentMargin) { newValue in
                        document.setSplitMargin(for: context.selection, value: CGFloat(newValue))
                    }
                    
                    Divider().padding(.vertical, 4)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("This section padding")
                        .controlLabelStyle()
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                        GridRow {
                            Text("Top").frame(width: 50, alignment: .leading)
                            Stepper("", value: $childPaddingTop, in: 0...200, step: 2)
                                .labelsHidden()
                                .controlSize(.small)
                            Text("\(Int(childPaddingTop)) pt")
                                .controlValueStyle(numeric: true)
                        }
                        GridRow {
                            Text("Leading").frame(width: 50, alignment: .leading)
                            Stepper("", value: $childPaddingLeading, in: 0...200, step: 2)
                                .labelsHidden()
                                .controlSize(.small)
                            Text("\(Int(childPaddingLeading)) pt")
                                .controlValueStyle(numeric: true)
                        }
                        GridRow {
                            Text("Bottom").frame(width: 50, alignment: .leading)
                            Stepper("", value: $childPaddingBottom, in: 0...200, step: 2)
                                .labelsHidden()
                                .controlSize(.small)
                            Text("\(Int(childPaddingBottom)) pt")
                                .controlValueStyle(numeric: true)
                        }
                        GridRow {
                            Text("Trailing").frame(width: 50, alignment: .leading)
                            Stepper("", value: $childPaddingTrailing, in: 0...200, step: 2)
                                .labelsHidden()
                                .controlSize(.small)
                            Text("\(Int(childPaddingTrailing)) pt")
                                .controlValueStyle(numeric: true)
                        }
                    }
                }
                .onChange(of: childPaddingTop) { _ in pushChildPadding() }
                .onChange(of: childPaddingLeading) { _ in pushChildPadding() }
                .onChange(of: childPaddingBottom) { _ in pushChildPadding() }
                .onChange(of: childPaddingTrailing) { _ in pushChildPadding() }
                
                if isSplitSelection {
                    Text("Spacing/margins adjust the selected split; \"This section padding\" adjusts the selected section inside it.")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var structureToolsSection: some View {
        controlGroupBox {
            LazyVGrid(columns: splitToolColumns, spacing: 8) {
                ForEach(splitToolPresets) { preset in
                    SplitToolButton(preset: preset)
                }
            }
            .padding(.vertical, 2)

            if canMergeParentSplit {
                Divider().padding(.vertical, 4)
                
                InspectorActionButton(
                    icon: "arrow.triangle.merge",
                    title: "Merge parent split",
                    isActive: false,
                    style: .destructive
                ) {
                    mergeParentSplit()
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func binding(for section: SplitInspectorSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { newValue in updateExpansion(for: section, isExpanded: newValue) }
        )
    }

    private func updateExpansion(for section: SplitInspectorSection, isExpanded: Bool) {
        withAnimation(.smooth(duration: 0.3)) {
            if isExpanded {
                expandedSections.insert(section)
            } else {
                expandedSections.remove(section)
            }
        }
    }
    
    private func sectionID(_ section: SplitInspectorSection) -> String {
        String(describing: section).lowercased()
    }
    
    @ViewBuilder
    private func inspectorSection(
        title: String,
        section: SplitInspectorSection,
        alwaysExpanded: Bool = false,
        isVisible: Bool,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        if isVisible {
            let sectionBinding = alwaysExpanded ? .constant(true) : binding(for: section)
            let expandedRadius: CGFloat = 10
            let collapsedRadius: CGFloat = 8

            HierarchySectionCard(
                title: title,
                isExpanded: sectionBinding,
                isCollapsible: !alwaysExpanded,
                expandedCornerRadius: expandedRadius,
                collapsedCornerRadius: collapsedRadius
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(sectionID(section))
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private func controlGroupBox<Content: View>(
        title: String? = nil,
        icon: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                }
                    .padding(.bottom, 2)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.secondary)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .glassEffect(
            .regular.tint(Color(NSColor.windowBackgroundColor)),
            in: .rect(cornerRadius: 14)
        )
        .glassEffectTransition(.materialize)
        .accessibilityElement(children: .contain)
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
            get: { ratioValue },
            set: { newValue in
                ratioValue = newValue
                document.setSplitRatio(for: context.selection, ratio: CGFloat(newValue))
            }
        )
    }

    private var ratioPercentBinding: Binding<Double> {
        Binding(
            get: { ratioValue * 100 },
            set: { newPercent in
                let normalized = max(ratioBounds.lowerBound, min(ratioBounds.upperBound, newPercent / 100))
                ratioBinding.wrappedValue = normalized
            }
        )
    }

    private var horizontalTextAlignmentBinding: Binding<TextAlignment> {
        Binding(
            get: {
                switch horizontalAlignment {
                case .leading: return .leading
                case .center: return .center
                case .trailing: return .trailing
                }
            },
            set: { newValue in
                switch newValue {
                case .leading: horizontalAlignment = .leading
                case .center: horizontalAlignment = .center
                case .trailing: horizontalAlignment = .trailing
                }
                applyAlignment()
            }
        )
    }

    private var verticalAlignmentBinding: Binding<VerticalAlignment> {
        Binding(
            get: {
                switch verticalAlignment {
                case .top: return .top
                case .center: return .center
                case .bottom: return .bottom
                }
            },
            set: { newValue in
                switch newValue {
                case .top: verticalAlignment = .top
                case .center: verticalAlignment = .center
                case .bottom: verticalAlignment = .bottom
                default: verticalAlignment = .top
                }
                applyAlignment()
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

    private func applyAlignment() {
        let alignment = SectionSplit.LeafAlignment(
            horizontal: horizontalAlignment,
            vertical: verticalAlignment
        )
        document.setSplitAlignment(for: context.selection, alignment: alignment)
    }

    private static func initialRatioValue(for context: SectionSplitLeafContext) -> Double {
        let rawValue = Double(context.ratio ?? 1.0)
        if context.parentSplit.splitCount > 1 {
            return min(max(rawValue, 0.05), 0.95)
        }
        return rawValue
    }
    
    private var currentChildPadding: SectionSplit.PaddingInsets {
        context.parentSplit.childPaddings[safe: context.childIndex] ?? .zero
    }
    
    // True when the selected slot holds a split (not a leaf)
    private var isSplitSelection: Bool {
        context.parentSplit.children[safe: context.childIndex] != nil
    }
    
    private var currentLayoutSplit: SectionSplit {
        if let selection = document.selectedSplitSelection,
           var split = document.sectionSplits[selection.sectionIndex] {
            for index in selection.path {
                guard let next = split.children[safe: index] else { break }
                if let child = next {
                    split = child
                } else {
                    break
                }
            }
            return split
        }
        return context.parentSplit
    }
    
    // MARK: - Change Handlers
    private func updateLabel(_ newValue: String) {
        labelText = newValue
    }
    
    private func updateHorizontalAlignment(_ newValue: SectionSplit.LeafAlignment.HorizontalAlignment) {
        horizontalAlignment = newValue
    }
    
    private func updateVerticalAlignment(_ newValue: SectionSplit.LeafAlignment.VerticalAlignment) {
        verticalAlignment = newValue
    }
    
    private func updateRatio(_ newValue: CGFloat?) {
        let next = Double(newValue ?? CGFloat(ratioValue))
        ratioValue = canAdjustRatio
            ? min(max(next, ratioBounds.lowerBound), ratioBounds.upperBound)
            : next
    }
    
    private func updateParentPadding(_ newValue: CGFloat) {
        parentPadding = Double(newValue)
    }
    
    private func updateParentMargin(_ newValue: CGFloat) {
        parentMargin = Double(newValue)
    }
    
    private func updateParentSpacing(_ newValue: CGFloat) {
        parentSpacing = Double(newValue)
    }
    
    private func updateChildPadding(_ newValue: SectionSplit.PaddingInsets) {
        childPaddingTop = Double(newValue.top)
        childPaddingLeading = Double(newValue.leading)
        childPaddingBottom = Double(newValue.bottom)
        childPaddingTrailing = Double(newValue.trailing)
    }
    
    private func pushChildPadding() {
        let padding = SectionSplit.PaddingInsets(
            top: CGFloat(childPaddingTop),
            leading: CGFloat(childPaddingLeading),
            bottom: CGFloat(childPaddingBottom),
            trailing: CGFloat(childPaddingTrailing)
        )
        document.setChildPadding(for: context.selection, value: padding)
    }
    
    private func syncLayoutState() {
        let split = currentLayoutSplit
        parentPadding = Double(split.padding)
        parentMargin = Double(split.margin)
        parentSpacing = Double(split.childSpacing)
        
        let pad = split.childPaddings[safe: context.childIndex] ?? .zero
        childPaddingTop = Double(pad.top)
        childPaddingLeading = Double(pad.leading)
        childPaddingBottom = Double(pad.bottom)
        childPaddingTrailing = Double(pad.trailing)
        
        rebuildExpandedSections()
    }
    
    private func rebuildExpandedSections() {
        let visible = Set(sectionDescriptors.filter { $0.isVisible }.map { $0.section })
        
        // Keep current expansions that are still visible
        var next = expandedSections.intersection(visible)
        
        expandedSections = next
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

    private func adjustRatio(by delta: Double) {
        guard canAdjustRatio else { return }
        let nextValue = min(max(ratioValue + delta, ratioBounds.lowerBound), ratioBounds.upperBound)
        ratioBinding.wrappedValue = nextValue
    }

}

// MARK: - Local Components

private struct InspectorActionButton: View {
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

    @ViewBuilder
    var body: some View {
        let button = baseButton
            .buttonStyle(.plain)
            .disabled(isDisabled)

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

    private var accentColor: Color {
        switch style {
        case .accent:
            return Color.accentColor
        case .destructive:
            return Color(NSColor.systemRed)
        default:
            return Color(NSColor.secondaryLabelColor)
        }
    }

    private var colorForCurrentStyle: Color {
        if isActive || style == .accent {
            return accentColor
        } else if style == .destructive {
            return accentColor
        } else {
            return Color(NSColor.secondaryLabelColor)
        }
    }
    

    private var baseButton: some View {
        Button(action: action) {
            Group {
                if useSystemIcon {
                    Image(systemName: icon)
                } else {
                    Image(icon, bundle: .module)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(iconColor)
            .frame(width: 20, height: 20)
            .opacity(isDisabled ? 0.35 : 1.0)
            .accessibilityLabel(Text(title))
        }
    }
}

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
                        .background(Color(NSColor.controlAccentColor))
                        .clipShape(Circle())
                        .foregroundColor(.white)
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
