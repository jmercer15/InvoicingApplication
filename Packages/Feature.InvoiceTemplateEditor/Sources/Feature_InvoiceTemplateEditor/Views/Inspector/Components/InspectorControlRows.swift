import SwiftUI

struct InspectorTextFieldRow: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var numeric: Bool = false
    var formatter: Formatter?

    var body: some View {
        ControlRowContainer {
            LabeledContent {
                if numeric {
                    TextField(
                        placeholder,
                        value: Binding(
                            get: { Double(text) ?? 0 },
                            set: { text = String($0) }
                        ),
                        formatter: formatter ?? NumberFormatter()
                    )
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .controlValueStyle(numeric: true)
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.roundedBorder)
                        .controlValueStyle()
                }
            } label: {
                Text(label)
                    .controlLabelStyle()
            }
        }
    }
}

struct InspectorToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        ControlRowContainer {
            LabeledContent {
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .controlLabelStyle()
            }
        }
    }
}

struct InspectorButtonRow: View {
    let label: String
    let title: String
    let action: () -> Void

    var body: some View {
        ControlRowContainer {
            LabeledContent {
                Button(title, action: action)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 6)
            } label: {
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .controlLabelStyle()
            }
        }
    }
}

struct InspectorColorPickerRow: View {
    let label: String
    @Binding var color: Color

    var body: some View {
        ControlRowContainer {
            LabeledContent {
                ColorPicker("", selection: $color)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .controlLabelStyle()
            }
        }
    }
}

struct InspectorLabeledRow<Content: View>: View {
    let label: String
    let content: () -> Content

    var body: some View {
        ControlRowContainer {
            LabeledContent {
                content()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .controlLabelStyle()
            }
        }
    }
}

struct InspectorRow<Content: View>: View {
    let content: () -> Content

    var body: some View {
        ControlRowContainer {
            content()
                .frame(maxWidth: .infinity)
        }
    }
}

struct InspectorAlignmentGridRow: View {
    let label: String
    @Binding var horizontalAlignment: TextAlignment
    @Binding var verticalAlignment: VerticalAlignment

    var body: some View {
        ControlRowContainer {
            LabeledContent {
                AlignmentGridPicker(
                    label: label,
                    horizontalAlignment: $horizontalAlignment,
                    verticalAlignment: $verticalAlignment
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            } label: {
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .controlLabelStyle()
                    .padding(.top, 4)
            }
        }
    }
}

struct InspectorStepperRow<Value: Strideable>: View where Value.Stride: BinaryFloatingPoint {
    let label: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value.Stride

    var body: some View {
        ControlRowContainer {
            LabeledContent {
                Stepper(
                    value: $value,
                    in: range,
                    step: step
                ) {
                    Text("\(value)")
                        .controlValueStyle(numeric: true)
                }
            } label: {
                Text(label)
                    .controlLabelStyle()
            }
        }
    }
}

struct InspectorStepperFieldRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        ControlRowContainer {
            LabeledContent {
                Spacer()
                Stepper(
                    value: $value,
                    in: range,
                    step: step
                ) {
                    TextField(
                        "",
                        value: $value,
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .controlValueStyle(numeric: true)
                }
            } label: {
                Text(label)
                    .controlLabelStyle()
            }
        }
    }
}

struct InspectorPickerRow<Selection: Hashable, Options: RandomAccessCollection, RowView: View>: View where Options.Element == Selection {
    let label: String
    @Binding var selection: Selection
    let options: Options
    let makeLabel: (Selection) -> RowView

    init(
        label: String,
        selection: Binding<Selection>,
        options: Options,
        @ViewBuilder makeLabel: @escaping (Selection) -> RowView
    ) {
        self.label = label
        self._selection = selection
        self.options = options
        self.makeLabel = makeLabel
    }

    var body: some View {
        ControlRowContainer {
            Picker(label, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    makeLabel(option)
                        .tag(option)
                }
            }
        }
    }
}
