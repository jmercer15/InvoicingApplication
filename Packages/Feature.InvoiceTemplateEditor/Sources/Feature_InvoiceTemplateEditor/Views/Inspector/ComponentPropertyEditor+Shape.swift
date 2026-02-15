import SwiftUI
import Core
import SharedUI

// MARK: - Shape Controls

extension ComponentPropertyEditor {
    @ViewBuilder
    func shapeSection(for component: InvoiceComponent) -> some View {
        let factory = ComponentInspectorControlFactory(component: component, document: document)
        
        switch component.type {
        case .lineShape:
            InspectorGroupBox(title: "Line", icon: "fluent-ic_fluent_inking_tool_20_regular") {
                InspectorControlGroup {
                    factory.stepper("thickness", keyPath: \.lineThickness, icon: "fluent-ic_fluent_line_thickness_20_regular",
                                   tooltip: "Thickness", range: 0.5...20, step: 0.5, suffix: "pt", format: .decimal(places: 1))
                    
                    factory.picker("lineStyle", keyPath: \.lineStyle, icon: "fluent-ic_fluent_line_style_20_regular",
                                  tooltip: "Line Style") { $0.rawValue.capitalized }
                    
                    lineDecoratorPicker("startDecorator", keyPath: \.lineStartDecorator, icon: "fluent-ic_fluent_arrow_move_20_regular",
                                       tooltip: "Start Decorator", component: component)
                    
                    lineDecoratorPicker("endDecorator", keyPath: \.lineEndDecorator, icon: "fluent-ic_fluent_arrow_move_20_regular",
                                       tooltip: "End Decorator", component: component)
                }
            }
            
        case .triangleShape:
            InspectorGroupBox(title: "Triangle", icon: "fluent-ic_fluent_triangle_20_regular") {
                InspectorControlGroup {
                    factory.picker("direction", keyPath: \.triangleDirection, icon: "fluent-ic_fluent_match_app_layout_20_regular",
                                  tooltip: "Direction") { $0.rawValue.capitalized }
                    
                    factory.button("reset", icon: "fluent-ic_fluent_options_20_regular", tooltip: "Reset Direction", title: "Reset") {
                        self.document.updateComponentStyle(for: component.id, actionName: "Reset Direction") { $0.triangleDirection = .up }
                    }
                }
            }
            
        case .starShape:
            InspectorGroupBox(title: "Star", icon: "fluent-ic_fluent_star_20_regular") {
                InspectorControlGroup {
                    factory.stepper("points", keyPath: \.starPoints, icon: "fluent-ic_fluent_square_hint_20_regular",
                                   tooltip: "Points", range: 3...20, step: 1)
                    
                    factory.stepper("smoothness", keyPath: \.starSmoothness, icon: "fluent-ic_fluent_blur_20_regular",
                                   tooltip: "Smoothness", range: 0...1, step: 0.05, suffix: "%", format: .decimal(places: 0))
                    
                    factory.stepper("innerRatio", keyPath: \.starInnerRatio, icon: "fluent-ic_fluent_scale_fit_20_regular",
                                   tooltip: "Inner Ratio", range: 0.1...0.9, step: 0.05, suffix: "%", format: .decimal(places: 0))
                }
            }
            
        default:
            EmptyView()
        }
    }
    
    /// Helper for line decorator pickers that use wrapper type conversion
    private func lineDecoratorPicker(_ id: String, keyPath: WritableKeyPath<ComponentStyle, LineDecorator>,
                                     icon: String, tooltip: String, component: InvoiceComponent) -> InspectorControl {
        let binding = Binding<LineDecoratorOption>(
            get: { LineDecoratorOption(styleValue: component.style[keyPath: keyPath]) },
            set: { newValue in
                document.updateComponentStyle(for: component.id, actionName: "Change Line Decorator") { style in
                    style[keyPath: keyPath] = newValue.styleValue
                }
            }
        )
        return .picker(id, icon: icon, tooltip: tooltip, selection: binding) { $0.rawValue }
    }
}

// MARK: - Preview

