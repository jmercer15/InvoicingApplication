import SwiftUI
import Core
import SharedUI

// MARK: - Appearance & Layout Controls

extension ComponentPropertyEditor {
    func orderedSections(for category: InspectorCategory) -> [InspectorSection] {
        switch category {
        case .text:
            return [.text, .layout, .appearance]
        case .container:
            return [.visibility, .text, .layout, .appearance]
        case .table:
            return [
                .tableLayoutStructure,
                .tableFill,
                .tableBorders,
                .tableShadow,
                .tableTypography,
                .tableColumns,
                .sectionTitle,
                .visibility
            ]
        case .image:
            return [.image, .layout, .appearance]
        case .shape:
            return [.shape, .layout, .appearance]
        }
    }
    
    @ViewBuilder
    func appearanceSection(for component: InvoiceComponent) -> some View {
        let factory = ComponentInspectorControlFactory(component: component, document: document)
        
        VStack(spacing: 10) {
            if component.type.supportsBackgroundFill || component.type.supportsBorderControls {
                InspectorGroupBox(title: "Fill & Border", icon: "fluent-ic_fluent_color_fill_20_regular") {
                    InspectorControlGroup {
                        if component.type.supportsBackgroundFill {
                            factory.color("bgColor", colorKeyPath: \.backgroundColor, swiftUIKeyPath: \.backgroundColorSwiftUI,
                                         icon: "fluent-ic_fluent_color_background_20_regular", tooltip: "Background Color")
                            
                            factory.stepper("bgOpacity", keyPath: \.backgroundOpacity, icon: "fluent-ic_fluent_circle_half_fill_20_regular",
                                           tooltip: "Background Opacity", range: 0...1, step: 0.1, suffix: "%", format: .decimal(places: 0))
                        }
                        
                        if component.type.supportsBorderControls {
                            factory.color("borderColor", colorKeyPath: \.borderColor, swiftUIKeyPath: \.borderColorSwiftUI,
                                         icon: "fluent-ic_fluent_color_line_20_regular", tooltip: "Border Color")
                            
                            factory.stepper("borderWidth", keyPath: \.borderWidth, icon: "fluent-ic_fluent_line_thickness_20_regular",
                                           tooltip: "Border Width", range: 0...20, step: 0.5, suffix: "pt", format: .decimal(places: 1))
                            
                            factory.stepper("cornerRadius", keyPath: \.cornerRadius, icon: "fluent-ic_fluent_square_hint_20_regular",
                                           tooltip: "Corner Radius", range: 0...50, step: 1, suffix: "pt")
                        }
                    }
                }
            }

            if component.type.supportsShadow {
                shadowControls(for: component)
            }
        }
    }

    @ViewBuilder
    func layoutSection(for component: InvoiceComponent) -> some View {
        let factory = ComponentInspectorControlFactory(component: component, document: document)
        
        InspectorGroupBox(title: "Spacing", icon: "fluent-ic_fluent_arrow_expand_20_regular") {
            InspectorControlGroup {
                factory.stepper("margin", keyPath: \.margin, icon: "fluent-ic_fluent_border_all_20_regular",
                               tooltip: "Margin", range: 0...200, step: 1, suffix: "pt")
                
                if component.type.supportsBackgroundFill || component.type.supportsBorderControls {
                    factory.stepper("padding", keyPath: \.padding, icon: "fluent-ic_fluent_padding_left_20_regular",
                                   tooltip: "Padding", range: 0...200, step: 1, suffix: "pt")
                }
            }
        }
    }

    @ViewBuilder
    func shadowControls(for component: InvoiceComponent) -> some View {
        let factory = ComponentInspectorControlFactory(component: component, document: document)
        
        InspectorGroupBox(title: "Shadow", icon: "fluent-ic_fluent_circle_shadow_20_regular") {
            InspectorControlGroup {
                factory.toggle("shadowEnabled", keyPath: \.shadowEnabled, icon: "fluent-ic_fluent_circle_shadow_20_regular",
                              tooltip: "Shadow")
                
                if component.style.shadowEnabled {
                    factory.color("shadowColor", colorKeyPath: \.shadowColor, swiftUIKeyPath: \.shadowColorSwiftUI,
                                 icon: "fluent-ic_fluent_color_fill_20_regular", tooltip: "Shadow Color")
                    
                    factory.stepper("shadowOpacity", keyPath: \.shadowOpacity, icon: "fluent-ic_fluent_circle_half_fill_20_regular",
                                   tooltip: "Shadow Opacity", range: 0...1, step: 0.1, suffix: "%", format: .decimal(places: 0))
                    
//                    shadowOffsetControl("shadowOffsetX", keyPath: \.shadowOffsetX, preserveKeyPath: \.shadowOffsetY,
//                                       icon: "fluent-ic_fluent_arrow_swap_20_regular", tooltip: "Offset X", component: component)
                    
                    shadowOffsetControl("shadowOffsetX", keyPath: \.shadowOffsetX, preserveKeyPath: \.shadowOffsetY,
                                       icon: "fluent-ic_fluent_arrow_move_20_regular", tooltip: "Offset X", component: component)

                    shadowOffsetControl("shadowOffsetY", keyPath: \.shadowOffsetY, preserveKeyPath: \.shadowOffsetX,
                                       icon: "fluent-ic_fluent_arrow_bidirectional_up_down_20_regular", tooltip: "Offset Y", component: component)
                    
                    factory.stepper("shadowRadius", keyPath: \.shadowRadius, icon: "fluent-ic_fluent_blur_20_regular",
                                   tooltip: "Shadow Radius", range: 0...50, step: 1, suffix: "pt")
                }
            }
        }
    }
    
