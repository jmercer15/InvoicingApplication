import SwiftUI
import AppKit
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
    @State private var typographyTabSelection: [UUID: Int] = [:]
    @State private var columnTabSelection: [UUID: Int] = [:]

    private var selectedComponent: InvoiceComponent? {
        document.component(document.selectedComponentID)
    }

    private var selectedSplitContext: SectionSplitLeafContext? {
        document.leafContext(for: document.selectedSplitSelection)
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
                expandedSections = Set([section])
            } else {
                expandedSections.remove(section)
            }
        }
    }

    enum InspectorSection: Hashable {
        case text
        case appearance
        case image
        case shape
        case tableLayoutStructure
        case tableFill
        case tableBorders
        case tableShadow
        case tableTypography
        case tableColumns
    }
    private func ensureTableTypographyData(for component: InvoiceComponent) {
        let tableData = tablePreviewData(for: component)

        if tableData.isHorizontal {
            if component.style.columnConfigurations.isEmpty {
                document.initializeColumnConfigurations(for: component.id, columnCount: tableData.columnCount)
            }
        } else if component.style.rowConfigurations.isEmpty {
            document.initializeRowConfigurations(for: component.id, rowCount: tableData.rowCount)
        }
    }

    private func ensureTableColumnData(for component: InvoiceComponent) {
        let tableData = tablePreviewData(for: component)
        if component.style.columnConfigurations.isEmpty {
            document.initializeColumnConfigurations(for: component.id, columnCount: tableData.columnCount)
        }
    }

    private func tablePreviewData(for component: InvoiceComponent) -> (component: InvoiceComponent, rowCount: Int, columnCount: Int, isHorizontal: Bool) {
        let currentComponent = document.component(component.id) ?? component
        let generator = DocumentGridDataGenerator(component: currentComponent, templateDataService: templateDataService, clientId: nil, invoiceId: nil)
        let sampleData = generator.generateSampleData()
        let columnCount = sampleData.first?.count ?? 4
        let isHorizontal = currentComponent.style.tableDirection == .horizontal
        return (currentComponent, sampleData.count, columnCount, isHorizontal)
    }
    var body: some View {
        Group {
            if let splitContext = selectedSplitContext {
                SplitInspectorView(context: splitContext)
            } else if let component = selectedComponent {
                inspectorScrollContent(for: component)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .glassEffect(
            .regular,
            in: .rect(cornerRadius: TemplateEditorPanelStyle.cornerRadius)
        )
        .padding(TemplateEditorPanelStyle.outerPadding)
    }

    @ViewBuilder
    private func inspectorScrollContent(for component: InvoiceComponent) -> some View {
        let capabilities = InspectorCapabilities(component: component)
        let descriptors = sectionDescriptors(for: component, capabilities: capabilities)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: component)

                Divider()
                    .background(Color(NSColor.separatorColor).opacity(0.3))

                LazyVStack(alignment: .leading, spacing: 16) {
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
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Top-Level Sections
    @ViewBuilder
    private func inspectorSection(
        title: String,
        section: InspectorSection,
        alwaysExpanded: Bool = false,
        isVisible: Bool,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        if isVisible {
            let sectionBinding = alwaysExpanded ? .constant(true) : binding(for: section)
            let level: InspectorFontLevel = .l2SectionHeader
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
        var descriptors: [InspectorSectionDescriptor] = []

        descriptors.append(
            InspectorSectionDescriptor(
                section: .text,
                title: "Text",
                alwaysExpanded: false,
                isVisible: category == .text && (capabilities.showsContentControls || capabilities.showsTypographySection)
            ) {
                AnyView(textSectionContent(for: component, capabilities: capabilities))
            }
        )

        descriptors.append(
            InspectorSectionDescriptor(
                section: .appearance,
                title: "Appearance",
                alwaysExpanded: false,
                isVisible: capabilities.showsAppearanceSection
            ) {
                AnyView(appearanceSection(for: component))
            }
        )

        if category == .table && capabilities.showsTableSection {
            descriptors.append(contentsOf: tableSectionDescriptors(for: component))
        }

        descriptors.append(
            InspectorSectionDescriptor(
                section: .image,
                title: "Image",
                alwaysExpanded: true,
                isVisible: category == .image && capabilities.showsImageSection
            ) {
                AnyView(imageContentControls(for: component))
            }
        )

        descriptors.append(
            InspectorSectionDescriptor(
                section: .shape,
                title: "Shape",
                alwaysExpanded: true,
                isVisible: category == .shape && capabilities.showsShapeSection
            ) {
                AnyView(shapeSection(for: component))
            }
        )

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
                text: styleBinding(for: component, \.placeholderText) { componentID, text in
                    document.updatePlaceholderText(for: componentID, text: text)
                }
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
                selection: styleBinding(for: component, \.imageContentMode) { componentID, mode in
                    document.updateImageContentMode(for: componentID, mode: mode)
                },
                options: ImageContentMode.allCases
            ) { mode in
                Text(mode.rawValue.capitalized)
                    .controlValueStyle()
                    .tag(mode)
            }

            InspectorStepperFieldRow(
                label: "Opacity",
                value: numericStyleBinding(for: component, \.imageOpacity) { componentID, opacity in
                    document.updateImageOpacity(for: componentID, opacity: CGFloat(opacity))
                },
                range: 0...1,
                step: 0.1
            )
        }
    }

    @ViewBuilder
    private func controlGroupBox<Content: View>(
        title: String? = nil,
        icon: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .glassEffect(
            .regular.tint(Color(NSColor.windowBackgroundColor)),
            in: .rect(cornerRadius: 14)
        )
        .glassEffectTransition(.materialize)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Text Typography Content
    @ViewBuilder
    private func textTypographyControls(for component: InvoiceComponent) -> some View {
        controlGroupBox(title: "Font", icon: "textformat") {
            InspectorTextFieldRow(
                label: "Font Family",
                text: styleBinding(for: component, \.fontFamily) { componentID, family in
                    document.updateFontFamily(for: componentID, family: family)
                }
            )

            InspectorStepperFieldRow(
                label: "Font Size",
                value: numericStyleBinding(for: component, \.fontSize) { componentID, size in
                    document.updateFontSize(for: componentID, fontSize: CGFloat(size))
                },
                range: 6...72,
                step: 1
            )

            InspectorTextFieldRow(
                label: "Font Weight",
                text: styleBinding(for: component, \.fontWeight) { componentID, weight in
                    document.updateFontWeight(for: componentID, weight: weight)
                }
            )
        }

        controlGroupBox(title: "Spacing", icon: "line.3.horizontal.decrease") {
            InspectorStepperFieldRow(
                label: "Line Spacing",
                value: numericStyleBinding(for: component, \.lineSpacing) { componentID, spacing in
                    document.updateLineSpacing(for: componentID, spacing: CGFloat(spacing))
                },
                range: 0.5...3.0,
                step: 0.1
            )

            InspectorStepperFieldRow(
                label: "Letter Spacing",
                value: numericStyleBinding(for: component, \.letterSpacing) { componentID, spacing in
                    document.updateLetterSpacing(for: componentID, spacing: CGFloat(spacing))
                },
                range: -2.0...5.0,
                step: 0.1
            )
        }

        controlGroupBox(title: "Paragraph & Case", icon: "text.alignleft") {
            InspectorPickerRow(
                label: "Text Alignment",
                selection: styleBinding(for: component, \.textAlignment) { componentID, alignment in
                    document.updateTextAlignment(for: componentID, alignment: alignment)
                },
                options: TextAlignment.allCases
            ) { alignment in
                Text(alignment.rawValue.capitalized)
                    .controlValueStyle()
                    .tag(alignment)
            }

            InspectorPickerRow(
                label: "Text Transform",
                selection: styleBinding(for: component, \.textTransform) { componentID, transform in
                    document.updateTextTransform(for: componentID, transform: transform)
                },
                options: TextTransform.allCases
            ) { transform in
                Text(transform.rawValue.capitalized)
                    .controlValueStyle()
                    .tag(transform)
            }
        }

        controlGroupBox(title: "Decoration", icon: "sparkles") {
            InspectorToggleRow(
                label: "Underline",
                isOn: styleBinding(for: component, \.textUnderline) { componentID, underline in
                    document.updateTextUnderline(for: componentID, underline: underline)
                }
            )

            InspectorToggleRow(
                label: "Strikethrough",
                isOn: styleBinding(for: component, \.textStrikethrough) { componentID, strikethrough in
                    document.updateTextStrikethrough(for: componentID, strikethrough: strikethrough)
                }
            )
        }

        controlGroupBox(title: "Color & Opacity", icon: "drop.fill") {
            InspectorColorPickerRow(
                label: "Text Color",
                color: styleBinding(for: component, \.textColorSwiftUI) { componentID, color in
                    document.updateTextColor(for: componentID, color: color.toHex())
                }
            )

            InspectorStepperFieldRow(
                label: "Text Opacity",
                value: numericStyleBinding(for: component, \.textOpacity) { componentID, opacity in
                    document.updateTextOpacity(for: componentID, opacity: CGFloat(opacity))
                },
                range: 0...1,
                step: 0.1
            )
        }
    }

    private func orderedSections(for category: InspectorCategory) -> [InspectorSection] {
        switch category {
        case .text:
            return [.text, .appearance]
        case .container:
            return [.text, .appearance]
        case .table:
            return [
                .tableLayoutStructure,
                .tableFill,
                .tableBorders,
                .tableShadow,
                .tableTypography,
                .tableColumns
            ]
        case .image:
            return [.image, .appearance]
        case .shape:
            return [.shape, .appearance]
        }
    }
    // MARK: - Appearance Content
    @ViewBuilder
    private func appearanceSection(for component: InvoiceComponent) -> some View {
        if component.type.supportsBackgroundFill {
            controlGroupBox(title: "Background", icon: "square.fill") {
                InspectorColorPickerRow(
                    label: "Background",
                    color: styleBinding(for: component, \.backgroundColorSwiftUI) { componentID, color in
                        document.updateBackgroundColor(for: componentID, color: color.toHex())
                    }
                )

                InspectorStepperFieldRow(
                    label: "Opacity",
                    value: numericStyleBinding(for: component, \.backgroundOpacity) { componentID, opacity in
                        document.updateBackgroundOpacity(for: componentID, opacity: CGFloat(opacity))
                    },
                    range: 0...1,
                    step: 0.1
                )
            }
        }

        if component.type.supportsBorderControls {
            controlGroupBox(title: "Border", icon: "square.dashed") {
                InspectorColorPickerRow(
                    label: "Border Color",
                    color: styleBinding(for: component, \.borderColorSwiftUI) { componentID, color in
                        document.updateBorderColor(for: componentID, color: color.toHex())
                    }
                )

                InspectorStepperFieldRow(
                    label: "Border Width",
                    value: numericStyleBinding(for: component, \.borderWidth) { componentID, width in
                        document.updateBorderWidth(for: componentID, width: CGFloat(width))
                    },
                    range: 0...10,
                    step: 0.5
                )

                InspectorStepperFieldRow(
                    label: "Corner Radius",
                    value: numericStyleBinding(for: component, \.cornerRadius) { componentID, radius in
                        document.updateCornerRadius(for: componentID, radius: CGFloat(radius))
                    },
                    range: 0...25,
                    step: 0.5
                )
            }
        }

        if component.type.supportsShadow {
            shadowControls(for: component)
        }
    }

    @ViewBuilder
    private func shadowControls(for component: InvoiceComponent) -> some View {
        controlGroupBox(title: "Shadow", icon: "drop.triangle") {
            InspectorToggleRow(
                label: "Shadow",
                isOn: styleBinding(for: component, \.shadowEnabled) { componentID, enabled in
                    document.updateShadowEnabled(for: componentID, enabled: enabled)
                }
            )
        }

        if component.style.shadowEnabled {
            controlGroupBox(title: "Color & Opacity", icon: "drop.fill") {
                InspectorColorPickerRow(
                    label: "Shadow Color",
                    color: styleBinding(for: component, \.shadowColorSwiftUI) { componentID, color in
                        document.updateShadowColor(for: componentID, color: color.toHex())
                    }
                )

                InspectorStepperFieldRow(
                    label: "Shadow Opacity",
                    value: numericStyleBinding(for: component, \.shadowOpacity) { componentID, opacity in
                        document.updateShadowOpacity(for: componentID, opacity: CGFloat(opacity))
                    },
                    range: 0...1,
                    step: 0.1
                )
            }

            controlGroupBox(title: "Offset & Blur", icon: "wind") {
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
                    value: numericStyleBinding(for: component, \.shadowRadius) { componentID, radius in
                        document.updateShadowRadius(for: componentID, radius: CGFloat(radius))
                    },
                    range: 0...20,
                    step: 0.5
                )
            }
        }
    }
    // MARK: - Table Content
    private func tableSectionDescriptors(for component: InvoiceComponent) -> [InspectorSectionDescriptor] {
        let sections: [(InspectorSection, String, () -> AnyView)] = [
            (.tableLayoutStructure, "Layout & Structure", { AnyView(tableLayoutStructureContent(for: component)) }),
            (.tableFill, "Fill", { AnyView(tableFillContent(for: component)) }),
            (.tableBorders, "Borders", { AnyView(tableBordersContent(for: component)) }),
            (.tableShadow, "Shadow", { AnyView(shadowControls(for: component)) }),
            (.tableTypography, "Typography", { AnyView(tableTypographyContent(for: component)) }),
            (.tableColumns, "Columns", { AnyView(tableColumnsContent(for: component)) })
        ]

        return sections.map { section, title, builder in
            InspectorSectionDescriptor(
                section: section,
                title: title,
                alwaysExpanded: false,
                isVisible: true,
                buildContent: builder
            )
        }
    }

    @ViewBuilder
    private func tableLayoutStructureContent(for component: InvoiceComponent) -> some View {
        controlGroupBox {
            InspectorPickerRow(
                label: "Direction",
                selection: styleBinding(for: component, \.tableDirection) { componentID, direction in
                    document.updateTableDirection(for: componentID, direction: direction)
                },
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

            Divider()
                .padding(.vertical, 4)

            InspectorToggleRow(
                label: "Show Header",
                isOn: styleBinding(for: component, \.showTableHeader) { componentID, show in
                    document.updateShowTableHeader(for: componentID, show: show)
                }
            )

            InspectorColorPickerRow(
                label: "Text Color",
                color: styleBinding(for: component, \.tableTextColorSwiftUI) { componentID, color in
                    document.updateTableTextColor(for: componentID, color: color.toHex())
                }
            )

            if component.style.showTableHeader {
                InspectorColorPickerRow(
                    label: "Header Text",
                    color: styleBinding(for: component, \.tableHeaderTextColorSwiftUI) { componentID, color in
                        document.updateTableHeaderTextColor(for: componentID, color: color.toHex())
                    }
                )
            }
        }

        controlGroupBox(title: "Spacing", icon: "line.3.horizontal.decrease") {
            InspectorStepperFieldRow(
                label: "Cell Padding",
                value: numericStyleBinding(for: component, \.tableCellPadding) { componentID, padding in
                    document.updateTableCellPadding(for: componentID, padding: CGFloat(padding))
                },
                range: 0...20,
                step: 1
            )

            InspectorStepperFieldRow(
                label: "Header Padding",
                value: numericStyleBinding(for: component, \.tableHeaderPadding) { componentID, padding in
                    document.updateTableHeaderPadding(for: componentID, padding: CGFloat(padding))
                },
                range: 0...20,
                step: 1
            )
        }
    }


    @ViewBuilder
    private func tableFillContent(for component: InvoiceComponent) -> some View {
        controlGroupBox {
            InspectorColorPickerRow(
                label: "Header Fill",
                color: styleBinding(for: component, \.tableHeaderColorSwiftUI) { componentID, color in
                    document.updateTableHeaderColor(for: componentID, color: color.toHex())
                }
            )

            InspectorColorPickerRow(
                label: "Row Fill",
                color: styleBinding(for: component, \.tableRowColorSwiftUI) { componentID, color in
                    document.updateTableRowColor(for: componentID, color: color.toHex())
                }
            )

            Divider()
                .padding(.vertical, 4)

            InspectorToggleRow(
                label: "Alternating Rows",
                isOn: styleBinding(for: component, \.useAlternatingRows) { componentID, use in
                    document.updateUseAlternatingRows(for: componentID, use: use)
                }
            )

            if component.style.useAlternatingRows {
                InspectorColorPickerRow(
                    label: "Alt Row Fill",
                    color: styleBinding(for: component, \.tableRowAltColorSwiftUI) { componentID, color in
                        document.updateTableRowAltColor(for: componentID, color: color.toHex())
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func tableBordersContent(for component: InvoiceComponent) -> some View {
        controlGroupBox {
            InspectorToggleRow(
                label: "Show Borders",
                isOn: styleBinding(for: component, \.showTableBorders) { componentID, show in
                    document.updateShowTableBorders(for: componentID, show: show)
                }
            )
        }

        if component.style.showTableBorders {
            controlGroupBox(title: "Style", icon: "paintpalette") {
                InspectorColorPickerRow(
                    label: "Border Color",
                    color: styleBinding(for: component, \.tableBorderColorSwiftUI) { componentID, color in
                        document.updateTableBorderColor(for: componentID, color: color.toHex())
                    }
                )

                InspectorStepperFieldRow(
                    label: "Border Width",
                    value: numericStyleBinding(for: component, \.tableBorderWidth) { componentID, width in
                        document.updateTableBorderWidth(for: componentID, width: CGFloat(width))
                    },
                    range: 0...5,
                    step: 0.5
                )
            }

            controlGroupBox(title: "Visibility", icon: "eye") {
                InspectorToggleRow(
                    label: "Header Borders",
                    isOn: styleBinding(for: component, \.showHeaderBorder) { componentID, show in
                        document.updateShowHeaderBorder(for: componentID, show: show)
                    }
                )

                InspectorToggleRow(
                    label: "Row Borders",
                    isOn: styleBinding(for: component, \.showRowBorders) { componentID, show in
                        document.updateShowRowBorders(for: componentID, show: show)
                    }
                )

                InspectorToggleRow(
                    label: "Cell Borders",
                    isOn: styleBinding(for: component, \.showCellBorders) { componentID, show in
                        document.updateShowCellBorders(for: componentID, show: show)
                    }
                )
            }

            if component.style.showHeaderBorder || component.style.showRowBorders {
                controlGroupBox(title: "Dividers", icon: "rectangle.split.2x1") {
                    if component.style.showHeaderBorder {
                        InspectorColorPickerRow(
                            label: "Header Divider",
                            color: styleBinding(for: component, \.tableHeaderBorderColorSwiftUI) { componentID, color in
                                document.updateTableHeaderBorderColor(for: componentID, color: color.toHex())
                            }
                        )

                        InspectorStepperFieldRow(
                            label: "Header Width",
                            value: numericStyleBinding(for: component, \.tableHeaderBorderWidth) { componentID, width in
                                document.updateTableHeaderBorderWidth(for: componentID, width: CGFloat(width))
                            },
                            range: 0...5,
                            step: 0.25
                        )
                    }

                    if component.style.showRowBorders {
                        InspectorColorPickerRow(
                            label: "Row Divider",
                            color: styleBinding(for: component, \.tableRowBorderColorSwiftUI) { componentID, color in
                                document.updateTableRowBorderColor(for: componentID, color: color.toHex())
                            }
                        )

                        InspectorStepperFieldRow(
                            label: "Row Width",
                            value: numericStyleBinding(for: component, \.tableRowBorderWidth) { componentID, width in
                                document.updateTableRowBorderWidth(for: componentID, width: CGFloat(width))
                            },
                            range: 0...5,
                            step: 0.25
                        )
                    }
                }
            }
        }
    }


    @ViewBuilder
    private func tableTypographyContent(for component: InvoiceComponent) -> some View {
        let _ = ensureTableTypographyData(for: component)
        let tableData = tablePreviewData(for: component)
        let currentComponent = tableData.component
        let tabCount = tableData.isHorizontal ? tableData.columnCount : tableData.rowCount
        let selectedIndex = min(typographyTabSelection[component.id] ?? 0, max(0, tabCount - 1))
        let isHorizontal = tableData.isHorizontal
        let columnConfig = currentComponent.style.columnConfiguration(for: selectedIndex)
        let rowConfig = currentComponent.style.rowConfiguration(for: selectedIndex)

        if tabCount > 1 {
            controlGroupBox {
                InspectorLabeledRow(
                    label: currentComponent.style.tableDirection == .horizontal ? "Column" : "Row"
                ) {
                    Picker(
                        "",
                        selection: Binding(
                            get: { typographyTabSelection[component.id] ?? 0 },
                            set: { typographyTabSelection[component.id] = $0 }
                        )
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
        }

        controlGroupBox(title: "Font", icon: "textformat") {
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
        }

        controlGroupBox(title: "Spacing", icon: "line.3.horizontal.decrease") {
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
        }

        controlGroupBox(title: "Text Limits", icon: "textformat.abc") {
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

    @ViewBuilder
    private func tableColumnsContent(for component: InvoiceComponent) -> some View {
        let _ = ensureTableColumnData(for: component)
        let tableData = tablePreviewData(for: component)
        let currentComponent = tableData.component
        let columnCount = tableData.columnCount
        let selectedIndex = min(columnTabSelection[component.id] ?? 0, max(0, columnCount - 1))
        let columnConfig = currentComponent.style.columnConfiguration(for: selectedIndex)

        if columnCount > 1 {
            controlGroupBox {
                InspectorLabeledRow(label: "Column") {
                    Picker(
                        "",
                        selection: Binding(
                            get: { columnTabSelection[component.id] ?? 0 },
                            set: { columnTabSelection[component.id] = $0 }
                        )
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
        }

        controlGroupBox(title: "Width", icon: "arrow.left.and.right") {
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

            if !columnConfig.isAutoSized && !columnConfig.isFlexible {
                InspectorStepperFieldRow(
                    label: "Fixed Width",
                    value: Binding(
                        get: { Double(columnConfig.width) },
                        set: { document.updateColumnWidth(for: component.id, columnIndex: selectedIndex, width: CGFloat($0)) }
                    ),
                    range: 50...300,
                    step: 10
                )
            }
        }

        controlGroupBox(title: "Alignment", icon: "square.grid.3x3.fill") {
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
            controlGroupBox(title: "Line", icon: "scribble") {
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
            controlGroupBox(title: "Triangle", icon: "triangle") {
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
            controlGroupBox(title: "Star", icon: "star") {
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Properties")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color.primaryText)

            Text(component.type.rawValue)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func headerStatistics(for component: InvoiceComponent) -> some View {
        let width = Int(component.size.width.rounded())
        let height = Int(component.size.height.rounded())
        let positionX = Int(component.position.x.rounded())
        let positionY = Int(component.position.y.rounded())

        HStack(spacing: 6) {
            InspectorHeaderStat(
                icon: "square.grid.2x2",
                label: "Type",
                value: component.type.rawValue
            )

            InspectorHeaderStat(
                icon: "arrow.up.left.and.arrow.down.right",
                label: "Size",
                value: "\(width) × \(height)"
            )

            InspectorHeaderStat(
                icon: "scope",
                label: "Pos",
                value: "\(positionX), \(positionY)"
            )

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func componentCommandBar(for component: InvoiceComponent) -> some View {
        let canMoveUp = document.canMoveLayerUp(component.id)
        let canMoveDown = document.canMoveLayerDown(component.id)

        HStack(spacing: 6) {
            InspectorActionButton(
                icon: component.isLocked ? "lock.fill" : "lock.open",
                title: component.isLocked ? "Unlock" : "Lock",
                isActive: component.isLocked,
                help: component.isLocked ? "Unlock component" : "Lock component"
            ) {
                document.toggleLock(for: component.id)
            }

            InspectorActionButton(
                icon: component.isVisible ? "eye.fill" : "eye.slash.fill",
                title: component.isVisible ? "Hide" : "Show",
                isActive: !component.isVisible,
                help: component.isVisible ? "Hide component" : "Show component"
            ) {
                document.toggleVisibility(for: component.id)
            }

            InspectorActionButton(
                icon: "square.on.square",
                title: "Duplicate",
                isActive: false,
                style: .accent,
                help: "Duplicate component"
            ) {
                editorViewModel.duplicateComponent(component)
            }

            InspectorActionButton(
                icon: "arrow.up.to.line",
                title: "Forward",
                isActive: false,
                isDisabled: !canMoveUp,
                help: "Bring forward"
            ) {
                document.moveLayerUp(component.id)
            }

            InspectorActionButton(
                icon: "arrow.down.to.line",
                title: "Backward",
                isActive: false,
                isDisabled: !canMoveDown,
                help: "Send backward"
            ) {
                document.moveLayerDown(component.id)
            }

            InspectorActionButton(
                icon: "trash",
                title: "Delete",
                isActive: false,
                style: .destructive,
                help: "Delete component"
            ) {
                editorViewModel.deleteComponent(component)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(NSColor.controlBackgroundColor).opacity(0.7),
                            Color(NSColor.windowBackgroundColor).opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.4)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .padding(.top, 2)
    }

    private func tagTitle(for component: InvoiceComponent) -> String {
        if component.type.usesTableProperties { return "Table" }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 32)
        .padding(.vertical, 48)
    }
}

// MARK: - Tag & Header Chip Views
private struct InspectorHeaderStat: View {
    let icon: String?
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
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
                .fill(Color.secondaryFill.opacity(0.4))
        )
    }
}

private enum InspectorActionButtonStyle {
    case normal
    case accent
    case destructive
}

private struct InspectorActionButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var isDisabled: Bool = false
    var style: InspectorActionButtonStyle = .normal
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

    private var background: LinearGradient {
        if style == .destructive {
            return LinearGradient(
                colors: [
                    Color(NSColor.systemRed).opacity(isDisabled ? 0.2 : 0.25),
                    Color(NSColor.systemRed).opacity(isDisabled ? 0.08 : 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if style == .accent || isActive {
            return LinearGradient(
                colors: [
                    Color.accentColor.opacity(isDisabled ? 0.16 : 0.22),
                    Color.accentColor.opacity(isDisabled ? 0.08 : 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(NSColor.controlBackgroundColor).opacity(0.35),
                    Color(NSColor.windowBackgroundColor).opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        switch style {
        case .destructive:
            return Color(NSColor.systemRed).opacity(isDisabled ? 0.2 : 0.5)
        case .accent:
            return Color.accentColor.opacity(isDisabled ? 0.2 : 0.45)
        default:
            return isActive ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.08)
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.6)
            )
            .opacity(isDisabled ? 0.35 : 1.0)
            .accessibilityLabel(Text(title))
        }
    }
}

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
    let section: ModernInspectorView.InspectorSection
    let title: String
    let alwaysExpanded: Bool
    let isVisible: Bool
    let buildContent: () -> AnyView

    var id: ModernInspectorView.InspectorSection { section }
}

private enum InspectorCategory {
    case text
    case container
    case table
    case image
    case shape
}

private struct InspectorCapabilities {
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
        nestsContentControls = isSimpleTextComponent && supportsTypography
        showsTypographySection = supportsTypography
        let supportsAppearance = type.supportsBackgroundFill || type.supportsBorderControls || type.supportsShadow
        showsAppearanceSection = supportsAppearance && !type.usesTableProperties
        showsTableSection = type.usesTableProperties
        showsImageSection = type.isImageComponent
        showsShapeSection = type.isShape
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

private extension ModernInspectorView {
    func styleBinding<Value>(
        for component: InvoiceComponent,
        _ keyPath: KeyPath<ComponentStyle, Value>,
        update: @escaping (UUID, Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { component.style[keyPath: keyPath] },
            set: { update(component.id, $0) }
        )
    }

    func numericStyleBinding<Value: BinaryFloatingPoint>(
        for component: InvoiceComponent,
        _ keyPath: KeyPath<ComponentStyle, Value>,
        update: @escaping (UUID, Value) -> Void
    ) -> Binding<Double> {
        Binding(
            get: { Double(component.style[keyPath: keyPath]) },
            set: { update(component.id, Value($0)) }
        )
    }

}
