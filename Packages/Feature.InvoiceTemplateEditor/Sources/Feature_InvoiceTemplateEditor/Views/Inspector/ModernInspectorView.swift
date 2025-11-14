import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Foundation
import Core
import SharedUI

struct ModernInspectorView: View {
    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var templateDataService: TemplateDataService
    
    // MARK: - Section Expansion State
    @State private var expandedSections: Set<InspectorSection> = []

    // MARK: - Table Stateful Controls
    @State private var tableTypographySelectedTab = 0
    @State private var tableColumnsSelectedTab = 0
    @State private var tableTypographyInitialised = false
    @State private var tableColumnsInitialised = false
    @State private var lastTypographyComponentID: UUID?
    @State private var lastColumnsComponentID: UUID?

    // MARK: - Miscellaneous State
    @State private var lastSelectedComponentID: UUID?

    private var selectedComponent: InvoiceComponent? {
        document.component(document.selectedComponentID)
    }

    private enum ColumnWidthMode: String, CaseIterable {
        case flexible = "Flexible"
        case autoSize = "Fit"
        case fixed = "Fixed"
    }

    // MARK: - Helper Functions
    private func binding(for section: InspectorSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { newValue in updateExpansion(for: section, isExpanded: newValue) }
        )
    }

    private func updateExpansion(for section: InspectorSection, isExpanded: Bool) {
        withAnimation(.smooth(duration: 0.3)) {
            if isExpanded {
                collapseGroups(for: section)
                expandedSections.insert(section)
            } else {
                collapse(section)
            }
        }
    }

    private func collapseGroups(for section: InspectorSection) {
        for group in section.collapseGroups {
            for member in group where member != section {
                collapse(member)
            }
        }
    }

    private func collapse(_ section: InspectorSection) {
        expandedSections.remove(section)
        for descendant in section.descendants {
            expandedSections.remove(descendant)
        }
    }

    enum InspectorSection: Hashable {
        case text
        case appearance
        case table
        case image
        case shape
    }
    private func ensureTableTypographyData(for component: InvoiceComponent) {
        guard !tableTypographyInitialised || lastTypographyComponentID != component.id else { return }
        let generator = DocumentGridDataGenerator(component: component, templateDataService: templateDataService, clientId: nil, invoiceId: nil)
        let sampleData = generator.generateSampleData()
        let detectedColumns = sampleData.first?.count ?? 4

        if component.style.tableDirection == .horizontal {
            if component.style.columnConfigurations.isEmpty {
                document.initializeColumnConfigurations(for: component.id, columnCount: detectedColumns)
            }
        } else {
            if component.style.rowConfigurations.isEmpty {
                document.initializeRowConfigurations(for: component.id, rowCount: sampleData.count)
            }
        }

        tableTypographyInitialised = true
        lastTypographyComponentID = component.id
    }

    private func ensureTableColumnData(for component: InvoiceComponent) {
        guard !tableColumnsInitialised || lastColumnsComponentID != component.id else { return }
        let generator = DocumentGridDataGenerator(component: component, templateDataService: templateDataService, clientId: nil, invoiceId: nil)
        let sampleData = generator.generateSampleData()
        let detectedColumns = sampleData.first?.count ?? 4

        if component.style.columnConfigurations.isEmpty {
            document.initializeColumnConfigurations(for: component.id, columnCount: detectedColumns)
        }

        tableColumnsInitialised = true
        lastColumnsComponentID = component.id
    }
    var body: some View {
        Group {
            if let component = selectedComponent {
                let capabilities = InspectorCapabilities(component: component)
        VStack(alignment: .leading, spacing: 0) {
                    header(for: component)

                    Divider()
                        .background(Color(NSColor.separatorColor).opacity(0.3))

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(sectionDescriptors(for: component, capabilities: capabilities)) { descriptor in
                                inspectorSection(
                                    title: descriptor.title,
                                    section: descriptor.section,
                                    alwaysExpanded: descriptor.alwaysExpanded,
                                    isVisible: descriptor.isVisible
                                ) {
                                    descriptor.content()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                        .frame(maxWidth: .infinity)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                //.padding(6)
                .glassEffect(
                    .regular.tint(.white),
                    in: .rect(cornerRadius: 12)
                )
                .glassEffectTransition(.materialize)
                .padding(12)
            } else {
                emptyState
            }
        }
        .foregroundColor(Color.primaryText)
    }

    // MARK: - Top-Level Sections
    @ViewBuilder
    private func inspectorSection(
        title: String,
        section: InspectorSection,
        level: InspectorFontLevel = .l2SectionHeader,
        alwaysExpanded: Bool = false,
        isVisible: Bool,
        expandedRadius: CGFloat = 10,
        collapsedRadius: CGFloat = 8,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        if isVisible {
            InspectorPropertySection(
                title: title,
                binding: alwaysExpanded ? .constant(true) : binding(for: section),
                level: level,
                alwaysExpanded: alwaysExpanded,
                expandedRadius: expandedRadius,
                collapsedRadius: collapsedRadius,
                idPrefix: sectionID(section),
                content: content
            )
        }
    }

    private func sectionID(_ section: InspectorSection) -> String {
        String(describing: section).lowercased()
    }

    @ViewBuilder
    private func textSectionContent(for component: InvoiceComponent, capabilities: InspectorCapabilities) -> some View {
        if capabilities.showsContentControls {
            if capabilities.nestsContentControls {
                textContentControls(for: component, title: "Content")
            } else {
                textContentControls(for: component)
            }
        }

        if capabilities.showsTypographySection {
            textTypographyControls(for: component)
        }
    }

    private func sectionDescriptors(for component: InvoiceComponent, capabilities: InspectorCapabilities) -> [InspectorSectionDescriptor] {
        let category = inspectorCategory(for: component)
        let descriptors = [
            InspectorSectionDescriptor(
                identifier: "text",
                title: "Text",
                section: .text,
                alwaysExpanded: false,
                isVisible: category == .text && capabilities.showsTextSection
            ) {
                AnyView(textSectionContent(for: component, capabilities: capabilities))
            },
            InspectorSectionDescriptor(
                identifier: "appearance",
                title: "Appearance",
                section: .appearance,
                alwaysExpanded: false,
                isVisible: capabilities.showsAppearanceSection
            ) {
                AnyView(appearanceSection(for: component))
            },
            InspectorSectionDescriptor(
                identifier: "table",
                title: "Table",
                section: .table,
                alwaysExpanded: false,
                isVisible: category == .table && capabilities.showsTableSection
            ) {
                AnyView(tableSection(for: component))
            },
            InspectorSectionDescriptor(
                identifier: "image",
                title: "Image",
                section: .image,
                alwaysExpanded: true,
                isVisible: category == .image && capabilities.showsImageSection
            ) {
                AnyView(imageContentControls(for: component))
            },
            InspectorSectionDescriptor(
                identifier: "shape",
                title: "Shape",
                section: .shape,
                alwaysExpanded: true,
                isVisible: category == .shape && capabilities.showsShapeSection
            ) {
                AnyView(shapeSection(for: component))
            }
        ]

        let descriptorMap = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.section, $0) })
        let order = orderedSections(for: category)

        return order.compactMap { section -> InspectorSectionDescriptor? in
            guard let descriptor = descriptorMap[section], descriptor.isVisible else { return nil }
            return descriptor
        }
    }

    @ViewBuilder
    private func textContentControls(for component: InvoiceComponent, title: String? = nil) -> some View {
        controlGroupBox(title: title) {
            InspectorTextFieldRow(
                label: "Content",
                text: Binding(
                    get: { component.style.placeholderText },
                    set: { document.updatePlaceholderText(for: component.id, text: $0) }
                )
            )

            InspectorButtonRow(
                label: "Clear Content",
                title: "Clear"
            ) {
                document.updatePlaceholderText(for: component.id, text: "")
            }
        }
    }

    @ViewBuilder
    private func imageContentControls(for component: InvoiceComponent) -> some View {
        controlGroupBox {
            InspectorPickerRow(
                label: "Content Mode",
                selection: Binding(
                    get: { component.style.imageContentMode },
                    set: { document.updateImageContentMode(for: component.id, mode: $0) }
                ),
                options: ImageContentMode.allCases
            ) { mode in
                Text(mode.rawValue.capitalized)
                    .controlValueStyle()
                    .tag(mode)
            }

            InspectorStepperFieldRow(
                label: "Opacity",
                value: Binding(
                    get: { Double(component.style.imageOpacity) },
                    set: { document.updateImageOpacity(for: component.id, opacity: CGFloat($0)) }
                ),
                range: 0...1,
                step: 0.1
            )
        }
    }

    @ViewBuilder
    private func controlGroupBox<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        } label: {
            if let title {
                Text(title)
                    .font(InspectorFontLevel.l4SubSubsection.font)
                    .foregroundColor(InspectorFontLevel.l4SubSubsection.foregroundColor)
                    .opacity(InspectorFontLevel.l4SubSubsection.textOpacity)
                    .tracking(InspectorFontLevel.l4SubSubsection.letterSpacing)
            } else {
                EmptyView()
            }
        }
        .inspectorControlGroupStyle()
    }

    // MARK: - Text Typography Content
    @ViewBuilder
    private func textTypographyControls(for component: InvoiceComponent) -> some View {
        Group {
            controlGroupBox(title: "Font") {
                InspectorTextFieldRow(
                    label: "Font Family",
                    text: Binding(
                        get: { component.style.fontFamily },
                        set: { document.updateFontFamily(for: component.id, family: $0) }
                    )
                )

                InspectorStepperFieldRow(
                    label: "Font Size",
                    value: Binding(
                        get: { Double(component.style.fontSize) },
                        set: { document.updateFontSize(for: component.id, fontSize: CGFloat($0)) }
                    ),
                    range: 6...72,
                    step: 1
                )

                InspectorTextFieldRow(
                    label: "Font Weight",
                    text: Binding(
                        get: { component.style.fontWeight },
                        set: { document.updateFontWeight(for: component.id, weight: $0) }
                    )
                )
            }

            controlGroupBox(title: "Spacing") {
                InspectorStepperFieldRow(
                    label: "Line Spacing",
                    value: Binding(
                        get: { Double(component.style.lineSpacing) },
                        set: { document.updateLineSpacing(for: component.id, spacing: CGFloat($0)) }
                    ),
                    range: 0.5...3.0,
                    step: 0.1
                )

                InspectorStepperFieldRow(
                    label: "Letter Spacing",
                    value: Binding(
                        get: { Double(component.style.letterSpacing) },
                        set: { document.updateLetterSpacing(for: component.id, spacing: CGFloat($0)) }
                    ),
                    range: -2.0...5.0,
                    step: 0.1
                )
            }

            controlGroupBox(title: "Paragraph & Case") {
                InspectorPickerRow(
                    label: "Text Alignment",
                    selection: Binding(
                        get: { component.style.textAlignment },
                        set: { document.updateTextAlignment(for: component.id, alignment: $0) }
                    ),
                    options: TextAlignment.allCases
                ) { alignment in
                    Text(alignment.rawValue.capitalized)
                        .controlValueStyle()
                        .tag(alignment)
                }

                InspectorPickerRow(
                    label: "Text Transform",
                    selection: Binding(
                        get: { component.style.textTransform },
                        set: { document.updateTextTransform(for: component.id, transform: $0) }
                    ),
                    options: TextTransform.allCases
                ) { transform in
                    Text(transform.rawValue.capitalized)
                        .controlValueStyle()
                        .tag(transform)
                }
            }

            controlGroupBox(title: "Decoration") {
                InspectorToggleRow(
                    label: "Underline",
                    isOn: Binding(
                        get: { component.style.textUnderline },
                        set: { document.updateTextUnderline(for: component.id, underline: $0) }
                    )
                )

                InspectorToggleRow(
                    label: "Strikethrough",
                    isOn: Binding(
                        get: { component.style.textStrikethrough },
                        set: { document.updateTextStrikethrough(for: component.id, strikethrough: $0) }
                    )
                )
            }

            controlGroupBox(title: "Color & Opacity") {
                InspectorColorPickerRow(
                    label: "Text Color",
                    color: Binding(
                        get: { component.style.textColorSwiftUI },
                        set: { document.updateTextColor(for: component.id, color: $0.toHex()) }
                    )
                )

                InspectorStepperFieldRow(
                    label: "Text Opacity",
                    value: Binding(
                        get: { Double(component.style.textOpacity) },
                        set: { document.updateTextOpacity(for: component.id, opacity: CGFloat($0)) }
                    ),
                    range: 0...1,
                    step: 0.1
                )
            }
        }
    }

    private func orderedSections(for category: InspectorCategory) -> [InspectorSection] {
        switch category {
        case .text:
            return [.text, .appearance]
        case .container:
            return [.text, .appearance]
        case .table:
            return [.table]
        case .image:
            return [.image, .appearance]
        case .shape:
            return [.shape, .appearance]
        }
    }
    // MARK: - Appearance Content
    @ViewBuilder
    private func appearanceSection(for component: InvoiceComponent) -> some View {
        Group {
            if component.type.supportsBackgroundFill {
                controlGroupBox(title: "Background") {
                    InspectorColorPickerRow(
                        label: "Background",
                        color: Binding(
                            get: { component.style.backgroundColorSwiftUI },
                            set: { document.updateBackgroundColor(for: component.id, color: $0.toHex()) }
                        )
                    )

                    InspectorStepperFieldRow(
                        label: "Opacity",
                        value: Binding(
                            get: { Double(component.style.backgroundOpacity) },
                            set: { document.updateBackgroundOpacity(for: component.id, opacity: CGFloat($0)) }
                        ),
                        range: 0...1,
                        step: 0.1
                    )
                }
            }

            if component.type.supportsBorderControls {
                controlGroupBox(title: "Border") {
                    InspectorColorPickerRow(
                        label: "Border Color",
                        color: Binding(
                            get: { component.style.borderColorSwiftUI },
                            set: { document.updateBorderColor(for: component.id, color: $0.toHex()) }
                        )
                    )

                    InspectorStepperFieldRow(
                        label: "Border Width",
                        value: Binding(
                            get: { Double(component.style.borderWidth) },
                            set: { document.updateBorderWidth(for: component.id, width: CGFloat($0)) }
                        ),
                        range: 0...10,
                        step: 0.5
                    )

                    InspectorStepperFieldRow(
                        label: "Corner Radius",
                        value: Binding(
                            get: { Double(component.style.cornerRadius) },
                            set: { document.updateCornerRadius(for: component.id, radius: CGFloat($0)) }
                        ),
                        range: 0...25,
                        step: 0.5
                    )
                }
            }

            if component.type.supportsShadow {
                controlGroupBox(title: "Shadow") {
                    InspectorToggleRow(
                        label: "Shadow",
                        isOn: Binding(
                            get: { component.style.shadowEnabled },
                            set: { document.updateShadowEnabled(for: component.id, enabled: $0) }
                        )
                    )
                }

                if component.style.shadowEnabled {
                    controlGroupBox(title: "Color & Opacity") {
                        InspectorColorPickerRow(
                            label: "Shadow Color",
                            color: Binding(
                                get: { component.style.shadowColorSwiftUI },
                                set: { document.updateShadowColor(for: component.id, color: $0.toHex()) }
                            )
                        )

                        InspectorStepperFieldRow(
                            label: "Shadow Opacity",
                            value: Binding(
                                get: { Double(component.style.shadowOpacity) },
                                set: { document.updateShadowOpacity(for: component.id, opacity: CGFloat($0)) }
                            ),
                            range: 0...1,
                            step: 0.1
                        )
                    }

                    controlGroupBox(title: "Offset & Blur") {
                        InspectorStepperFieldRow(
                            label: "X",
                            value: Binding(
                                get: { Double(component.style.shadowOffsetX) },
                                set: {
                                    let clamped = CGFloat(min(max($0, -20), 20))
                                    let currentY = document.component(component.id)?.style.shadowOffsetY ?? component.style.shadowOffsetY
                                    document.updateShadowOffset(for: component.id, x: clamped, y: currentY)
                                }
                            ),
                            range: -20...20,
                            step: 0.5
                        )

                        InspectorStepperFieldRow(
                            label: "Y",
                            value: Binding(
                                get: { Double(component.style.shadowOffsetY) },
                                set: {
                                    let clamped = CGFloat(min(max($0, -20), 20))
                                    let currentX = document.component(component.id)?.style.shadowOffsetX ?? component.style.shadowOffsetX
                                    document.updateShadowOffset(for: component.id, x: currentX, y: clamped)
                                }
                            ),
                            range: -20...20,
                            step: 0.5
                        )

                        InspectorStepperFieldRow(
                            label: "Shadow Radius",
                            value: Binding(
                                get: { Double(component.style.shadowRadius) },
                                set: { document.updateShadowRadius(for: component.id, radius: CGFloat($0)) }
                            ),
                            range: 0...20,
                            step: 0.5
                        )
                    }
                }
            }
        }
    }
    // MARK: - Table Content
    @ViewBuilder
    private func tableSection(for component: InvoiceComponent) -> some View {
        Group {
            controlGroupBox(title: "Layout") {
                InspectorPickerRow(
                    label: "Direction",
                    selection: Binding(
                        get: { component.style.tableDirection },
                        set: { document.updateTableDirection(for: component.id, direction: $0) }
                    ),
                    options: TableDirection.allCases
                ) { direction in
                    Text(direction.rawValue.capitalized)
                        .controlValueStyle()
                        .tag(direction)
                }

                InspectorButtonRow(
                    label: "Reset Direction",
                    title: "Reset"
                ) {
                    document.updateTableDirection(for: component.id, direction: .horizontal)
                }
            }

            controlGroupBox(title: "Structure") {
                InspectorToggleRow(
                    label: "Show Header",
                    isOn: Binding(
                        get: { component.style.showTableHeader },
                        set: { document.updateShowTableHeader(for: component.id, show: $0) }
                    )
                )

                InspectorColorPickerRow(
                    label: "Text Color",
                    color: Binding(
                        get: { component.style.tableTextColorSwiftUI },
                        set: { document.updateTableTextColor(for: component.id, color: $0.toHex()) }
                    )
                )
            }

            controlGroupBox(title: "Fill") {
                InspectorColorPickerRow(
                    label: "Header Fill",
                    color: Binding(
                        get: { component.style.tableHeaderColorSwiftUI },
                        set: { document.updateTableHeaderColor(for: component.id, color: $0.toHex()) }
                    )
                )

                InspectorColorPickerRow(
                    label: "Row Fill",
                    color: Binding(
                        get: { component.style.tableRowColorSwiftUI },
                        set: { document.updateTableRowColor(for: component.id, color: $0.toHex()) }
                    )
                )

                InspectorColorPickerRow(
                    label: "Alt Row Fill",
                    color: Binding(
                        get: { component.style.tableRowAltColorSwiftUI },
                        set: { document.updateTableRowAltColor(for: component.id, color: $0.toHex()) }
                    )
                )

                InspectorToggleRow(
                    label: "Alternating Rows",
                    isOn: Binding(
                        get: { component.style.useAlternatingRows },
                        set: { document.updateUseAlternatingRows(for: component.id, use: $0) }
                    )
                )
            }

            controlGroupBox(title: "Borders") {
                InspectorToggleRow(
                    label: "Show Borders",
                    isOn: Binding(
                        get: { component.style.showTableBorders },
                        set: { document.updateShowTableBorders(for: component.id, show: $0) }
                    )
                )
            }

            if component.style.showTableBorders {
                controlGroupBox(title: "Border Appearance") {
                    InspectorColorPickerRow(
                        label: "Border Color",
                        color: Binding(
                            get: { component.style.tableBorderColorSwiftUI },
                            set: { document.updateTableBorderColor(for: component.id, color: $0.toHex()) }
                        )
                    )

                    InspectorStepperFieldRow(
                        label: "Border Width",
                        value: Binding(
                            get: { Double(component.style.tableBorderWidth) },
                            set: { document.updateTableBorderWidth(for: component.id, width: CGFloat($0)) }
                        ),
                        range: 0...5,
                        step: 0.5
                    )
                }
            }

            controlGroupBox(title: "Border Visibility") {
                InspectorToggleRow(
                    label: "Header Borders",
                    isOn: Binding(
                        get: { component.style.showHeaderBorder },
                        set: { document.updateShowHeaderBorder(for: component.id, show: $0) }
                    )
                )

                InspectorToggleRow(
                    label: "Row Borders",
                    isOn: Binding(
                        get: { component.style.showRowBorders },
                        set: { document.updateShowRowBorders(for: component.id, show: $0) }
                    )
                )

                InspectorToggleRow(
                    label: "Cell Borders",
                    isOn: Binding(
                        get: { component.style.showCellBorders },
                        set: { document.updateShowCellBorders(for: component.id, show: $0) }
                    )
                )
            }

            controlGroupBox(title: "Shadow") {
                InspectorToggleRow(
                    label: "Shadow",
                    isOn: Binding(
                        get: { component.style.shadowEnabled },
                        set: { document.updateShadowEnabled(for: component.id, enabled: $0) }
                    )
                )
            }

            if component.style.shadowEnabled {
                controlGroupBox(title: "Shadow Color & Opacity") {
                    InspectorColorPickerRow(
                        label: "Shadow Color",
                        color: Binding(
                            get: { component.style.shadowColorSwiftUI },
                            set: { document.updateShadowColor(for: component.id, color: $0.toHex()) }
                        )
                    )

                    InspectorStepperFieldRow(
                        label: "Shadow Opacity",
                        value: Binding(
                            get: { Double(component.style.shadowOpacity) },
                            set: { document.updateShadowOpacity(for: component.id, opacity: CGFloat($0)) }
                        ),
                        range: 0...1,
                        step: 0.1
                    )
                }

                controlGroupBox(title: "Offset & Blur") {
                    InspectorStepperFieldRow(
                        label: "X",
                        value: Binding(
                            get: { Double(component.style.shadowOffsetX) },
                            set: {
                                let clamped = CGFloat(min(max($0, -20), 20))
                                let currentY = document.component(component.id)?.style.shadowOffsetY ?? component.style.shadowOffsetY
                                document.updateShadowOffset(for: component.id, x: clamped, y: currentY)
                            }
                        ),
                        range: -20...20,
                        step: 0.5
                    )

                    InspectorStepperFieldRow(
                        label: "Y",
                        value: Binding(
                            get: { Double(component.style.shadowOffsetY) },
                            set: {
                                let clamped = CGFloat(min(max($0, -20), 20))
                                let currentX = document.component(component.id)?.style.shadowOffsetX ?? component.style.shadowOffsetX
                                document.updateShadowOffset(for: component.id, x: currentX, y: clamped)
                            }
                        ),
                        range: -20...20,
                        step: 0.5
                    )

                    InspectorStepperFieldRow(
                        label: "Shadow Radius",
                        value: Binding(
                            get: { Double(component.style.shadowRadius) },
                            set: { document.updateShadowRadius(for: component.id, radius: CGFloat($0)) }
                        ),
                        range: 0...20,
                        step: 0.5
                    )
                }
            }

            controlGroupBox(title: "Spacing") {
                InspectorStepperFieldRow(
                    label: "Cell Padding",
                    value: Binding(
                        get: { Double(component.style.tableCellPadding) },
                        set: { document.updateTableCellPadding(for: component.id, padding: CGFloat($0)) }
                    ),
                    range: 0...20,
                    step: 1
                )

                InspectorStepperFieldRow(
                    label: "Header Padding",
                    value: Binding(
                        get: { Double(component.style.tableHeaderPadding) },
                        set: { document.updateTableHeaderPadding(for: component.id, padding: CGFloat($0)) }
                    ),
                    range: 0...20,
                    step: 1
                )
            }

            controlGroupBox(title: "Typography") {
                tableTypographyControls(for: component)
            }

            controlGroupBox(title: "Column Configuration") {
                tableColumnControls(for: component)
            }
        }
    }
    private func tableTypographyControls(for component: InvoiceComponent) -> some View {
        ensureTableTypographyData(for: component)
        let currentComponent = document.component(component.id) ?? component
        let generator = DocumentGridDataGenerator(component: currentComponent, templateDataService: templateDataService, clientId: nil, invoiceId: nil)
        let sampleData = generator.generateSampleData()
        let tabCount = currentComponent.style.tableDirection == .horizontal ? (sampleData.first?.count ?? 4) : sampleData.count
        let selectedIndex = min(tableTypographySelectedTab, max(0, tabCount - 1))
        let isHorizontal = currentComponent.style.tableDirection == .horizontal
        let columnConfig = currentComponent.style.columnConfiguration(for: selectedIndex)
        let rowConfig = currentComponent.style.rowConfiguration(for: selectedIndex)

        return VStack(alignment: .leading, spacing: 6) {
            if tabCount > 1 {
                InspectorLabeledRow(
                    label: currentComponent.style.tableDirection == .horizontal ? "Column" : "Row"
                ) {
                    Picker(
                        "",
                        selection: $tableTypographySelectedTab
                    ) {
                        ForEach(Array(0..<tabCount), id: \.self) { index in
                            Text(currentComponent.style.tableDirection == .horizontal ? "Column \(index + 1)" : "Row \(index + 1)")
                                .controlValueStyle()
                                .tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            InspectorPickerRow(
                label: "Font Family",
                selection: Binding(
                    get: { FontFamilyOption(styleValue: currentComponent.style.fontFamily) },
                    set: { document.updateFontFamily(for: component.id, family: $0.styleValue) }
                ),
                options: FontFamilyOption.allCases
            ) { option in
                Text(option.displayName)
                    .controlValueStyle()
                    .tag(option)
            }

            InspectorStepperFieldRow(
                label: "Font Size",
                value: Binding(
                    get: { Double(currentComponent.style.fontSize) },
                    set: { document.updateFontSize(for: component.id, fontSize: CGFloat($0)) }
                ),
                range: 8...48,
                step: 1
            )

            InspectorPickerRow(
                label: "Font Weight",
                selection: Binding(
                    get: { FontWeightOption(styleValue: currentComponent.style.fontWeight) },
                    set: { document.updateFontWeight(for: component.id, weight: $0.styleValue) }
                ),
                options: FontWeightOption.allCases
            ) { option in
                Text(option.displayName)
                    .controlValueStyle()
                    .tag(option)
            }

            InspectorStepperFieldRow(
                label: "Line Spacing",
                value: Binding(
                    get: { Double(currentComponent.style.lineSpacing) },
                    set: { document.updateLineSpacing(for: component.id, spacing: CGFloat($0)) }
                ),
                range: 0.8...2.5,
                step: 0.05
            )

            InspectorStepperFieldRow(
                label: "Letter Spacing",
                value: Binding(
                    get: { Double(currentComponent.style.letterSpacing) },
                    set: { document.updateLetterSpacing(for: component.id, spacing: CGFloat($0)) }
                ),
                range: -2...10,
                step: 0.1
            )

            InspectorStepperFieldRow(
                label: "Line Limit",
                value: Binding(
                    get: { Double(isHorizontal ? columnConfig.lineLimit : rowConfig.lineLimit) },
                    set: { value in
                        if isHorizontal {
                            document.updateColumnLineLimit(for: component.id, columnIndex: selectedIndex, lineLimit: Int(value))
                        } else {
                            document.updateRowLineLimit(for: component.id, rowIndex: selectedIndex, lineLimit: Int(value))
                        }
                    }
                ),
                range: 1...5,
                step: 1
            )
        }
    }

    private func tableColumnControls(for component: InvoiceComponent) -> some View {
        ensureTableColumnData(for: component)
        let currentComponent = document.component(component.id) ?? component
        let generator = DocumentGridDataGenerator(component: currentComponent, templateDataService: templateDataService, clientId: nil, invoiceId: nil)
        let sampleData = generator.generateSampleData()
        let columnCount = sampleData.first?.count ?? 4
        let selectedIndex = min(tableColumnsSelectedTab, max(0, columnCount - 1))
        let columnConfig = currentComponent.style.columnConfiguration(for: selectedIndex)

        return VStack(alignment: .leading, spacing: 6) {
            if columnCount > 1 {
                InspectorLabeledRow(label: "Column") {
                    Picker(
                        "",
                        selection: $tableColumnsSelectedTab
                    ) {
                        ForEach(Array(0..<columnCount), id: \.self) { index in
                            Text("Column \(index + 1)")
                                .controlValueStyle()
                                .tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            InspectorPickerRow(
                label: "Width Mode",
                selection: Binding(
                    get: { columnConfig.isAutoSized ? ColumnWidthMode.autoSize : (columnConfig.isFlexible ? ColumnWidthMode.flexible : ColumnWidthMode.fixed) },
                    set: { newMode in
                        switch newMode {
                        case .flexible:
                            document.updateColumnIsFlexible(for: component.id, columnIndex: selectedIndex, isFlexible: true)
                        case .autoSize:
                            document.updateColumnAutoSizing(for: component.id, columnIndex: selectedIndex, isAutoSized: true)
                        case .fixed:
                            document.updateColumnIsFlexible(for: component.id, columnIndex: selectedIndex, isFlexible: false)
                            document.updateColumnAutoSizing(for: component.id, columnIndex: selectedIndex, isAutoSized: false)
                        }
                    }
                ),
                options: ColumnWidthMode.allCases
            ) { mode in
                Text(mode.rawValue)
                    .controlValueStyle()
                    .tag(mode)
            }

            InspectorStepperFieldRow(
                label: "Fixed Width",
                value: Binding(
                    get: { Double(columnConfig.width) },
                    set: { document.updateColumnWidth(for: component.id, columnIndex: selectedIndex, width: CGFloat($0)) }
                ),
                range: 50...300,
                step: 10
            )

            InspectorAlignmentGridRow(
                label: "Data Cell Alignment",
                horizontalAlignment: Binding(
                    get: { currentComponent.style.columnConfiguration(for: selectedIndex).alignment },
                    set: { document.updateColumnAlignment(for: component.id, columnIndex: selectedIndex, alignment: $0) }
                ),
                verticalAlignment: Binding(
                    get: { currentComponent.style.columnConfiguration(for: selectedIndex).verticalAlignment },
                    set: { document.updateColumnVerticalAlignment(for: component.id, columnIndex: selectedIndex, verticalAlignment: $0) }
                )
            )

            InspectorAlignmentGridRow(
                label: "Header Alignment",
                horizontalAlignment: Binding(
                    get: { currentComponent.style.columnConfiguration(for: selectedIndex).headerAlignment },
                    set: { document.updateColumnHeaderAlignment(for: component.id, columnIndex: selectedIndex, alignment: $0) }
                ),
                verticalAlignment: Binding(
                    get: { currentComponent.style.columnConfiguration(for: selectedIndex).headerVerticalAlignment },
                    set: { document.updateColumnHeaderVerticalAlignment(for: component.id, columnIndex: selectedIndex, verticalAlignment: $0) }
                )
            )
        }
    }

    // MARK: - Shape Content
    @ViewBuilder
    private func shapeSection(for component: InvoiceComponent) -> some View {
        switch component.type {
        case .lineShape:
            controlGroupBox(title: "Line") {
                InspectorStepperFieldRow(
                    label: "Thickness",
                    value: Binding(
                        get: { Double(component.style.lineThickness) },
                        set: { document.updateLineThickness(for: component.id, thickness: CGFloat($0)) }
                    ),
                    range: 0.5...10,
                    step: 0.5
                )

                InspectorPickerRow(
                    label: "Line Style",
                    selection: Binding(
                        get: { component.style.lineStyle },
                        set: { document.updateLineStyle(for: component.id, style: $0) }
                    ),
                    options: LineStyle.allCases
                ) { style in
                    Text(style.rawValue.capitalized)
                        .controlValueStyle()
                        .tag(style)
                }
            }
        case .triangleShape:
            controlGroupBox(title: "Triangle") {
                InspectorPickerRow(
                    label: "Direction",
                    selection: Binding(
                        get: { component.style.triangleDirection },
                        set: { document.updateTriangleDirection(for: component.id, direction: $0) }
                    ),
                    options: TriangleDirection.allCases
                ) { direction in
                    Text(direction.rawValue.capitalized)
                        .controlValueStyle()
                        .tag(direction)
                }

                InspectorButtonRow(
                    label: "Reset Direction",
                    title: "Reset"
                ) {
                    document.updateTriangleDirection(for: component.id, direction: .up)
                }
            }
        case .starShape:
            controlGroupBox(title: "Star") {
                InspectorStepperFieldRow(
                    label: "Points",
                    value: Binding(
                        get: { Double(component.style.starPoints) },
                        set: { document.updateStarPoints(for: component.id, points: Int($0)) }
                    ),
                    range: 3...12,
                    step: 1
                )

                InspectorStepperFieldRow(
                    label: "Smoothness",
                    value: Binding(
                        get: { Double(component.style.starSmoothness) },
                        set: { document.updateStarSmoothness(for: component.id, smoothness: CGFloat($0)) }
                    ),
                    range: 0.1...1.0,
                    step: 0.05
                )

                InspectorStepperFieldRow(
                    label: "Inner Ratio",
                    value: Binding(
                        get: { Double(component.style.starInnerRatio) },
                        set: { document.updateStarInnerRatio(for: component.id, ratio: CGFloat($0)) }
                    ),
                    range: 0.1...0.9,
                    step: 0.05
                )
            }
        default:
            EmptyView()
        }
    }
    // MARK: - Header & Empty State
    @ViewBuilder
    private func header(for component: InvoiceComponent) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                        .shadow(color: Color.accentColor.opacity(0.1), radius: 2, x: 0, y: 1)

                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Properties")
                    .font(InspectorFontLevel.l1MainHeader.font)
                    .foregroundColor(InspectorFontLevel.l1MainHeader.foregroundColor)
                    .tracking(InspectorFontLevel.l1MainHeader.letterSpacing)
                    .opacity(InspectorFontLevel.l1MainHeader.textOpacity)
                    .baselineOffset(InspectorFontLevel.l1MainHeader.baselineOffset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(InspectorFontLevel.l1MainHeader.headerPadding)
            }

            TagView(text: tagTitle(for: component))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func tagTitle(for component: InvoiceComponent) -> String {
        if component.type.supportsTypography { return "Text" }
        if component.type.isSection { return "Section" }
        if component.type.isImageComponent { return "Image" }
        if component.type.isShape { return "Shape" }
        return "Component"
    }

    private var emptyState: some View {
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

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 28, weight: .medium))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 48)
        .padding(12)
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 12))
        .glassEffectTransition(.materialize)
    }
}

private struct InspectorPropertySection: View {
    private let sectionCornerRadius: CGFloat = 8
    let title: String
    let binding: Binding<Bool>
    let level: InspectorFontLevel
    let alwaysExpanded: Bool
    let expandedRadius: CGFloat
    let collapsedRadius: CGFloat
    let idPrefix: String
    let contentView: AnyView

    private var appearance: HierarchySectionCard<AnyView>.Appearance {
        level == .l2SectionHeader ? .glass : .plain
    }
    init(
        title: String,
        binding: Binding<Bool>,
        level: InspectorFontLevel,
        alwaysExpanded: Bool,
        expandedRadius: CGFloat,
        collapsedRadius: CGFloat,
        idPrefix: String,
        @ViewBuilder content: () -> some View
    ) {
        self.title = title
        self.binding = binding
        self.level = level
        self.alwaysExpanded = alwaysExpanded
        self.expandedRadius = sectionCornerRadius
        self.collapsedRadius = sectionCornerRadius
        self.idPrefix = idPrefix
        self.contentView = AnyView(
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            //.padding(.vertical, 6)
            //.padding(.horizontal, 6)
        )
    }

    var body: some View {
        HierarchySectionCard(
            title: title,
            isExpanded: binding,
            appearance: appearance,
            childSpacing: 10,
            namespace: nil,
            glassIDPrefix: idPrefix,
            glassUnionID: nil,
            isCollapsible: !alwaysExpanded,
            expandedCornerRadius: expandedRadius,
            collapsedCornerRadius: collapsedRadius,
            onExpand: nil,
            onCollapse: nil,
            headerStyle: headerStyle(for: level),
            headerGlassStyle: headerGlassStyle(for: level)
        ) {
            contentView
        }
    }

    private func headerStyle(for level: InspectorFontLevel) -> HierarchyHeaderStyle {
        return HierarchyHeaderStyle(
            font: level.font,
            color: level.foregroundColor,
            opacity: level.textOpacity,
            letterSpacing: level.letterSpacing,
            baselineOffset: level.baselineOffset,
            padding: level.headerPadding
        )
    }

    private func headerGlassStyle(for level: InspectorFontLevel) -> Glass {
        let tint: NSColor
        switch level {
        case .l2SectionHeader:
            tint = NSColor.systemFill
        case .l3Subsection:
            tint = NSColor.secondarySystemFill
        case .l4SubSubsection:
            tint = NSColor.tertiarySystemFill
        default:
            tint = NSColor.quaternarySystemFill
        }
        return .regular.interactive().tint(Color(tint))
    }
}

extension ModernInspectorView.InspectorSection {
    static let topLevelGroup: Set<Self> = [.text, .appearance, .table, .image, .shape]

    var collapseGroups: [Set<Self>] {
        switch self {
        case .text, .appearance, .table, .image, .shape:
            return [Self.topLevelGroup]
        }
    }

    var descendants: Set<Self> { [] }
}

// MARK: - Tag View
private struct TagView: View {
    let text: String
    @State private var isHovered = false

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded))
            .fontWeight(.semibold)
            .foregroundColor(Color(NSColor.labelColor))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        isHovered
                            ? LinearGradient(
                                colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.accentColor.opacity(0.14), Color.accentColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(isHovered ? 0.28 : 0.2),
                                        Color.accentColor.opacity(isHovered ? 0.18 : 0.14)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
            )
            .shadow(
                color: Color.accentColor.opacity(isHovered ? 0.12 : 0),
                radius: isHovered ? 5 : 0,
                x: 0,
                y: isHovered ? 2.5 : 0
            )
            .onHover { isHovered = $0 }
    }
}

