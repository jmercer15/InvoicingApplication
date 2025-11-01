import SwiftUI

// MARK: - Modern Property Editor Components
// Redesigned specifically for the new 6-section property editor layout

// MARK: - Compact Slider Editor
struct ModernSliderEditor: View {
    let title: String
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    let formatter: String
    let onChange: (CGFloat) -> Void

    init(
        title: String,
        value: CGFloat,
        range: ClosedRange<CGFloat>,
        step: CGFloat = 1,
        formatter: String = "%.0f",
        onChange: @escaping (CGFloat) -> Void
    ) {
        self.title = title
        self.value = value
        self.range = range
        self.step = step
        self.formatter = formatter
        self.onChange = onChange
    }

    var body: some View {
        Group {
            LabeledContent(title) {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { onChange(CGFloat($0)) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: Double(step)
                )
                .pointerStyle(.link)
                .accentColor(.accentColor)
                .controlSize(.mini)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
            
            LabeledContent("Value") {
                Text(String(format: formatter, value))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryText)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
        }
    }
}

// MARK: - Compact Toggle Editor
struct ModernToggleEditor: View {
    let title: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        LabeledContent(title) {
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { onChange($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Compact Color Editor
struct ModernColorEditor: View {
    let title: String
    let color: Color
    let hexColor: String
    let onChange: (String) -> Void

    var body: some View {
        Group {
            LabeledContent(title) {
                ColorPicker("", selection: Binding(
                    get: { color },
                    set: { newColor in
                        onChange(newColor.toHex())
                    }
                ))
                .labelsHidden()
                .controlSize(.mini)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
            
            LabeledContent("Hex Color") {
                TextField(
                    "",
                    text: Binding(
                        get: { hexColor },
                        set: { newValue in
                            let hex = newValue.replacingOccurrences(of: "#", with: "")
                            onChange(hex)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.regular)
                .pointerStyle(.horizontalText)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
        }
    }
}

// MARK: - Compact Picker Editor
struct ModernPickerEditor<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    let selection: T
    let onChange: (T) -> Void

    var body: some View {
        LabeledContent(title) {
            Picker("", selection: Binding(
                get: { selection },
                set: { onChange($0) }
            )) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.mini)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Compact Segmented Picker
struct ModernSegmentedPicker<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    let selection: T
    let onChange: (T) -> Void

    var body: some View {
        LabeledContent(title) {
            Picker("", selection: Binding(
                get: { selection },
                set: { onChange($0) }
            )) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.mini)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Compact Shadow Offset Editor
struct ModernShadowOffsetEditor: View {
    let offsetX: CGFloat
    let offsetY: CGFloat
    let onChange: (CGFloat, CGFloat) -> Void

    var body: some View {
        Group {
            LabeledContent("Offset X") {
                Slider(
                    value: Binding(
                        get: { Double(offsetX) },
                        set: { onChange(CGFloat($0), offsetY) }
                    ),
                    in: -10...10,
                    step: 1
                )
                .pointerStyle(.link)
                .accentColor(.accentColor)
                .controlSize(.mini)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
            
            LabeledContent("Offset X Value") {
                Text("\(Int(offsetX))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryText)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
            
            LabeledContent("Offset Y") {
                Slider(
                    value: Binding(
                        get: { Double(offsetY) },
                        set: { onChange(offsetX, CGFloat($0)) }
                    ),
                    in: -10...10,
                    step: 1
                )
                .pointerStyle(.link)
                .accentColor(.accentColor)
                .controlSize(.mini)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
            
            LabeledContent("Offset Y Value") {
                Text("\(Int(offsetY))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryText)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
        }
    }
}

// MARK: - Compact Grid Label Editor
struct ModernGridLabelEditor: View {
    let icon: String
    let title: String
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    let formatter: String
    let onChange: (CGFloat) -> Void

    init(
        icon: String,
        title: String,
        value: CGFloat,
        range: ClosedRange<CGFloat>,
        step: CGFloat = 1,
        formatter: String = "%.0f",
        onChange: @escaping (CGFloat) -> Void
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.range = range
        self.step = step
        self.formatter = formatter
        self.onChange = onChange
    }

    var body: some View {
        Group {
            LabeledContent(title) {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { onChange(CGFloat($0)) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: Double(step)
                )
                .pointerStyle(.link)
                .accentColor(.accentColor)
                .controlSize(.mini)
            }
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
            
            LabeledContent("Value") {
                Text(String(format: formatter, value))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryText)
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
        }
    }
}

// MARK: - Compact Color Grid Editor
struct ModernColorGridEditor: View {
    let label: String
    let color: Color
    let hexColor: String
    let onChange: (String) -> Void

    var body: some View {
        Group {
            LabeledContent(label) {
                ColorPicker("", selection: Binding(
                    get: { color },
                    set: { newColor in
                        onChange(newColor.toHex())
                    }
                ))
                .labelsHidden()
                .controlSize(.mini)
            }
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
            
            LabeledContent("Hex Color") {
                TextField(
                    "",
                    text: Binding(
                        get: { hexColor },
                        set: { newValue in
                            let hex = newValue.replacingOccurrences(of: "#", with: "")
                            onChange(hex)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.regular)
                .pointerStyle(.horizontalText)
            }
            .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
        }
    }
}
