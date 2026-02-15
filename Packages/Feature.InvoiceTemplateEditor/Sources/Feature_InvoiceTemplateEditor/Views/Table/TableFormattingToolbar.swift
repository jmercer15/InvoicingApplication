import SwiftUI

/// Formatting toolbar for table cells with text editing and formatting commands
struct TableFormattingToolbar: View {
    @ObservedObject var document: TableDocument
    @ObservedObject var selectionManager: SelectionManager
    
    private var selectedCells: [CellModel] {
        selectionManager.selectedCells.compactMap { coord in
            document.activeCells.first(where: { $0.coordinate == coord })
        }
    }
    
    private var currentStyle: CellStyle? {
        selectedCells.first?.style
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Text Formatting Group
            GroupBox {
                HStack(spacing: 8) {
                    // Bold
                    ToolbarButton(
                        icon: "fluent-ic_fluent_text_bold_20_regular",
                        isActive: currentStyle?.isBold ?? false,
                        action: { toggleBold() }
                    )
                    .help("Bold")
                    
                    // Italic
                    ToolbarButton(
                        icon: "fluent-ic_fluent_text_italic_20_regular",
                        isActive: currentStyle?.isItalic ?? false,
                        action: { toggleItalic() }
                    )
                    .help("Italic")
                    
                    // Underline
                    ToolbarButton(
                        icon: "fluent-ic_fluent_text_underline_20_regular",
                        isActive: currentStyle?.isUnderline ?? false,
                        action: { toggleUnderline() }
                    )
                    .help("Underline")
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Font Size
                    Menu {
                        ForEach([10, 12, 14, 16, 18, 20, 24, 28, 32], id: \.self) { size in
                            Button("\(size) pt") {
                                setFontSize(CGFloat(size))
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image("fluent-ic_fluent_text_font_size_20_regular", bundle: .module)
                                .resizable()
                                .renderingMode(.template)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            Text("\(Int(currentStyle?.fontSize ?? 14))")
                                .frame(minWidth: 20)
                            Image("fluent-ic_fluent_chevron_down_20_regular", bundle: .module)
                                .resizable()
                                .renderingMode(.template)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .help("Font Size")
                }
                .padding(4)
            }
            
            // Text Alignment Group
            GroupBox {
                HStack(spacing: 8) {
                    ToolbarButton(
                        icon: "fluent-ic_fluent_text_align_left_20_regular",
                        isActive: currentStyle?.textAlignment == .leading,
                        action: { setAlignment(.leading) }
                    )
                    .help("Align Left")
                    
                    ToolbarButton(
                        icon: "fluent-ic_fluent_text_align_center_20_regular",
                        isActive: currentStyle?.textAlignment == .center,
                        action: { setAlignment(.center) }
                    )
                    .help("Align Center")
                    
                    ToolbarButton(
                        icon: "fluent-ic_fluent_text_align_right_20_regular",
                        isActive: currentStyle?.textAlignment == .trailing,
                        action: { setAlignment(.trailing) }
                    )
                    .help("Align Right")
                }
                .padding(4)
            }
            
            // Vertical Alignment Group
            GroupBox {
                HStack(spacing: 8) {
                    ToolbarButton(
                        icon: "arrow.up.to.line",
                        isActive: currentStyle?.verticalAlignment == .top,
                        action: { setVerticalAlignment(.top) }
                    )
                    .help("Align Top")
                    
                    ToolbarButton(
                        icon: "arrow.up.and.down.text.horizontal",
                        isActive: currentStyle?.verticalAlignment == .center,
                        action: { setVerticalAlignment(.center) }
                    )
                    .help("Align Middle")
                    
                    ToolbarButton(
                        icon: "arrow.down.to.line",
                        isActive: currentStyle?.verticalAlignment == .bottom,
                        action: { setVerticalAlignment(.bottom) }
                    )
                    .help("Align Bottom")
                }
                .padding(4)
            }
            
            // Colors Group
            GroupBox {
                HStack(spacing: 8) {
                    // Text Color
                    ColorPicker("", selection: Binding(
                        get: { currentStyle?.textColor.swiftUIColor ?? .black },
                        set: { setTextColor($0) }
                    ))
                    .labelsHidden()
                    .frame(width: 30, height: 24)
                    .help("Text Color")
                    
                    // Background Color
                    ColorPicker("", selection: Binding(
                        get: { currentStyle?.backgroundColor?.swiftUIColor ?? .clear },
                        set: { setBackgroundColor($0) }
                    ))
                    .labelsHidden()
                    .frame(width: 30, height: 24)
                    .help("Background Color")
                }
                .padding(4)
            }
            
            Spacer()
            
            // Clear Formatting
            Button(action: clearFormatting) {
                Label {
                    Text("Clear Formatting")
                } icon: {
                    Image("fluent-ic_fluent_delete_20_regular", bundle: .module)
                        .renderingMode(.template) 
                }
            }
            .help("Clear Formatting")
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func toggleBold() {
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style.isBold.toggle()
        }
    }
    
    private func toggleItalic() {
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style.isItalic.toggle()
        }
    }
    
    private func toggleUnderline() {
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style.isUnderline.toggle()
        }
    }
    
    private func setFontSize(_ size: CGFloat) {
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style.fontSize = size
        }
    }
    
    private func setAlignment(_ alignment: TextAlignment) {
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style.textAlignment = alignment
        }
    }
    
    private func setVerticalAlignment(_ alignment: CellVerticalAlignment) {
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style.verticalAlignment = alignment
        }
    }
    
    private func setTextColor(_ color: Color) {
        let components = color.cgColor?.components ?? [0, 0, 0, 1]
        let wrapper = ColorWrapper(
            red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2]),
            opacity: Double(components[3])
        )
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style.textColor = wrapper
        }
    }
    
    private func setBackgroundColor(_ color: Color) {
        let components = color.cgColor?.components ?? [0, 0, 0, 1]
        let wrapper = ColorWrapper(
            red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2]),
            opacity: Double(components[3])
        )
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style.backgroundColor = wrapper
        }
    }
    
    private func clearFormatting() {
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style = CellStyle() // Reset to default
        }
    }
}

/// Toolbar button component
private struct ToolbarButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(icon, bundle: .module)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.primary)
                .frame(width: 20, height: 20)
                .frame(width: 24, height: 24)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("ToolbarButton - States") {
    HStack(spacing: 16) {
        // Inactive buttons
        VStack(spacing: 8) {
            Text("Inactive").font(.caption)
            HStack(spacing: 8) {
                ToolbarButton(icon: "bold", isActive: false, action: {})
                ToolbarButton(icon: "italic", isActive: false, action: {})
                ToolbarButton(icon: "underline", isActive: false, action: {})
            }
        }
        
        Divider().frame(height: 60)
        
        // Active buttons
        VStack(spacing: 8) {
            Text("Active").font(.caption)
            HStack(spacing: 8) {
                ToolbarButton(icon: "bold", isActive: true, action: {})
                ToolbarButton(icon: "italic", isActive: true, action: {})
                ToolbarButton(icon: "underline", isActive: true, action: {})
            }
        }
    }
    .padding()
}
