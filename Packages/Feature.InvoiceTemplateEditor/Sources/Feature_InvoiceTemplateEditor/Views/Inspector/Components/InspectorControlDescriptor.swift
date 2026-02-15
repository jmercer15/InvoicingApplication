import SwiftUI
import SharedUI

// MARK: - Inspector Control Types

/// Type-erased container for inspector control configurations.
/// Enables declarative control definitions that reduce 10-15 lines to 1-2 lines.
@MainActor
struct InspectorControl: View, Identifiable, Sendable {
    let id: String
    let icon: String
    let tooltip: String
    private let _render: @MainActor @Sendable () -> AnyView
    
    var body: some View {
        _render()
    }
    
    private init(id: String, icon: String, tooltip: String, render: @escaping @MainActor @Sendable () -> AnyView) {
        self.id = id
        self.icon = icon
        self.tooltip = tooltip
        self._render = render
    }
}

// MARK: - Factory Methods

extension InspectorControl {
    /// Creates a stepper control
    static func stepper(
        _ id: String,
        icon: String,
        tooltip: String,
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        suffix: String = "pt",
        format: InspectorStepper.FormatStyle = .integer
    ) -> InspectorControl {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    InspectorStepper(value: value, in: range, step: step, suffix: suffix, format: format)
                }
            )
        }
    }
    
    /// Creates a color picker control
    static func color(
        _ id: String,
        icon: String,
        tooltip: String,
        selection: Binding<Color>
    ) -> InspectorControl {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    ColorPicker(selection: selection) { EmptyView() }
                }
            )
        }
    }
    
    /// Creates a toggle control
    static func toggle(
        _ id: String,
        icon: String,
        tooltip: String,
        isOn: Binding<Bool>
    ) -> InspectorControl {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    Toggle("", isOn: isOn).labelsHidden()
                }
            )
        }
    }
    
    /// Creates a text field control
    static func text(
        _ id: String,
        icon: String,
        tooltip: String,
        text: Binding<String>
    ) -> InspectorControl {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    InspectorTextField(text: text)
                }
            )
        }
    }
    
    /// Creates a color picker control
    static func colorPicker(
        _ id: String,
        icon: String,
        tooltip: String,
        selection: Binding<Color>
    ) -> InspectorControl {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    ColorPicker("", selection: selection)
                        .labelsHidden()
                }
            )
        }
    }
    
    /// Creates a picker control with custom content
    static func picker<Selection: Hashable, Content: View>(
        _ id: String,
        icon: String,
        tooltip: String,
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping () -> Content
    ) -> InspectorControl {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    Picker("", selection: selection) {
                        content()
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            )
        }
    }

    /// Creates a button control
    static func button(
        _ id: String,
        icon: String,
        tooltip: String,
        title: String,
        action: @escaping @MainActor () -> Void
    ) -> InspectorControl {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    Button(title, action: action)
                        .buttonStyle(.bordered)
                }
            )
        }
    }
    
    /// Creates a picker control for any CaseIterable & Hashable type
    static func picker<T: Hashable & CaseIterable>(
        _ id: String,
        icon: String,
        tooltip: String,
        selection: Binding<T>,
        label: @escaping @Sendable (T) -> String = { "\($0)" }
    ) -> InspectorControl where T.AllCases: RandomAccessCollection {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    Picker("", selection: selection) {
                        ForEach(Array(T.allCases), id: \.self) { option in
                            Text(label(option)).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            )
        }
    }
    
    /// Creates a picker control with explicit options array
    static func picker<T: Hashable>(
        _ id: String,
        icon: String,
        tooltip: String,
        selection: Binding<T>,
        options: [T],
        label: @escaping @Sendable (T) -> String = { "\($0)" }
    ) -> InspectorControl {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    Picker("", selection: selection) {
                        ForEach(options, id: \.self) { option in
                            Text(label(option)).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            )
        }
    }
}

// MARK: - Control Group View

/// Renders a group of inspector controls in an InspectorGrid
struct InspectorControlGroup: View {
    let controls: [InspectorControl]
    
    init(@InspectorControlBuilder _ builder: () -> [InspectorControl]) {
        self.controls = builder()
    }
    
    init(controls: [InspectorControl]) {
        self.controls = controls
    }
    
    var body: some View {
        InspectorGrid {
            ForEach(controls) { control in
                control.body
            }
        }
    }
}

// MARK: - Result Builder

@resultBuilder
struct InspectorControlBuilder {
    static func buildBlock(_ components: [InspectorControl]...) -> [InspectorControl] {
        components.flatMap { $0 }
    }
    
    static func buildOptional(_ component: [InspectorControl]?) -> [InspectorControl] {
        component ?? []
    }
    
    static func buildEither(first component: [InspectorControl]) -> [InspectorControl] {
        component
    }
    
    static func buildEither(second component: [InspectorControl]) -> [InspectorControl] {
        component
    }
    
    static func buildArray(_ components: [[InspectorControl]]) -> [InspectorControl] {
        components.flatMap { $0 }
    }
    
    static func buildExpression(_ expression: InspectorControl) -> [InspectorControl] {
        [expression]
    }
    
    static func buildExpression(_ expression: [InspectorControl]) -> [InspectorControl] {
        expression
    }
}

