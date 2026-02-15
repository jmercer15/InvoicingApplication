import SwiftUI
import Core
import SharedUI

// MARK: - Font Picker Controls

extension InlineFontPicker {
    
    // MARK: - Font Family
    
    @ViewBuilder
    var fontFamilyControl: some View {
        InspectorControl.picker("fontFamily", icon: "fluent-ic_fluent_text_20_regular",
                               tooltip: "Font Family", selection: $configuration.fontFamily) {
            ForEach(availableFamilies, id: \.self) { Text($0).tag($0) }
        }
    }
    
    // MARK: - Font Size
    
    @ViewBuilder
    var fontSizeControl: some View {
        InspectorControl.stepper("fontSize", icon: "fluent-ic_fluent_font_increase_20_regular",
                                tooltip: "Font Size", value: Binding(
                                    get: { Double(configuration.fontSize) },
                                    set: { configuration.fontSize = CGFloat($0) }
                                ), range: 6...200, step: 1, suffix: "pt", format: .integer)
    }
    
    // MARK: - Font Weight
    
    @ViewBuilder
    var fontWeightControl: some View {
        InspectorControl.picker("fontWeight", icon: "fluent-ic_fluent_text_bold_20_regular",
                               tooltip: "Font Weight", selection: $configuration.fontWeight) {
            ForEach(fontCapabilities.availableWeights, id: \.self) {
                Text($0.capitalized).tag($0)
            }
        }
    }
    
    // MARK: - Font Width
    
    @ViewBuilder
    var fontWidthControl: some View {
        if fontCapabilities.hasCondensed || fontCapabilities.hasExpanded {
            InspectorControl.picker("fontWidth", icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                   tooltip: "Font Width", selection: $configuration.fontWidth) {
                if fontCapabilities.hasCondensed { Text("Condensed").tag("condensed") }
                Text("Standard").tag("standard")
                if fontCapabilities.hasExpanded { Text("Expanded").tag("expanded") }
            }
        } else {
            Color.clear.frame(height: 1)
        }
    }
    
    // MARK: - Text Color
    
    // MARK: - Text Color
    
    @ViewBuilder
    var textColorControl: some View {
        InspectorControl.colorPicker("textColor", icon: "fluent-ic_fluent_text_color_20_regular",
                                   tooltip: "Text Color", selection: Binding(
                                    get: { Color(hex: configuration.foregroundColor) ?? .black },
                                    set: { configuration.foregroundColor = $0.toHex() }
                                   ))
    }
    
    // MARK: - Italic
    
    var italicControl: some View {
        InspectorControl.toggle("italic", icon: "fluent-ic_fluent_text_italic_20_regular",
                               tooltip: "Italic", isOn: $configuration.italic)
            .disabled(!fontCapabilities.hasItalic)
    }
    
    // MARK: - Alignment
    
    @ViewBuilder
    var alignmentControl: some View {
        InspectorControl.picker("alignment", icon: "fluent-ic_fluent_text_align_left_20_regular",
                               tooltip: "Text Alignment", selection: $configuration.alignment) {
            InspectorIcon("fluent-ic_fluent_text_align_left_20_regular", tooltip: "Align Left", showLabel: false).tag(TextAlignment.leading)
            InspectorIcon("fluent-ic_fluent_text_align_center_20_regular", tooltip: "Align Center", showLabel: false).tag(TextAlignment.center)
            InspectorIcon("fluent-ic_fluent_text_align_right_20_regular", tooltip: "Align Right", showLabel: false).tag(TextAlignment.trailing)
        }
    }
    
    // MARK: - Text Transform
    
    @ViewBuilder
    var textTransformControl: some View {
        InspectorControl.picker("textTransform", icon: "fluent-ic_fluent_text_case_title_20_regular",
                               tooltip: "Text Transform", selection: $configuration.textTransform) {
            HStack { Image("fluent-ic_fluent_text_case_title_20_regular", bundle: .module); Text("None") }.tag(TextTransform.none)
            HStack { Image("fluent-ic_fluent_text_case_uppercase_20_regular", bundle: .module); Text("Uppercase") }.tag(TextTransform.uppercase)
            HStack { Image("fluent-ic_fluent_text_case_lowercase_20_regular", bundle: .module); Text("Lowercase") }.tag(TextTransform.lowercase)
            HStack { Image("fluent-ic_fluent_text_font_20_regular", bundle: .module); Text("Capitalize") }.tag(TextTransform.capitalize)
        }
    }
    
    // MARK: - Opacity
    
    var opacityControl: some View {
        InspectorControl.stepper("opacity", icon: "fluent-ic_fluent_circle_half_fill_20_regular",
                                tooltip: "Text Opacity", 
                                value: Binding(
                                    get: { Double(configuration.opacity) },
                                    set: { configuration.opacity = CGFloat($0) }
                                ),
                                range: 0...1, step: 0.1, suffix: "%", format: .decimal(places: 0))
    }
    
    // MARK: - Underline Style
    
    @ViewBuilder
    var underlineStyleControl: some View {
        InspectorControl.picker("underlineStyle", icon: "fluent-ic_fluent_text_underline_20_regular",
                               tooltip: "Underline Style", selection: $configuration.underlineStyle) {
            Text("None").tag(0)
            Text("Single").tag(1)
            Text("Thick").tag(2)
            Text("Double").tag(9)
        }
    }
    
    // MARK: - Underline Pattern
    
    @ViewBuilder
    var underlinePatternControl: some View {
        InspectorControl.picker("underlinePattern", icon: "fluent-ic_fluent_line_style_20_regular",
                               tooltip: "Underline Pattern", selection: $configuration.underlinePattern) {
            Text("Solid").tag(0)
            Text("Dot").tag(0x0100)
            Text("Dash").tag(0x0200)
            Text("Dash-Dot").tag(0x0300)
        }
        .disabled(configuration.underlineStyle == 0)
    }
    
    // MARK: - Underline Color
    
    @ViewBuilder
    var underlineColorControl: some View {
        if configuration.underlineStyle != 0 {
            InspectorControl.colorPicker("underlineColor", icon: "fluent-ic_fluent_color_fill_20_regular",
                                       tooltip: "Underline Color", selection: Binding(
                                        get: { Color(hex: configuration.underlineColor) ?? .black },
                                        set: { configuration.underlineColor = $0.toHex() }
                                       ))
        } else {
            Color.clear.frame(height: 1)
        }
    }
    
    // MARK: - Kerning
    
    @ViewBuilder
    var kerningControl: some View {
        InspectorControl.stepper("kerning", icon: "fluent-ic_fluent_font_space_tracking_out_20_regular",
                                tooltip: "Kerning", value: Binding(
                                    get: { Double(configuration.kerning) },
                                    set: { configuration.kerning = CGFloat($0) }
                                ), range: -10...20, step: 0.5, format: .decimal(places: 1))
    }
    
    // MARK: - Computed Properties
    
    var underlineStyleName: String {
        switch configuration.underlineStyle {
        case 0: return "None"
        case 1: return "Single"
        case 2: return "Thick"
        case 9: return "Double"
        default: return "Single"
        }
    }
    
    var underlinePatternName: String {
        switch configuration.underlinePattern {
        case 0: return "Solid"
        case 0x0100: return "Dot"
        case 0x0200: return "Dash"
        case 0x0300: return "Dash-Dot"
        default: return "Solid"
        }
    }
}
