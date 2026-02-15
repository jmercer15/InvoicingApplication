import SwiftUI
import Core
import SharedUI

// MARK: - Text Controls

extension ComponentPropertyEditor {
    @ViewBuilder
    func textSectionContent(for component: InvoiceComponent, capabilities: InspectorCapabilities) -> some View {
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
    
    @ViewBuilder
    func textContentControls(for component: InvoiceComponent, title: String? = nil) -> some View {
        let factory = ComponentInspectorControlFactory(component: component, document: document)
        
        InspectorGroupBox(title: title, icon: "fluent-ic_fluent_text_align_left_20_regular") {
            InspectorControlGroup {
                textFieldControl("content", keyPath: \.placeholderText, icon: "fluent-ic_fluent_text_20_regular",
                                tooltip: "Content", placeholder: "Content", component: component)
                
                factory.button("clear", icon: "fluent-ic_fluent_delete_20_regular", tooltip: "Clear Content", title: "Clear Content") {
                    self.document.updateComponentStyle(for: component.id, actionName: "Clear Content") { $0.placeholderText = "" }
                }
            }
        }
    }
    
    /// Helper for text field controls with styleBinding
    private func textFieldControl(_ id: String, keyPath: WritableKeyPath<ComponentStyle, String>,
                                  icon: String, tooltip: String, placeholder: String,
                                  component: InvoiceComponent) -> InspectorControl {
        let binding = styleBinding(for: component, keyPath) { componentID, text in
            document.updateComponentStyle(for: componentID, actionName: "Change Content") { $0[keyPath: keyPath] = text }
        }
        return .text(id, icon: icon, tooltip: tooltip, text: binding)
    }
    
    @ViewBuilder
    func textTypographyControls(for component: InvoiceComponent) -> some View {
        let configurationBinding = Binding<FontPickerConfiguration>(
            get: {
                FontPickerConfiguration(from: liveComponent.style, scope: .text)
            },
            set: { config in
                document.updateComponentStyle(for: component.id, actionName: "Change Typography") { style in
                    config.apply(to: &style, scope: .text)
                }
            }
        )
        
        // Use InlineFontPicker for consistent UI and full feature support
        // Opacity is now handled within InlineFontPicker's Style section
        InlineFontPicker(configuration: configurationBinding)
    }
}

// MARK: - Preview

#Preview("Text Inspector - Content Controls") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    @Previewable @State var contentText = "Invoice #2024-001"
    
    VStack(spacing: 16) {
        InspectorGroupBox(title: nil, icon: "fluent-ic_fluent_text_align_left_20_regular") {
            InspectorGrid {
                InspectorControl.text("content", icon: "fluent-ic_fluent_text_20_regular",
                                     tooltip: "Content", text: $contentText)
                
                InspectorControl.button("clear", icon: "fluent-ic_fluent_delete_20_regular",
                                       tooltip: "Clear Content", title: "Clear Content", action: {
                                        contentText = ""
                                       })
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        Divider()
        
        // Preview text display
        Text(contentText.isEmpty ? "Enter text here" : contentText)
            .font(.title3)
            .foregroundColor(contentText.isEmpty ? .secondary : .primary)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
    .frame(width: 280)
    .padding()
}

#Preview("Text Inspector - Typography Controls") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    @Previewable @State var fontFamily = "SF Pro"
    @Previewable @State var fontSize: Double = 16
    @Previewable @State var fontWeight = "Regular"
    @Previewable @State var textColor = Color.primary
    @Previewable @State var isBold = false
    @Previewable @State var isItalic = false
    @Previewable @State var selectedAlignment = 0  // 0=leading, 1=center, 2=trailing
    
    VStack(spacing: 16) {
        InspectorGroupBox(title: "Typography", icon: "fluent-ic_fluent_text_font_20_regular") {
            InspectorGrid {
                InspectorControl.picker("fontFamily", icon: "fluent-ic_fluent_text_20_regular",
                                       tooltip: "Font Family", selection: $fontFamily) {
                    Text("SF Pro").tag("SF Pro")
                    Text("Helvetica").tag("Helvetica")
                    Text("Georgia").tag("Georgia")
                }
                
                InspectorControl.stepper("fontSize", icon: "fluent-ic_fluent_font_increase_20_regular",
                                        tooltip: "Font Size", value: $fontSize, range: 8...72, step: 1, suffix: "pt")
                
                InspectorControl.picker("fontWeight", icon: "fluent-ic_fluent_text_bold_20_regular",
                                       tooltip: "Font Weight", selection: $fontWeight) {
                    Text("Light").tag("Light")
                    Text("Regular").tag("Regular")
                    Text("Medium").tag("Medium")
                    Text("Bold").tag("Bold")
                }
                
                InspectorControl.colorPicker("textColor", icon: "fluent-ic_fluent_text_color_20_regular",
                                           tooltip: "Text Color", selection: $textColor)
                
                InspectorControl.picker("alignment", icon: "fluent-ic_fluent_text_align_left_20_regular",
                                       tooltip: "Alignment", selection: $selectedAlignment) {
                    InspectorIcon("fluent-ic_fluent_text_align_left_20_regular", tooltip: "Align Left", showLabel: false).tag(0)
                    InspectorIcon("fluent-ic_fluent_text_align_center_20_regular", tooltip: "Align Center", showLabel: false).tag(1)
                    InspectorIcon("fluent-ic_fluent_text_align_right_20_regular", tooltip: "Align Right", showLabel: false).tag(2)
                }
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        // Preview text
        Text("Sample Text Preview")
            .font(.system(size: fontSize, weight: fontWeight == "Bold" ? .bold : .regular))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, alignment: selectedAlignment == 0 ? .leading : selectedAlignment == 2 ? .trailing : .center)
            .padding()
    }
    .frame(width: 280)
    .padding()
    .onAppear { context.expandedID = "Typography" }
}