#Preview("Shape Inspector - Line Controls") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    @Previewable @State var thickness: Double = 2
    @Previewable @State var lineStyle = "Solid"
    @Previewable @State var startDecorator = "None"
    @Previewable @State var endDecorator = "Arrow"
    
    VStack(spacing: 16) {
        InspectorGroupBox(title: "Line", icon: "fluent-ic_fluent_inking_tool_20_regular") {
            InspectorGrid {
                InspectorControl.stepper("thickness", icon: "fluent-ic_fluent_line_thickness_20_regular",
                                        tooltip: "Thickness", value: $thickness, range: 0.5...20, step: 0.5, suffix: "pt")
                
                InspectorControl.picker("lineStyle", icon: "fluent-ic_fluent_line_style_20_regular",
                                       tooltip: "Line Style", selection: $lineStyle) {
                    Text("Solid").tag("Solid")
                    Text("Dashed").tag("Dashed")
                    Text("Dotted").tag("Dotted")
                }
                
                InspectorControl.picker("startDecorator", icon: "fluent-ic_fluent_arrow_move_20_regular",
                                       tooltip: "Start Decorator", selection: $startDecorator) {
                    ForEach(["None", "Arrow", "Circle", "Square"], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                
                InspectorControl.picker("endDecorator", icon: "fluent-ic_fluent_arrow_move_20_regular",
                                       tooltip: "End Decorator", selection: $endDecorator) {
                    ForEach(["None", "Arrow", "Circle", "Square"], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        // Preview line
        Line(
            startDecorator: LineDecorator(rawValue: startDecorator.lowercased()) ?? .none,
            endDecorator: LineDecorator(rawValue: endDecorator.lowercased()) ?? .arrow,
            thickness: thickness
        )
        .stroke(Color.primary, lineWidth: thickness)
        .frame(width: 150, height: 30)
    }
    .frame(width: 280)
    .padding()
    .onAppear { context.expandedID = "Line" }
}

#Preview("Shape Inspector - Star Controls") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    @Previewable @State var points: Double = 5
    @Previewable @State var smoothness: Double = 0.5
    @Previewable @State var innerRatio: Double = 0.4
    
    VStack(spacing: 16) {
        InspectorGroupBox(title: "Star", icon: "fluent-ic_fluent_star_20_regular") {
            InspectorGrid {
                InspectorControl.stepper("points", icon: "fluent-ic_fluent_square_hint_20_regular",
                                        tooltip: "Points", value: $points, range: 3...20, step: 1)
                
                InspectorControl.stepper("smoothness", icon: "fluent-ic_fluent_blur_20_regular",
                                        tooltip: "Smoothness", value: $smoothness, range: 0...1, step: 0.05, suffix: "%", format: .decimal(places: 0))
                
                InspectorControl.stepper("innerRatio", icon: "fluent-ic_fluent_scale_fit_20_regular",
                                        tooltip: "Inner Ratio", value: $innerRatio, range: 0.1...0.9, step: 0.05, suffix: "%", format: .decimal(places: 0))
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        // Preview star
        Star(points: Int(points), smoothness: smoothness)
            .fill(Color.yellow)
            .frame(width: 80, height: 80)
    }
    .frame(width: 280)
    .padding()
    .onAppear { context.expandedID = "Star" }
}

#Preview("Shape Inspector - Triangle Controls") {
    @Previewable @StateObject var context = InspectorAccordionContext()
    @Previewable @State var direction = TriangleDirection.up
    
    VStack(spacing: 16) {
        InspectorGroupBox(title: "Triangle", icon: "fluent-ic_fluent_triangle_20_regular") {
            InspectorGrid {
                InspectorControl.picker("direction", icon: "fluent-ic_fluent_match_app_layout_20_regular",
                                       tooltip: "Direction", selection: $direction) {
                    ForEach(TriangleDirection.allCases, id: \.self) { dir in
                        Text(dir.rawValue.capitalized).tag(dir)
                    }
                }
                
                InspectorControl.button("reset", icon: "fluent-ic_fluent_options_20_regular",
                                       tooltip: "Reset Direction", title: "Reset", action: {
                                        direction = .up
                                       })
            }
        }
        .environment(\.inspectorAccordionContext, context)
        
        // Preview triangle
        Triangle(direction: direction)
            .fill(Color.green)
            .frame(width: 60, height: 60)
    }
    .frame(width: 280)
    .padding()
    .onAppear { context.expandedID = "Triangle" }
}
