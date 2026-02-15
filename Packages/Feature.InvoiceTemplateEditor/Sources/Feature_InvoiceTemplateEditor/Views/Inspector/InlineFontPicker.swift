import SwiftUI
import CoreText
import Core
import SharedUI

// MARK: - Inline Font Picker

/// Compact font picker UI with CoreText attributes and Fluent UI icons.
struct InlineFontPicker: View {
    @Binding var configuration: FontPickerConfiguration
    
    @State var availableFamilies: [String] = []
    @State var fontCapabilities: FontFamilyCapabilities = .default
    
    var body: some View {
        Group {
            InspectorGroupBox(title: "Font", icon: "textformat") {
                InspectorGrid {
                    fontFamilyControl
                    fontSizeControl
                    fontWeightControl
                    fontWidthControl
                }
            }
            
            InspectorGroupBox(title: "Style", icon: "paintbrush") {
                InspectorGrid {
                    textColorControl
                    italicControl
                    alignmentControl
                    textTransformControl
                    opacityControl
                }
            }
            
            InspectorGroupBox(title: "Decoration", icon: "underline") {
                InspectorGrid {
                    underlineStyleControl
                    underlinePatternControl
                    underlineColorControl
                    kerningControl
                }
            }
        }
        .onAppear { loadFonts() }
        .onChange(of: configuration.fontFamily) { _, newFamily in
            updateCapabilities(for: newFamily)
        }
    }
    
    // MARK: - Font Loading
    
    func loadFonts() {
        let families = CTFontManagerCopyAvailableFontFamilyNames()
        availableFamilies = (families as? [String])?.sorted() ?? []
        if !availableFamilies.contains("system") {
            availableFamilies.insert("system", at: 0)
        }
        updateCapabilities(for: configuration.fontFamily)
    }
    
    func updateCapabilities(for family: String) {
        fontCapabilities = FontCapabilityDetector.getCapabilities(for: family)
        
        if !fontCapabilities.availableWeights.contains(configuration.fontWeight) {
            configuration.fontWeight = fontCapabilities.availableWeights.first ?? "regular"
        }
        if configuration.fontWidth == "condensed" && !fontCapabilities.hasCondensed {
            configuration.fontWidth = "standard"
        }
        if configuration.fontWidth == "expanded" && !fontCapabilities.hasExpanded {
            configuration.fontWidth = "standard"
        }
        if configuration.italic && !fontCapabilities.hasItalic {
            configuration.italic = false
        }
    }
}

// MARK: - Preview

#Preview("InlineFontPicker") {
    struct PreviewWrapper: View {
        @State private var config = FontPickerConfiguration()
        
        var body: some View {
            ScrollView {
                InlineFontPicker(configuration: $config)
                    .inspectorAccordion(defaultExpanded: "Font")
            }
            .frame(width: 280, height: 500)
        }
    }
    return PreviewWrapper()
}