// MARK: - Component-Bound Inspector Control Factory

/// Factory for creating inspector controls bound to a specific component.
/// This enables concise, keyPath-based control declarations.
@MainActor
struct ComponentInspectorControlFactory {
    let component: InvoiceComponent
    let document: InvoiceDocument
    
    /// Creates a stepper control bound to a CGFloat property
    func stepper(
        _ id: String,
        keyPath: WritableKeyPath<ComponentStyle, CGFloat>,
        icon: String,
        tooltip: String,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        suffix: String = "pt",
        format: InspectorStepper.FormatStyle = .integer
    ) -> InspectorControl {
        let componentId = component.id
        let binding = Binding<Double>(
            get: { Double(self.component.style[keyPath: keyPath]) },
            set: { newValue in
                self.document.updateComponentStyle(for: componentId, actionName: "Change \(tooltip)") { style in
                    style[keyPath: keyPath] = CGFloat(newValue)
                }
            }
        )
        return .stepper(id, icon: icon, tooltip: tooltip, value: binding, range: range, step: step, suffix: suffix, format: format)
    }
    
    /// Creates a stepper control bound to an optional CGFloat property
    func stepper(
        _ id: String,
        keyPath: WritableKeyPath<ComponentStyle, CGFloat?>,
        icon: String,
        tooltip: String,
        defaultValue: CGFloat = 0,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        suffix: String = "pt",
        format: InspectorStepper.FormatStyle = .integer
    ) -> InspectorControl {
        let componentId = component.id
        let binding = Binding<Double>(
            get: { Double(self.component.style[keyPath: keyPath] ?? defaultValue) },
            set: { newValue in
                self.document.updateComponentStyle(for: componentId, actionName: "Change \(tooltip)") { style in
                    style[keyPath: keyPath] = CGFloat(newValue)
                }
            }
        )
        return .stepper(id, icon: icon, tooltip: tooltip, value: binding, range: range, step: step, suffix: suffix, format: format)
    }
    
    /// Creates a toggle control bound to a Bool property
    func toggle(
        _ id: String,
        keyPath: WritableKeyPath<ComponentStyle, Bool>,
        icon: String,
        tooltip: String
    ) -> InspectorControl {
        let componentId = component.id
        let binding = Binding<Bool>(
            get: { self.component.style[keyPath: keyPath] },
            set: { newValue in
                self.document.updateComponentStyle(for: componentId, actionName: "Toggle \(tooltip)") { style in
                    style[keyPath: keyPath] = newValue
                }
            }
        )
        return .toggle(id, icon: icon, tooltip: tooltip, isOn: binding)
    }
    
    /// Creates a color picker control bound to a SwiftUI Color computed property
    func color(
        _ id: String,
        colorKeyPath: WritableKeyPath<ComponentStyle, String>,
        swiftUIKeyPath: KeyPath<ComponentStyle, Color>,
        icon: String,
        tooltip: String
    ) -> InspectorControl {
        let componentId = component.id
        let binding = Binding<Color>(
            get: { self.component.style[keyPath: swiftUIKeyPath] },
            set: { newColor in
                self.document.updateComponentStyle(for: componentId, actionName: "Change \(tooltip)") { style in
                    style[keyPath: colorKeyPath] = newColor.toHex()
                }
            }
        )
        return .color(id, icon: icon, tooltip: tooltip, selection: binding)
    }
    
    /// Creates a picker control bound to a CaseIterable property
    func picker<T: Hashable & CaseIterable>(
        _ id: String,
        keyPath: WritableKeyPath<ComponentStyle, T>,
        icon: String,
        tooltip: String,
        label: @escaping @Sendable (T) -> String = { "\($0)" }
    ) -> InspectorControl where T.AllCases: RandomAccessCollection {
        let componentId = component.id
        let binding = Binding<T>(
            get: { self.component.style[keyPath: keyPath] },
            set: { newValue in
                self.document.updateComponentStyle(for: componentId, actionName: "Change \(tooltip)") { style in
                    style[keyPath: keyPath] = newValue
                }
            }
        )
        return .picker(id, icon: icon, tooltip: tooltip, selection: binding, label: label)
    }
    
    /// Creates a stepper control bound to an Int property
    func stepper(
        _ id: String,
        keyPath: WritableKeyPath<ComponentStyle, Int>,
        icon: String,
        tooltip: String,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        suffix: String = ""
    ) -> InspectorControl {
        let componentId = component.id
        let binding = Binding<Double>(
            get: { Double(self.component.style[keyPath: keyPath]) },
            set: { newValue in
                self.document.updateComponentStyle(for: componentId, actionName: "Change \(tooltip)") { style in
                    style[keyPath: keyPath] = Int(newValue)
                }
            }
        )
        return .stepper(id, icon: icon, tooltip: tooltip, value: binding, range: range, step: step, suffix: suffix, format: .integer)
    }
    
    /// Creates a button control with an action
    func button(
        _ id: String,
        icon: String,
        tooltip: String,
        title: String,
        action: @escaping @MainActor () -> Void
    ) -> InspectorControl {
        .button(id, icon: icon, tooltip: tooltip, title: title, action: action)
    }
}

