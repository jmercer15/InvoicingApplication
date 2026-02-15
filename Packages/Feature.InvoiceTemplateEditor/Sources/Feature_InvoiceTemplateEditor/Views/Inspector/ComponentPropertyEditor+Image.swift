import SwiftUI
import Core
import SharedUI

// MARK: - Image Controls

extension ComponentPropertyEditor {
    @ViewBuilder
    func imageContentControls(for component: InvoiceComponent) -> some View {
        let factory = ComponentInspectorControlFactory(component: component, document: document)
        
        // Sizing - uses InspectorGrid for mixed InspectorControl and View content
        InspectorGroupBox(title: "Sizing", icon: "fluent-ic_fluent_arrow_expand_20_regular") {
            InspectorGrid {
                factory.picker("contentMode", keyPath: \.imageContentMode, icon: "fluent-ic_fluent_content_view_20_regular",
                              tooltip: "Content Mode") { $0.rawValue.capitalized }
                
                // Width Mode
                InspectorControl.picker("widthMode", icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                       tooltip: "Width Mode", selection: Binding(
                                        get: { component.style.imageWidthMode ?? .auto },
                                        set: { newValue in
                                            document.updateComponentStyle(for: component.id, actionName: "Change Width Mode") { $0.imageWidthMode = newValue }
                                        }
                                       )) {
                    ForEach(ComponentSizingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                
                if component.style.imageWidthMode == .fixed {
                    factory.stepper("widthValue", keyPath: \.imageWidth, icon: "fluent-ic_fluent_resize_image_20_regular",
                                   tooltip: "Width", range: 0...1000, step: 1, suffix: "pt")
                }
                
                // Height Mode
                InspectorControl.picker("heightMode", icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                                       tooltip: "Height Mode", selection: Binding(
                                        get: { component.style.imageHeightMode ?? .auto },
                                        set: { newValue in
                                            document.updateComponentStyle(for: component.id, actionName: "Change Height Mode") { $0.imageHeightMode = newValue }
                                        }
                                       )) {
                    ForEach(ComponentSizingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                
                if component.style.imageHeightMode == .fixed {
                    factory.stepper("heightValue", keyPath: \.imageHeight, icon: "fluent-ic_fluent_resize_image_20_regular",
                                   tooltip: "Height", range: 0...1000, step: 1, suffix: "pt")
                }
                
                factory.stepper("aspectRatio", keyPath: \.aspectRatio, icon: "fluent-ic_fluent_resize_image_20_regular",
                                tooltip: "Aspect Ratio", range: 0.1...3.0, step: 0.1, suffix: "", format: .decimal(places: 1))
                
                factory.stepper("opacity", keyPath: \.imageOpacity, icon: "fluent-ic_fluent_circle_half_fill_20_regular",
                                tooltip: "Opacity", range: 0...1, step: 0.1, suffix: "%", format: .decimal(places: 0))
            }
        }
        
        // Constraints
        InspectorGroupBox(title: "Constraints", icon: "fluent-ic_fluent_ruler_20_regular") {
            InspectorControlGroup {
                imageConstraintControl("minWidth", keyPath: \.imageMinWidth, icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                      tooltip: "Minimum Width", component: component)
                
                imageConstraintControl("maxWidth", keyPath: \.imageMaxWidth, icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                      tooltip: "Maximum Width", component: component)
                
                imageConstraintControl("minHeight", keyPath: \.imageMinHeight, icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                                      tooltip: "Minimum Height", component: component)
                
                imageConstraintControl("maxHeight", keyPath: \.imageMaxHeight, icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                                      tooltip: "Maximum Height", component: component)
            }
        }
    }
    

    
    /// Helper for constraint text fields with optional CGFloat
    private func imageConstraintControl(_ id: String, keyPath: WritableKeyPath<ComponentStyle, CGFloat?>,
                                        icon: String, tooltip: String, component: InvoiceComponent) -> InspectorControl {
        let binding = Binding<String>(
            get: {
                if let value = component.style[keyPath: keyPath] {
                    return String(format: "%.0f", value)
                }
                return ""
            },
            set: { newValue in
                document.updateComponentStyle(for: component.id, actionName: "Change Image Constraint") { style in
                    style[keyPath: keyPath] = Double(newValue).map { CGFloat($0) }
                }
            }
        )
        return .text(id, icon: icon, tooltip: tooltip, text: binding)
    }
}

// MARK: - Preview

#Preview("Image Inspector - Sizing Controls") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    @Previewable @State var contentMode = "Fit"
    @Previewable @State var widthMode = "Auto"
    @Previewable @State var widthValue: Double = 200
    @Previewable @State var heightMode = "Auto"
    @Previewable @State var heightValue: Double = 150
    @Previewable @State var aspectRatio: Double = 1.33
    @Previewable @State var opacity: Double = 100
    
    VStack(spacing: 16) {
        InspectorGroupBox(title: "Sizing", icon: "fluent-ic_fluent_resize_image_20_regular") {
            InspectorGrid {
                InspectorControl.picker("contentMode", icon: "fluent-ic_fluent_maximize_20_regular",
                                       tooltip: "Content Mode", selection: $contentMode) {
                    Text("Fill").tag("Fill")
                    Text("Fit").tag("Fit")
                }
                
                InspectorControl.picker("widthMode", icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                       tooltip: "Width Mode", selection: $widthMode) {
                    Text("Auto").tag("Auto")
                    Text("Fixed").tag("Fixed")
                    Text("Fill").tag("Fill")
                }
                
                if widthMode == "Fixed" {
                    InspectorControl.stepper("widthValue", icon: "fluent-ic_fluent_resize_image_20_regular",
                                            tooltip: "Width", value: $widthValue, range: 0...1000, step: 1, suffix: "pt")
                }
                
                InspectorControl.picker("heightMode", icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                                       tooltip: "Height Mode", selection: $heightMode) {
                    Text("Auto").tag("Auto")
                    Text("Fixed").tag("Fixed")
                    Text("Fill").tag("Fill")
                }
                
                if heightMode == "Fixed" {
                    InspectorControl.stepper("heightValue", icon: "fluent-ic_fluent_resize_image_20_regular",
                                            tooltip: "Height", value: $heightValue, range: 0...1000, step: 1, suffix: "pt")
                }
                
                InspectorControl.stepper("aspectRatio", icon: "fluent-ic_fluent_scale_fit_20_regular",
                                        tooltip: "Aspect Ratio", value: $aspectRatio, range: 0.1...3.0, step: 0.1, suffix: "", format: .decimal(places: 1))
                
                InspectorControl.stepper("opacity", icon: "fluent-ic_fluent_circle_half_fill_20_regular",
                                        tooltip: "Opacity", value: $opacity, range: 0...100, step: 5, suffix: "%")
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        // Preview image placeholder
        Image("fluent-ic_fluent_image_20_regular", bundle: .module)
            .resizable()
            .aspectRatio(aspectRatio, contentMode: contentMode == "Fill" ? .fill : .fit)
            .foregroundColor(.gray)
            .opacity(opacity / 100)
            .frame(width: 100, height: 75)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
    .frame(width: 280)
    .padding()
    .onAppear { context.expandedID = "Sizing" }
}

#Preview("Image Inspector - Constraints") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    @Previewable @State var minWidth: Double = 50
    @Previewable @State var maxWidth: Double = 400
    @Previewable @State var minHeight: Double = 50
    @Previewable @State var maxHeight: Double = 300
    
    VStack(spacing: 16) {
        InspectorGroupBox(title: "Constraints", icon: "fluent-ic_fluent_ruler_20_regular") {
            InspectorGrid {
                InspectorControl.stepper("minWidth", icon: "fluent-ic_fluent_align_center_horizontal_20_regular",
                                        tooltip: "Min Width", value: $minWidth, range: 0...1000, step: 1, suffix: "pt")
                
                InspectorControl.stepper("maxWidth", icon: "fluent-ic_fluent_align_center_horizontal_20_regular",
                                        tooltip: "Max Width", value: $maxWidth, range: 0...1000, step: 1, suffix: "pt")
                
                InspectorControl.stepper("minHeight", icon: "fluent-ic_fluent_align_center_vertical_20_regular",
                                        tooltip: "Min Height", value: $minHeight, range: 0...1000, step: 1, suffix: "pt")
                
                InspectorControl.stepper("maxHeight", icon: "fluent-ic_fluent_align_center_vertical_20_regular",
                                        tooltip: "Max Height", value: $maxHeight, range: 0...1000, step: 1, suffix: "pt")
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        // Constraint visualization
        VStack(spacing: 4) {
            Text("Width: \(Int(minWidth)) - \(Int(maxWidth))")
                .font(.caption)
            Text("Height: \(Int(minHeight)) - \(Int(maxHeight))")
                .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    .frame(width: 280)
    .padding()
    .onAppear { context.expandedID = "Constraints" }
}