    /// Helper for shadow offset controls that need to preserve the other offset value
    private func shadowOffsetControl(_ id: String, keyPath: WritableKeyPath<ComponentStyle, CGFloat>,
                                     preserveKeyPath: WritableKeyPath<ComponentStyle, CGFloat>,
                                     icon: String, tooltip: String, component: InvoiceComponent) -> InspectorControl {
        let binding = Binding<Double>(
            get: { Double(component.style[keyPath: keyPath]) },
            set: { newValue in
                let clamped = CGFloat(min(max(newValue, -50), 50))
                let preserved = document.component(component.id)?.style[keyPath: preserveKeyPath] ?? component.style[keyPath: preserveKeyPath]
                document.updateComponentStyle(for: component.id, actionName: "Change Shadow") { style in
                    style[keyPath: keyPath] = clamped
                    style[keyPath: preserveKeyPath] = preserved
                }
            }
        )
        return .stepper(id, icon: icon, tooltip: tooltip, value: binding, range: -50...50, step: 1, suffix: "pt", format: .integer)
    }
}

// MARK: - Preview

#Preview("Appearance Inspector - Fill & Border") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    @Previewable @State var backgroundColor = Color.blue
    @Previewable @State var backgroundOpacity: Double = 100
    @Previewable @State var borderColor = Color.black
    @Previewable @State var borderWidth: Double = 2
    @Previewable @State var cornerRadius: Double = 8
    
    VStack(spacing: 16) {
        InspectorGroupBox(title: "Fill & Border", icon: "fluent-ic_fluent_color_fill_20_regular") {
            InspectorGrid {
                InspectorControl.colorPicker("bgColor", icon: "fluent-ic_fluent_color_background_20_regular",
                                           tooltip: "Background Color", selection: $backgroundColor)
                
                InspectorControl.stepper("bgOpacity", icon: "fluent-ic_fluent_circle_half_fill_20_regular",
                                        tooltip: "Background Opacity", value: $backgroundOpacity, range: 0...100, step: 5, suffix: "%")
                
                InspectorControl.colorPicker("borderColor", icon: "fluent-ic_fluent_color_line_20_regular",
                                           tooltip: "Border Color", selection: $borderColor)
                
                InspectorControl.stepper("borderWidth", icon: "fluent-ic_fluent_line_thickness_20_regular",
                                        tooltip: "Border Width", value: $borderWidth, range: 0...10, step: 0.5, suffix: "pt")
                
                InspectorControl.stepper("cornerRadius", icon: "fluent-ic_fluent_square_hint_20_regular",
                                        tooltip: "Corner Radius", value: $cornerRadius, range: 0...50, step: 1, suffix: "pt")
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        // Preview shape
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(backgroundColor.opacity(backgroundOpacity / 100))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .frame(width: 100, height: 60)
    }
    .frame(width: 280)
    .padding()
    .onAppear { context.expandedID = "Fill & Border" }
}

#Preview("Shadow Controls") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    @Previewable @State var shadowEnabled = true
    @Previewable @State var shadowColor = Color.black
    @Previewable @State var shadowOpacity: Double = 30
    @Previewable @State var shadowRadius: Double = 8
    @Previewable @State var shadowOffsetX: Double = 0
    @Previewable @State var shadowOffsetY: Double = 4
    
    VStack(spacing: 16) {
        InspectorGroupBox(title: "Shadow", icon: "fluent-ic_fluent_circle_shadow_20_regular") {
            InspectorGrid {
                InspectorControl.toggle("shadowEnabled", icon: "fluent-ic_fluent_circle_shadow_20_regular",
                                       tooltip: "Shadow Enabled", isOn: $shadowEnabled)
                
                if shadowEnabled {
                    InspectorControl.colorPicker("shadowColor", icon: "fluent-ic_fluent_color_fill_20_regular",
                                               tooltip: "Shadow Color", selection: $shadowColor)
                    
                    InspectorControl.stepper("shadowOpacity", icon: "fluent-ic_fluent_circle_half_fill_20_regular",
                                            tooltip: "Shadow Opacity", value: $shadowOpacity, range: 0...100, step: 5, suffix: "%")
                    
                    InspectorControl.stepper("shadowRadius", icon: "fluent-ic_fluent_blur_20_regular",
                                            tooltip: "Shadow Radius", value: $shadowRadius, range: 0...50, step: 1, suffix: "pt")
                    
                    InspectorControl.stepper("shadowOffsetX", icon: "fluent-ic_fluent_arrow_move_20_regular",
                                            tooltip: "X Offset", value: $shadowOffsetX, range: -20...20, step: 1, suffix: "pt")
                    
                    InspectorControl.stepper("shadowOffsetY", icon: "fluent-ic_fluent_position_backward_20_regular",
                                            tooltip: "Y Offset", value: $shadowOffsetY, range: -20...20, step: 1, suffix: "pt")
                }
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        // Preview shape with shadow
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white)
            .frame(width: 100, height: 60)
            .shadow(
                color: shadowEnabled ? shadowColor.opacity(shadowOpacity / 100) : .clear,
                radius: shadowRadius,
                x: shadowOffsetX,
                y: shadowOffsetY
            )
    }
    .frame(width: 280)
    .padding()
    .onAppear { context.expandedID = "Shadow" }
}
