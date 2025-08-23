import SwiftUI

// MARK: - Reusable Property Editor Components

struct SliderPropertyEditor: View {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: formatter, value))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { onChange(CGFloat($0)) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
            .accentColor(.accentColor)
        }
    }
}

struct ColorPropertyEditor: View {
    let title: String
    let color: Color
    let hexColor: String
    let onChange: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 8) {
                ColorPicker("", selection: Binding(
                    get: { color },
                    set: { newColor in
                        onChange(newColor.toHex())
                    }
                ))
                .frame(width: 32, height: 32)
                
                TextField("Hex Color", text: Binding(
                    get: { "#\(hexColor)" },
                    set: { newValue in
                        let hex = newValue.replacingOccurrences(of: "#", with: "")
                        onChange(hex)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            }
        }
    }
}

struct PickerPropertyEditor<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    let selection: T
    let onChange: (T) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker(title, selection: Binding(
                get: { selection },
                set: { onChange($0) }
            )) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct TogglePropertyEditor: View {
    let title: String
    let isOn: Bool
    let onChange: (Bool) -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { onChange($0) }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.8)
        }
    }
}

struct TextFieldPropertyEditor: View {
    let title: String
    let text: String
    let placeholder: String
    let width: CGFloat?
    let onChange: (String) -> Void
    
