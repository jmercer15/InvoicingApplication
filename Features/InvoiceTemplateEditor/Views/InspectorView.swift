import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var document: InvoiceDocument
    @State private var expandedSections: Set<String> = ["Component Info", "Position & Size"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
            
            if let selected = document.component(document.selectedComponentID) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        // Component Info Section
                        CollapsibleSection(
                            title: "Component Info",
                            isExpanded: expandedSections.contains("Component Info"),
                            onToggle: { toggleSection("Component Info") }
                        ) {
                            componentInfoSection(for: selected)
                        }
                        
                        // Position & Size Section
                        CollapsibleSection(
                            title: "Position & Size",
                            isExpanded: expandedSections.contains("Position & Size"),
                            onToggle: { toggleSection("Position & Size") }
                        ) {
                            positionSizeSection(for: selected)
                        }
                        
                        // Typography Section (for text components)
                        if selected.type.isTextComponent {
                            CollapsibleSection(
                                title: "Typography",
                                isExpanded: expandedSections.contains("Typography"),
                                onToggle: { toggleSection("Typography") }
                            ) {
                                typographySection(for: selected)
                            }
                        }
                        
                        // Shape-specific properties
                        if selected.type == .starShape || selected.type == .triangleShape || selected.type == .lineShape {
                             CollapsibleSection(
                                title: "Shape Properties",
                                isExpanded: expandedSections.contains("Shape Properties"),
                                onToggle: { toggleSection("Shape Properties") }
                            ) {
                                if selected.type == .starShape {
                                    starPropertiesSection(for: selected)
                                }
                                if selected.type == .triangleShape {
                                    trianglePropertiesSection(for: selected)
                                }
                                if selected.type == .lineShape {
                                    linePropertiesSection(for: selected)
                                }
                            }
                        }
                        
                        // Image-specific properties
                        if selected.type == .companyLogo || selected.type == .imagePlaceholder {
                             CollapsibleSection(
                                title: "Image Properties",
                                isExpanded: expandedSections.contains("Image Properties"),
                                onToggle: { toggleSection("Image Properties") }
                            ) {
                                imagePropertiesSection(for: selected)
                            }
                        }
                        
                        // Table-specific properties
                        if selected.type == .servicesTable {
                             CollapsibleSection(
                                title: "Table Properties",
                                isExpanded: expandedSections.contains("Table Properties"),
                                onToggle: { toggleSection("Table Properties") }
                            ) {
                                tablePropertiesSection(for: selected)
                            }
                        }
                        
                        // Section Layout Properties
                        if selected.type.isSection {
                            CollapsibleSection(
                                title: "Section Layout",
                                isExpanded: expandedSections.contains("Section Layout"),
                                onToggle: { toggleSection("Section Layout") }
                            ) {
                                sectionLayoutPropertiesSection(for: selected)
                            }
                        }
                        
                        // Layout & Spacing Section (for all components)
                        CollapsibleSection(
                            title: "Layout & Spacing",
                            isExpanded: expandedSections.contains("Layout & Spacing"),
                            onToggle: { toggleSection("Layout & Spacing") }
                        ) {
                            layoutSpacingSection(for: selected)
                        }
                        
                        // Appearance Section (for shapes and text components)
                        if selected.type.isTextComponent || selected.type == .rectangleShape || selected.type == .ellipseShape || selected.type == .triangleShape || selected.type == .starShape {
                            CollapsibleSection(
                                title: "Appearance",
                                isExpanded: expandedSections.contains("Appearance"),
                                onToggle: { toggleSection("Appearance") }
                            ) {
                                appearanceSection(for: selected)
                            }
                        }
                        
                        // Effects Section (for shapes and text components)
                        if selected.type.isTextComponent || selected.type == .rectangleShape || selected.type == .ellipseShape || selected.type == .triangleShape || selected.type == .starShape {
                            CollapsibleSection(
                                title: "Effects",
                                isExpanded: expandedSections.contains("Effects"),
                                onToggle: { toggleSection("Effects") }
                            ) {
                                effectsSection(for: selected)
                            }
                        }
                        
                        // Preview Section
                        CollapsibleSection(
                            title: "Preview",
                            isExpanded: expandedSections.contains("Preview"),
                            onToggle: { toggleSection("Preview") }
                        ) {
                            previewSection(for: selected)
                        }
                        
                        // Actions Section
                        CollapsibleSection(
                            title: "Actions",
                            isExpanded: expandedSections.contains("Actions"),
                            onToggle: { toggleSection("Actions") }
                        ) {
                            actionsSection(for: selected)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
            } else {
                emptyStateView
            }
        }
        .background(.black)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Label("Inspector", systemImage: "info.circle")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            if document.component(document.selectedComponentID) != nil {
                Button(action: expandAllSections) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down.text.horizontal")
                            .font(.caption)
                        Text("Expand All")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .controlBackgroundColor), Color(nsColor: .controlBackgroundColor).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "hand.point.up.left")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                
                VStack(spacing: 8) {
                    Text("Select a Component")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Choose any component on the canvas to view and edit its properties in this inspector")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    // MARK: - Component Info Section
    
    private func componentInfoSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Component Badge
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(component.type.iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: component.type.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(component.type.iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(component.type.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(component.id.uuidString.prefix(8))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status indicator
                VStack(alignment: .trailing, spacing: 2) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Active")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .controlBackgroundColor),
                                Color(nsColor: .controlBackgroundColor).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(component.type.iconColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
            
            // Component Title (for child components)
            if component.parentSectionId != nil || component.title != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Component Title")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    TextField("Enter title", text: Binding(
                        get: { component.title ?? "" },
                        set: { newTitle in
                            document.updateTitle(for: component.id, title: newTitle.isEmpty ? nil : newTitle)
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
    
    // MARK: - Position & Size Section
    
    private func positionSizeSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Position
            VStack(alignment: .leading, spacing: 8) {
                Text("Position")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("X")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("X", text: Binding(
                            get: { String(Int(component.position.x)) },
                            set: { newValue in
                                if let x = Double(newValue) {
                                    document.setPosition(for: component.id, to: CGPoint(x: x, y: component.position.y))
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Y")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Y", text: Binding(
                            get: { String(Int(component.position.y)) },
                            set: { newValue in
                                if let y = Double(newValue) {
                                    document.setPosition(for: component.id, to: CGPoint(x: component.position.x, y: y))
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Document margins moved to toolbar for quicker access
            
            // Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Size")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Width")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Width", text: Binding(
                            get: { String(Int(component.size.width)) },
                            set: { newValue in
                                if let width = Double(newValue) {
                                    document.setSize(for: component.id, to: CGSize(width: width, height: component.size.height))
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Height")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Height", text: Binding(
                            get: { String(Int(component.size.height)) },
                            set: { newValue in
                                if let height = Double(newValue) {
                                    document.setSize(for: component.id, to: CGSize(width: component.size.width, height: height))
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Star Properties Section
    
    private func starPropertiesSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SliderPropertyEditor(
                title: "Points",
                value: CGFloat(component.style.starPoints),
                range: 3...20,
                step: 1,
                formatter: "%.0f",
                onChange: { document.updateStarPoints(for: component.id, points: Int($0)) }
            )
            
            SliderPropertyEditor(
                title: "Smoothness",
                value: component.style.starSmoothness,
                range: 0.1...0.9,
                step: 0.01,
                formatter: "%.2f",
                onChange: { document.updateStarSmoothness(for: component.id, smoothness: $0) }
            )
        }
    }
    
    // MARK: - Triangle Properties Section
    
    private func trianglePropertiesSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            PickerPropertyEditor(
                title: "Direction",
                selection: component.style.triangleDirection,
                onChange: { document.updateTriangleDirection(for: component.id, direction: $0) }
            )
        }
    }
    
    // MARK: - Line Properties Section
    
    private func linePropertiesSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SliderPropertyEditor(
                title: "Thickness",
                value: component.style.lineThickness,
                range: 1...20,
                step: 0.5,
                formatter: "%.1fpt",
                onChange: { document.updateLineThickness(for: component.id, thickness: $0) }
            )
            
            PickerPropertyEditor(
                title: "Start Decorator",
                selection: component.style.lineStartDecorator,
                onChange: { document.updateLineStartDecorator(for: component.id, decorator: $0) }
            )
            
            PickerPropertyEditor(
                title: "End Decorator",
                selection: component.style.lineEndDecorator,
                onChange: { document.updateLineEndDecorator(for: component.id, decorator: $0) }
            )
        }
    }
    
    // MARK: - Table Properties Section
    
    private func tablePropertiesSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TogglePropertyEditor(
                title: "Show Table Header",
                isOn: component.style.showTableHeader,
                onChange: { document.updateShowTableHeader(for: component.id, show: $0) }
            )
            
            TogglePropertyEditor(
                title: "Use Alternating Row Colors",
                isOn: component.style.useAlternatingRows,
                onChange: { document.updateUseAlternatingRows(for: component.id, use: $0) }
            )

            ColorPropertyEditor(
                title: "Header Color",
                color: Color(hex: component.style.tableHeaderColor),
                hexColor: component.style.tableHeaderColor,
                onChange: { document.updateTableHeaderColor(for: component.id, color: $0) }
            )
            
            ColorPropertyEditor(
                title: "Text Color",
                color: Color(hex: component.style.tableTextColor),
                hexColor: component.style.tableTextColor,
                onChange: { document.updateTableTextColor(for: component.id, color: $0) }
            )
            
            ColorPropertyEditor(
                title: "Row Color",
                color: Color(hex: component.style.tableRowColor),
                hexColor: component.style.tableRowColor,
                onChange: { document.updateTableRowColor(for: component.id, color: $0) }
            )
            
            ColorPropertyEditor(
                title: "Alt Row Color",
                color: Color(hex: component.style.tableRowAltColor),
                hexColor: component.style.tableRowAltColor,
                onChange: { document.updateTableRowAltColor(for: component.id, color: $0) }
            )
            .disabled(!component.style.useAlternatingRows)
        }
    }
    
    // MARK: - Section Layout Properties Section
    
    private func sectionLayoutPropertiesSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            PickerPropertyEditor(
                title: "Layout Type",
                selection: component.style.sectionLayout,
                onChange: { document.updateSectionLayout(for: component.id, layout: $0) }
            )
            
            if component.style.sectionLayout == .grid {
                SliderPropertyEditor(
                    title: "Grid Columns",
                    value: CGFloat(component.style.gridColumns),
                    range: 1...10,
                    step: 1,
                    formatter: "%.0f",
                    onChange: { document.updateGridColumns(for: component.id, columns: Int($0)) }
                )
            }
            
            SliderPropertyEditor(
                title: "Content Spacing",
                value: component.style.contentSpacing,
                range: 0...50,
                step: 1,
                formatter: "%.0f",
                onChange: { document.updateContentSpacing(for: component.id, spacing: $0) }
            )
            
            SliderPropertyEditor(
                title: "Content Padding",
                value: component.style.contentPadding,
                range: 0...50,
                step: 1,
                formatter: "%.0f",
                onChange: { document.updateContentPadding(for: component.id, padding: $0) }
            )
        }
    }
    
    // MARK: - Image Properties Section
    
    private func imagePropertiesSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            PickerPropertyEditor(
                title: "Content Mode",
                selection: component.style.imageContentMode,
                onChange: { document.updateImageContentMode(for: component.id, mode: $0) }
            )
            
            // Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Actions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Button(action: {
                    // Note: Image replacement is handled by double-tapping the component on the canvas
                    // This provides a better UX as users can see exactly which component they're editing
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Double-Tap Component to Replace Image")
                    }
                }
                .disabled(true)

                Button(action: {
                    document.updateImageData(for: component.id, data: nil)
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Clear Image")
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Typography Section
    
    private func typographySection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SliderPropertyEditor(
                title: "Font Size",
                value: component.style.fontSize,
                range: 8...48,
                step: 1,
                formatter: "%.0fpt",
                onChange: { document.updateFontSize(for: component.id, fontSize: $0) }
            )
            
            // Font Weight - Note: Can't use PickerPropertyEditor here as FontWeight doesn't conform to required protocols
            VStack(alignment: .leading, spacing: 8) {
                Text("Font Weight")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Font Weight", selection: Binding(
                    get: { component.style.fontWeight },
                    set: { document.updateFontWeight(for: component.id, weight: $0) }
                )) {
                    Text("Regular").tag("regular")
                    Text("Medium").tag("medium")
                    Text("Semibold").tag("semibold")
                    Text("Bold").tag("bold")
                }
                .pickerStyle(.segmented)
            }
            
            // Text Alignment - Note: Can't use PickerPropertyEditor here as TextAlignment doesn't conform to required protocols
            VStack(alignment: .leading, spacing: 8) {
                Text("Text Alignment")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Alignment", selection: Binding(
                    get: { component.style.textAlignment },
                    set: { document.updateTextAlignment(for: component.id, alignment: $0) }
                )) {
                    Text("Left").tag(TextAlignment.leading)
                    Text("Center").tag(TextAlignment.center)
                    Text("Right").tag(TextAlignment.trailing)
                }
                .pickerStyle(.segmented)
            }
            
            // Font Family - Note: Can't use PickerPropertyEditor here as FontFamily doesn't conform to required protocols
            VStack(alignment: .leading, spacing: 8) {
                Text("Font Family")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Font Family", selection: Binding(
                    get: { component.style.fontFamily },
                    set: { document.updateFontFamily(for: component.id, family: $0) }
                )) {
                    Text("System").tag("system")
                    Text("Serif").tag("serif")
                    Text("Monospace").tag("monospace")
                }
                .pickerStyle(.segmented)
            }
            
            SliderPropertyEditor(
                title: "Line Spacing",
                value: component.style.lineSpacing,
                range: 0.5...3.0,
                step: 0.1,
                formatter: "%.1f",
                onChange: { document.updateLineSpacing(for: component.id, spacing: $0) }
            )
            
            SliderPropertyEditor(
                title: "Letter Spacing",
                value: component.style.letterSpacing,
                range: -2.0...5.0,
                step: 0.1,
                formatter: "%.1f",
                onChange: { document.updateLetterSpacing(for: component.id, spacing: $0) }
            )
            
            ColorPropertyEditor(
                title: "Text Color",
                color: component.style.textColorSwiftUI,
                hexColor: component.style.textColor,
                onChange: { document.updateTextColor(for: component.id, color: $0) }
            )
            
            // Placeholder Text (only for textBox components)
            if component.type == .textBox {
                TextFieldPropertyEditor(
                    title: "Placeholder Text",
                    text: component.style.placeholderText,
                    placeholder: "Enter placeholder text...",
                    onChange: { document.updatePlaceholderText(for: component.id, text: $0) }
                )
            }
        }
    }
    
    // MARK: - Layout & Spacing Section
    
    private func layoutSpacingSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SliderPropertyEditor(
                title: "Padding",
                value: component.style.padding,
                range: 0...20,
                step: 1,
                formatter: "%.0fpt",
                onChange: { document.updatePadding(for: component.id, padding: $0) }
            )
            
            SliderPropertyEditor(
                title: "Margin",
                value: component.style.margin,
                range: 0...20,
                step: 1,
                formatter: "%.0fpt",
                onChange: { document.updateMargin(for: component.id, margin: $0) }
            )
            
            // Note: Width and height constraints are not currently implemented
            // They would be useful for responsive design but require additional logic
        }
    }
    
    // MARK: - Appearance Section
    
    private func appearanceSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Background Color (for shapes only, except line shape)
            if !component.type.isTextComponent && component.type != .lineShape {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background Color")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        ColorPicker("", selection: Binding(
                            get: { component.style.backgroundColorSwiftUI },
                            set: { newColor in
                                let hex = String(format: "%02X%02X%02X", 
                                               Int((NSColor(newColor).redComponent * 255).rounded()),
                                               Int((NSColor(newColor).greenComponent * 255).rounded()),
                                               Int((NSColor(newColor).blueComponent * 255).rounded()))
                                document.updateBackgroundColor(for: component.id, color: hex)
                            }
                        ))
                        .frame(width: 32, height: 32)
                        
                        TextField("Hex Color", text: Binding(
                            get: { "#\(component.style.backgroundColor)" },
                            set: { newValue in
                                let hex = newValue.replacingOccurrences(of: "#", with: "")
                                document.updateBackgroundColor(for: component.id, color: hex)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    }
                }
                
                SliderPropertyEditor(
                    title: "Background Opacity",
                    value: component.style.backgroundOpacity,
                    range: 0...1,
                    step: 0.1,
                    formatter: "%.1f",
                    onChange: { document.updateBackgroundOpacity(for: component.id, opacity: $0) }
                )
                
                // Border (for shapes only, except line shape which has its own line properties)
                if component.type != .lineShape {
                    VStack(alignment: .leading, spacing: 12) {
                    Text("Border")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Border Style")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Border Style", selection: Binding(
                            get: { component.style.borderStyle },
                            set: { document.updateBorderStyle(for: component.id, style: $0) }
                        )) {
                            Text("Solid").tag(BorderStyle.solid)
                            Text("Dashed").tag(BorderStyle.dashed)
                            Text("Dotted").tag(BorderStyle.dotted)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    SliderPropertyEditor(
                        title: "Border Width",
                        value: component.style.borderWidth,
                        range: 0...5,
                        step: 0.5,
                        formatter: "%.1fpt",
                        onChange: { document.updateBorderWidth(for: component.id, width: $0) }
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Border Color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ColorPropertyEditor(
                            title: "",
                            color: component.style.borderColorSwiftUI,
                            hexColor: component.style.borderColor,
                            onChange: { document.updateBorderColor(for: component.id, color: $0) }
                        )
                    }
                }
                
                SliderPropertyEditor(
                    title: "Corner Radius",
                    value: component.style.cornerRadius,
                    range: 0...20,
                    step: 1,
                    formatter: "%.0fpt",
                    onChange: { document.updateCornerRadius(for: component.id, radius: $0) }
                )
                }
            }
            
            // Line color (for line shape only)
            if component.type == .lineShape {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Line Color")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ColorPropertyEditor(
                        title: "",
                        color: component.style.borderColorSwiftUI,
                        hexColor: component.style.borderColor,
                        onChange: { document.updateBorderColor(for: component.id, color: $0) }
                    )
                }
            }
        }
    }
    
    // MARK: - Effects Section
    
    private func effectsSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TogglePropertyEditor(
                title: "Shadow",
                isOn: component.style.shadowEnabled,
                onChange: { document.updateShadowEnabled(for: component.id, enabled: $0) }
            )
            
            if component.style.shadowEnabled {
                ColorPropertyEditor(
                    title: "Shadow Color",
                    color: component.style.shadowColorSwiftUI,
                    hexColor: component.style.shadowColor,
                    onChange: { document.updateShadowColor(for: component.id, color: $0) }
                )
                
                SliderPropertyEditor(
                    title: "Shadow Radius",
                    value: component.style.shadowRadius,
                    range: 0...20,
                    step: 1,
                    formatter: "%.0fpt",
                    onChange: { document.updateShadowRadius(for: component.id, radius: $0) }
                )
                
                ShadowOffsetEditor(
                    offsetX: component.style.shadowOffsetX,
                    offsetY: component.style.shadowOffsetY,
                    onChange: { x, y in
                        document.updateShadowOffset(for: component.id, x: x, y: y)
                    }
                )
                
                SliderPropertyEditor(
                    title: "Shadow Opacity",
                    value: component.style.shadowOpacity,
                    range: 0...1,
                    step: 0.1,
                    formatter: "%.1f",
                    onChange: { document.updateShadowOpacity(for: component.id, opacity: $0) }
                )
            }
        }
    }
    
    // MARK: - Preview Section
    
    private func previewSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Preview")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            // Preview container with fixed size
            VStack {
                ZStack {
                    // Background grid for reference
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            Path { path in
                                let gridSize: CGFloat = 10
                                for x in stride(from: 0, through: 200, by: gridSize) {
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: 150))
                                }
                                for y in stride(from: 0, through: 150, by: gridSize) {
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: 200, y: y))
                                }
                            }
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        )
                    
                    // Component preview
                    ComponentPreviewView(component: component)
                        .frame(width: min(component.size.width, 180), height: min(component.size.height, 130))
                        .scaleEffect(min(180 / component.size.width, 130 / component.size.height, 1.0))
                }
                .frame(width: 200, height: 150)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
            }
            
            // Component info
            VStack(alignment: .leading, spacing: 4) {
                Text("Type: \(component.type.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Size: \(Int(component.size.width)) × \(Int(component.size.height))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Position: (\(Int(component.position.x)), \(Int(component.position.y)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Actions Section
    
    private func actionsSection(for component: InvoiceComponent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Copy Component
            Button(action: {
                document.copyComponent(component.id)
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .font(.body)
                    Text("Copy Component")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
                .buttonStyle(.plain)
            
            // Reset to Defaults
            Button(action: {
                document.resetComponentToDefaults(for: component.id)
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                    Text("Reset to Defaults")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Delete Component
            Button(action: {
                document.removeComponent(with: component.id)
            }) {
                HStack {
                    Image(systemName: "trash")
                        .font(.body)
                    Text("Delete Component")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.red)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleSection(_ sectionName: String) {
        if expandedSections.contains(sectionName) {
            expandedSections.remove(sectionName)
        } else {
            expandedSections.insert(sectionName)
        }
    }
    
    private func expandAllSections() {
        expandedSections = ["Component Info", "Position & Size", "Typography", "Shape Properties", "Image Properties", "Table Properties", "Layout & Spacing", "Appearance", "Effects", "Actions"]
    }
    

}

// MARK: - Collapsible Section View

struct CollapsibleSection<Content: View>: View {
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
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(nsColor: .controlBackgroundColor),
                                    Color(nsColor: .controlBackgroundColor).opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.separator.opacity(0.8), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
                .scaleEffect(isExpanded ? 1.0 : 0.98)
                .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isExpanded)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    content
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.separator.opacity(0.3), lineWidth: 0.5)
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    )
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
}