private struct InspectorSectionDescriptor: Identifiable {
    let identifier: String
    let title: String
    let section: ModernInspectorView.InspectorSection
    let alwaysExpanded: Bool
    let isVisible: Bool
    let buildContent: () -> AnyView

    var id: String { identifier }

    func content() -> AnyView {
        buildContent()
    }
}

private enum InspectorCategory {
    case text
    case container
    case table
    case image
    case shape
}

private struct InspectorCapabilities {
    let showsTextSection: Bool
    let showsContentControls: Bool
    let nestsContentControls: Bool
    let showsTypographySection: Bool
    let showsAppearanceSection: Bool
    let showsTableSection: Bool
    let showsImageSection: Bool
    let showsShapeSection: Bool

    init(component: InvoiceComponent) {
        let type = component.type
        let isSimpleTextComponent = type == .textBox || type == .notes
        let supportsTypography = type.supportsTypography

        showsContentControls = isSimpleTextComponent
        let excludesTextCategory = type.usesTableProperties || type.isImageComponent || type.isShape || type.isSection
        showsTextSection = (showsContentControls || supportsTypography) && !excludesTextCategory
        nestsContentControls = isSimpleTextComponent && supportsTypography
        showsTypographySection = supportsTypography
        let supportsAppearance = type.supportsBackgroundFill || type.supportsBorderControls || type.supportsShadow
        showsAppearanceSection = supportsAppearance && !type.usesTableProperties
        showsTableSection = type.usesTableProperties
        showsImageSection = type.isImageComponent
        showsShapeSection = type.isShape
    }
}

private extension View {
    func inspectorControlGroupStyle(cornerRadius: CGFloat = 8) -> some View {
        self
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
    }
}

private func inspectorCategory(for component: InvoiceComponent) -> InspectorCategory {
    let type = component.type
    if type.usesTableProperties { return .table }
    if type.isImageComponent { return .image }
    if type.isShape { return .shape }
    if type.isSection { return .container }
    return .text
}
