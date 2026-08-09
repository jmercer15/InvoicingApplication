import Core
import PersistenceModels
import SwiftUI

extension InvoiceTemplateRibbon {
  @ViewBuilder
  func ribbonGroup<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    Section {
      Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
        content()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } header: {
      Label(title, systemImage: sectionIcon(for: title))
    }
  }

  @ViewBuilder
  func ribbonRow<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    GridRow {
      content()
    }
  }

  func sectionIcon(for title: String) -> String {
    switch title {
    case "Templates": "square.grid.2x2"
    case "Composition": "rectangle.3.group"
    case "Page Setup": "doc"
    case "Margins": "rectangle.inset.filled"
    case "Accent colour": "paintpalette"
    case "Typography": "textformat"
    case "Spacing": "arrow.up.and.down.text.horizontal"
    case "Rules": "line.3.horizontal"
    case "Party cards": "person.2"
    case "Payment cards": "creditcard"
    case "Invoice metadata": "list.bullet.rectangle"
    case "Header": "rectangle.topthird.inset.filled"
    case "Payments": "banknote"
    case "Document flow": "doc.text"
    case "Parties": "person.3"
    case "Provider details": "person.text.rectangle"
    case "Table style": "tablecells"
    case "Totals": "sum"
    case "Headings": "textformat.size"
    case "Columns": "rectangle.split.3x1"
    case "Amount format": "dollarsign.circle"
    default: "slider.horizontal.3"
    }
  }

  func ribbonPicker<Value: Hashable, OptionLabel: View>(
    _ title: String,
    selection: Binding<Value>,
    values: some RandomAccessCollection<Value>,
    @ViewBuilder label: @escaping (Value) -> OptionLabel
  ) -> some View {
    Picker(title, selection: selection) {
      ForEach(Array(values), id: \.self) { value in
        label(value).tag(value)
      }
    }
    .pickerStyle(.menu)
  }

  func concisePickerOption(
    _ title: String,
    accessibilityLabel: String,
    systemImage: String
  ) -> some View {
    Label(title, systemImage: systemImage)
      .accessibilityLabel(accessibilityLabel)
  }

  func ribbonPicker<Value: Hashable, OptionLabel: View>(
    _ title: String,
    selected: Value?,
    values: some RandomAccessCollection<Value>,
    @ViewBuilder label: @escaping (Value) -> OptionLabel,
    action: @escaping (Value) -> Void
  ) -> some View {
    Picker(
      title,
      selection: Binding(
        get: { selected },
        set: { value in
          if let value {
            action(value)
          }
        }
      )
    ) {
      Text("Custom").tag(Value?.none)
      ForEach(Array(values), id: \.self) { value in
        label(value).tag(Optional(value))
      }
    }
    .pickerStyle(.menu)
  }

  func toggle(_ title: String, image: String, isOn: Binding<Bool>) -> some View {
    Toggle(isOn: isOn) {
      Label(title, systemImage: image)
    }
    .toggleStyle(.checkbox)
  }

  @ViewBuilder
  func granularControl(
    _ title: String,
    value: Binding<Double>,
    inputID: String,
    range: ClosedRange<Double>,
    step: Double,
    suffix: String,
    resetAvailable: Bool = true,
    reset: (() -> Void)? = nil
  ) -> some View {
    let adjustmentBinding = Binding(
      get: { value.wrappedValue },
      set: { newValue in
        replaceNumericDraft(inputID) {
          if value.wrappedValue != newValue {
            value.wrappedValue = newValue
          }
        }
      }
    )
    GridRow {
      Slider(value: adjustmentBinding, in: range, step: step) {
        Text(title)
      }
    }
    GridRow {
      InvoiceValidatedDoubleField(
        "Value",
        value: value,
        inputID: inputID,
        validRange: range,
        draftStore: toolbarState.numericInputDrafts,
        resetRevision: toolbarState.numericInputResetRevision,
        onValidityChange: inputValidityChange
      )
        .accessibilityLabel("Exact \(title)")
      Text(suffix)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    GridRow {
      Stepper("Adjust", value: adjustmentBinding, in: range, step: step)
        .accessibilityLabel("Adjust \(title)")
      if let reset {
        Button("Preset", systemImage: "arrow.uturn.backward") {
          replaceNumericDraft(inputID, applying: reset)
        }
        .labelStyle(.titleAndIcon)
        .disabled(!resetAvailable)
        .help("Use the selected preset's \(title.lowercased())")
      }
    }
  }

  func geometryField(
    _ title: String,
    value: Binding<Double>,
    inputID: String,
    validRange: ClosedRange<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("\(title) (pt)")
        .font(.caption)
        .foregroundStyle(.secondary)
      InvoiceValidatedDoubleField(
        title,
        value: value,
        inputID: inputID,
        validRange: validRange,
        draftStore: toolbarState.numericInputDrafts,
        resetRevision: toolbarState.numericInputResetRevision,
        onValidityChange: inputValidityChange
      )
      .accessibilityLabel("\(title) in Points")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  func ribbonColorPicker(_ title: String, selection: Binding<Color>) -> some View {
    ColorPicker(title, selection: selection, supportsOpacity: true)
  }

  func applyTemplatePreset(_ preset: InvoiceTemplatePreset) {
    viewModel.applyTemplatePreset(preset)
    clearNumericInputDrafts()
  }

  func clearNumericInputDrafts() {
    for inputID in toolbarState.resetNumericInputDrafts() {
      inputValidityChange(inputID, false)
    }
  }

  var customAccentBinding: Binding<Color> {
    Binding(
      get: {
        if let color = viewModel.customAccentColor {
          return Color(red: color.red, green: color.green, blue: color.blue, opacity: color.opacity)
        }
        return viewModel.accentTheme.accentColor
      },
      set: { color in
        guard let resolved = NSColor(color).usingColorSpace(.sRGB) else { return }
        viewModel.customAccentColor = InvoiceCustomAccentColor(
          red: resolved.redComponent,
          green: resolved.greenComponent,
          blue: resolved.blueComponent,
          opacity: resolved.alphaComponent
        )
      }
    )
  }

  var accentThemeBinding: Binding<InvoiceAccentTheme> {
    Binding(
      get: { viewModel.accentTheme },
      set: {
        viewModel.accentTheme = $0
        viewModel.customAccentColor = nil
      }
    )
  }

  var typographyDensityBinding: Binding<InvoiceTypographyDensity> {
    Binding(
      get: { viewModel.typographyDensity },
      set: { density in
        replaceNumericDraft(InvoiceTemplateGeometryInputID.typographyScale) {
          viewModel.typographyDensity = density
          viewModel.customTypographyScale = nil
        }
      }
    )
  }

  var documentSpacingBinding: Binding<InvoiceDocumentSpacingPreset> {
    Binding(
      get: { viewModel.documentSpacing },
      set: { spacing in
        replaceNumericDraft(InvoiceTemplateGeometryInputID.spacingScale) {
          viewModel.documentSpacing = spacing
          viewModel.customSpacingScale = nil
        }
      }
    )
  }

  var borderWeightBinding: Binding<InvoiceBorderWeight> {
    Binding(
      get: { viewModel.borderWeight },
      set: { weight in
        replaceNumericDraft(InvoiceTemplateGeometryInputID.borderWidth) {
          viewModel.borderWeight = weight
          viewModel.customBorderWidth = nil
        }
      }
    )
  }

  var typographyScaleBinding: Binding<Double> {
    Binding(
      get: { viewModel.customTypographyScale ?? Double(viewModel.typographyDensity.scale) },
      set: viewModel.updateCustomTypographyScale
    )
  }

  var spacingScaleBinding: Binding<Double> {
    Binding(
      get: { viewModel.customSpacingScale ?? Double(viewModel.documentSpacing.scale) },
      set: viewModel.updateCustomSpacingScale
    )
  }

  var borderWidthBinding: Binding<Double> {
    Binding(
      get: { viewModel.customBorderWidth ?? Double(viewModel.borderWeight.detailsBorderWidth) },
      set: viewModel.updateCustomBorderWidth
    )
  }

  var marginPresetBinding: Binding<InvoiceMarginPreset> {
    Binding(
      get: { viewModel.marginPreset },
      set: { preset in
        replaceNumericDraft(InvoiceTemplateGeometryInputID.margin) {
          viewModel.marginPreset = preset
          viewModel.customMarginPoints = nil
        }
      }
    )
  }

  var paperSizeBinding: Binding<PaperSize> {
    Binding(
      get: { viewModel.paperSize },
      set: {
        viewModel.paperSize = $0
        viewModel.customPageWidthPoints = nil
        viewModel.customPageHeightPoints = nil
        clearPageSizeDrafts()
      })
  }

  var pageOrientationBinding: Binding<PageOrientation> {
    Binding(
      get: { viewModel.pageOrientation },
      set: {
        viewModel.updatePageOrientation($0)
        clearPageSizeDrafts()
      }
    )
  }

  var customPageWidthBinding: Binding<Double> {
    Binding(
      get: {
        viewModel.customPageWidthPoints
          ?? Double(viewModel.paperSize.sizePoints(for: viewModel.pageOrientation).width)
      }, set: {
        viewModel.customPageWidthPoints = InvoiceTemplateLayoutLimits.pageDimension($0)
      })
  }

  var customPageHeightBinding: Binding<Double> {
    Binding(
      get: {
        viewModel.customPageHeightPoints
          ?? Double(viewModel.paperSize.sizePoints(for: viewModel.pageOrientation).height)
      }, set: {
        viewModel.customPageHeightPoints = InvoiceTemplateLayoutLimits.pageDimension($0)
      })
  }

  var customMarginBinding: Binding<Double> {
    Binding(
      get: {
        viewModel.customMarginPoints == nil
          ? Double(viewModel.marginPreset.marginPoints)
          : Double(viewModel.effectiveMarginPoints)
      },
      set: {
        viewModel.customMarginPoints = Double(
          InvoiceTemplateLayoutLimits.effectiveMargin($0, pageSize: viewModel.pageSizePoints)
        )
      }
    )
  }

  func clearPageSizeDrafts() {
    clearNumericDraft(InvoiceTemplateGeometryInputID.pageWidth)
    clearNumericDraft(InvoiceTemplateGeometryInputID.pageHeight)
  }

  func clearNumericDraft(_ inputID: String) {
    toolbarState.resetNumericInputDraft(inputID)
    inputValidityChange(inputID, false)
  }

  func replaceNumericDraft(
    _ inputID: String,
    applying mutation: () -> Void
  ) {
    InvoiceTemplateNumericDraftResolution.replace(
      inputID: inputID,
      toolbarState: toolbarState,
      onValidityChange: inputValidityChange,
      applying: mutation
    )
  }

}