    init(
        title: String,
        text: String,
        placeholder: String = "",
        width: CGFloat? = nil,
        onChange: @escaping (String) -> Void
    ) {
        self.title = title
        self.text = text
        self.placeholder = placeholder
        self.width = width
        self.onChange = onChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            TextField(placeholder, text: Binding(
                get: { text },
                set: { onChange($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
        }
    }
}

struct NumberFieldPropertyEditor: View {
    let title: String
    let value: CGFloat
    let placeholder: String
    let width: CGFloat?
    let onChange: (CGFloat) -> Void
    
    init(
        title: String,
        value: CGFloat,
        placeholder: String = "",
        width: CGFloat? = nil,
        onChange: @escaping (CGFloat) -> Void
    ) {
        self.title = title
        self.value = value
        self.placeholder = placeholder
        self.width = width
        self.onChange = onChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            TextField(placeholder, text: Binding(
                get: { String(format: "%.1f", value) },
                set: { newValue in
                    if let number = Double(newValue) {
                        onChange(CGFloat(number))
                    }
                }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
        }
    }
}

// MARK: - Component Preview View

struct ComponentPreviewView: View {
    let component: InvoiceComponent
    
    var body: some View {
        Group {
            switch component.type {
            case .companyName:
                Text("ACME CORPORATION")
                    .font(.system(size: min(component.style.fontSize, 12), weight: component.style.fontWeightValue))
                    .foregroundColor(component.style.textColorSwiftUI)
                    .multilineTextAlignment(component.style.textAlignment.swiftUIAlignment)
            case .companyLogo:
                if let imageData = component.style.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: component.style.imageContentMode == .fit ? .fit : .fill)
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            case .companyABN:
                Text("12 345 678 901")
                    .font(.system(size: min(component.style.fontSize, 10), weight: component.style.fontWeightValue))
                    .foregroundColor(component.style.textColorSwiftUI)
            case .companyEmail:
                Text("contact@company.com")
                    .font(.system(size: min(component.style.fontSize, 10), weight: component.style.fontWeightValue))
                    .foregroundColor(component.style.textColorSwiftUI)
            case .invoiceNumberAndDates, .billTo, .participant, .totals, .paymentDetails:
                Text("Sample Content")
                    .font(.system(size: min(component.style.fontSize, 10), weight: component.style.fontWeightValue))
                    .foregroundColor(component.style.textColorSwiftUI)
            case .paymentTerms:
                Text("Payment due within 30 days")
                    .font(.system(size: min(component.style.fontSize, 10), weight: component.style.fontWeightValue))
                    .foregroundColor(component.style.textColorSwiftUI)
            case .invoiceTitle:
                Text("TAX INVOICE")
                    .font(.system(size: min(component.style.fontSize, 12), weight: component.style.fontWeightValue))
                    .foregroundColor(component.style.textColorSwiftUI)
            case .notes:
                Text("Payment is due within 30 days...")
                    .font(.system(size: min(component.style.fontSize, 9), weight: component.style.fontWeightValue))
                    .foregroundColor(component.style.textColorSwiftUI)
            case .textBox:
                Text(component.title ?? "Text")
                    .font(.system(size: min(component.style.fontSize, 10), weight: component.style.fontWeightValue))
                    .foregroundColor(component.style.textColorSwiftUI)
            case .rectangleShape:
                RoundedRectangle(cornerRadius: component.style.cornerRadius)
                    .fill(component.style.backgroundColorSwiftUI.opacity(component.style.backgroundOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: component.style.cornerRadius)
                            .stroke(component.style.borderColorSwiftUI, style: component.style.borderStrokeStyle)
                    )
            case .ellipseShape:
                Ellipse()
                    .fill(component.style.backgroundColorSwiftUI.opacity(component.style.backgroundOpacity))
                    .overlay(
                        Ellipse()
                            .stroke(component.style.borderColorSwiftUI, style: component.style.borderStrokeStyle)
                    )
            case .lineShape:
                Line(startDecorator: component.style.lineStartDecorator, endDecorator: component.style.lineEndDecorator, thickness: component.style.lineThickness)
                    .stroke(component.style.borderColorSwiftUI, lineWidth: component.style.lineThickness)
            case .triangleShape:
                Triangle(direction: component.style.triangleDirection)
                    .fill(component.style.backgroundColorSwiftUI.opacity(component.style.backgroundOpacity))
                    .overlay(
                        Triangle(direction: component.style.triangleDirection)
                            .stroke(component.style.borderColorSwiftUI, style: component.style.borderStrokeStyle)
                    )
            case .starShape:
                Star(points: component.style.starPoints, smoothness: component.style.starSmoothness)
                    .fill(component.style.backgroundColorSwiftUI.opacity(component.style.backgroundOpacity))
                    .overlay(
                        Star(points: component.style.starPoints, smoothness: component.style.starSmoothness)
                            .stroke(component.style.borderColorSwiftUI, style: component.style.borderStrokeStyle)
                    )
            case .imagePlaceholder:
                if let imageData = component.style.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: component.style.imageContentMode == .fit ? .fit : .fill)
                } else {
                    ImagePlaceholder()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .foregroundColor(component.style.borderColorSwiftUI)
                }
            case .servicesTable:
                VStack(spacing: 2) {
                    if component.style.showTableHeader {
                        HStack {
                            Text("Service").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Qty").frame(width: 20)
                            Text("Rate").frame(width: 25)
                            Text("Amt").frame(width: 25, alignment: .trailing)
                        }
                        .font(.system(size: 8, weight: .bold))
                        .padding(2)
                        .background(Color(hex: component.style.tableHeaderColor))
                        .foregroundColor(Color(hex: component.style.tableTextColor))
                    }
                    
                    ForEach(0..<2) { i in
                        HStack {
                            Text("Service \(i + 1)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("1").frame(width: 20)
                            Text("$50").frame(width: 25)
                            Text("$50").frame(width: 25, alignment: .trailing)
                        }
                        .font(.system(size: 8))
                        .padding(2)
                        .background(
                            component.style.useAlternatingRows && i % 2 == 1
                                ? Color(hex: component.style.tableRowAltColor)
                                : Color(hex: component.style.tableRowColor)
                        )
                        .foregroundColor(Color(hex: component.style.tableTextColor))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(component.style.backgroundColorSwiftUI.opacity(component.style.backgroundOpacity))
        .overlay(
            RoundedRectangle(cornerRadius: component.style.cornerRadius)
                .stroke(component.style.borderColorSwiftUI, style: component.style.borderStrokeStyle)
        )
        .shadow(
            color: component.style.shadowEnabled ? component.style.shadowColorSwiftUI : Color.clear,
            radius: component.style.shadowRadius,
            x: component.style.shadowOffsetX,
            y: component.style.shadowOffsetY
        )
    }
}

struct ShadowOffsetEditor: View {
    let offsetX: CGFloat
    let offsetY: CGFloat
    let onChange: (CGFloat, CGFloat) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shadow Offset")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("X: \(Int(offsetX))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { Double(offsetX) },
                            set: { onChange(CGFloat($0), offsetY) }
                        ),
                        in: -10...10,
                        step: 1
                    )
                    .accentColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Y: \(Int(offsetY))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { Double(offsetY) },
                            set: { onChange(offsetX, CGFloat($0)) }
                        ),
                        in: -10...10,
                        step: 1
                    )
                    .accentColor(.accentColor)
                }
            }
        }
    }
}

struct PropertySection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            content
        }
    }
}

// MARK: - Helper Extensions for Property Editors

extension InspectorView {
    func sliderProperty(
        title: String,
        value: CGFloat,
        range: ClosedRange<CGFloat>,
        step: CGFloat = 1,
        formatter: String = "%.0f",
        onChange: @escaping (CGFloat) -> Void
    ) -> some View {
        SliderPropertyEditor(
            title: title,
            value: value,
            range: range,
            step: step,
            formatter: formatter,
            onChange: onChange
        )
    }
    
    func colorProperty(
        title: String,
        color: Color,
        hexColor: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        ColorPropertyEditor(
            title: title,
            color: color,
            hexColor: hexColor,
            onChange: onChange
        )
    }
    
    func toggleProperty(
        title: String,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        TogglePropertyEditor(
            title: title,
            isOn: isOn,
            onChange: onChange
        )
    }
}
