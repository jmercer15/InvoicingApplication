import AppKit
import SwiftUI

enum InvoiceTemplateFormatSection: String, CaseIterable, Identifiable {
  case template
  case layout
  case design
  case content
  case lineItems

  var id: Self { self }

  var title: String {
    switch self {
    case .template: "Template"
    case .layout: "Layout"
    case .design: "Design"
    case .content: "Content"
    case .lineItems: "Table"
    }
  }

  var systemImage: String {
    switch self {
    case .template: "square.grid.2x2"
    case .layout: "doc"
    case .design: "paintpalette"
    case .content: "text.page"
    case .lineItems: "tablecells"
    }
  }

  static func destination(for target: InvoiceInspectorFocusTarget) -> Self {
    switch target {
    case .header, .from, .billedTo, .recipient:
      .template
    case .lineItems, .lineItem, .totals,
         .lineItemServiceDate, .lineItemDescription, .lineItemCode,
         .lineItemQuantity, .lineItemUnit, .lineItemUnitPrice, .lineItemTaxRate,
         .discountPercent, .discountAmount, .creditApplied,
         .currencyCode, .defaultTaxRate:
      .lineItems
    case .invoiceNumber, .issueDate, .dueDate,
         .paymentDetails, .paymentTerms, .notes,
         .sellerName, .sellerAddress, .sellerEmail, .sellerPhone, .sellerTaxID,
         .billParticipantDirectly,
         .billToName, .billToAddress, .billToEmail, .billToPhone, .billingAuthority,
         .clientName, .clientAddress, .clientEmail, .clientPhone, .clientTaxID,
         .bankName, .bankAccountName, .bankBSB, .bankAccountNumber:
      .content
    }
  }
}

enum InvoiceTemplateGeometryInputID {
  static let pageWidth = "template.page.width"
  static let pageHeight = "template.page.height"
  static let margin = "template.page.margin"
  static let typographyScale = "template.typographyScale"
  static let spacingScale = "template.spacingScale"
  static let borderWidth = "template.borderWidth"
}

enum InvoiceTemplateInvalidInputDestination {
  static func section(for inputID: String) -> InvoiceTemplateFormatSection? {
    switch inputID {
    case InvoiceTemplateGeometryInputID.pageWidth,
         InvoiceTemplateGeometryInputID.pageHeight,
         InvoiceTemplateGeometryInputID.margin:
      .layout
    case InvoiceTemplateGeometryInputID.typographyScale,
         InvoiceTemplateGeometryInputID.spacingScale,
         InvoiceTemplateGeometryInputID.borderWidth:
      .design
    default:
      nil
    }
  }

  /// Stable section priority avoids Set iteration order changing recovery destination.
  static func firstSection(for inputIDs: Set<String>) -> InvoiceTemplateFormatSection? {
    let destinations = Set(inputIDs.compactMap(section(for:)))
    return InvoiceTemplateFormatSection.allCases.first(where: destinations.contains)
  }
}

enum InvoiceTemplateInputRelevance {
  static func disabledInputIDs(tableStyle: InvoiceTableStyle) -> Set<String> {
    tableStyle == .borderless
      ? [InvoiceTemplateGeometryInputID.borderWidth]
      : []
  }
}

@MainActor
enum InvoiceTemplateNumericDraftResolution {
  /// Alternate controls replace exact text, so apply typed value first and then force field state
  /// to adopt that new baseline. Reversing this order can restore stale text while field is focused.
  static func replace(
    inputID: String,
    toolbarState: InvoiceEditorToolbarState,
    onValidityChange: (String, Bool) -> Void,
    applying mutation: () -> Void
  ) {
    mutation()
    toolbarState.resetNumericInputDraft(inputID)
    onValidityChange(inputID, false)
  }
}

/// Presentation and command controls displayed in the inspector's Format tab.
struct InvoiceTemplateRibbon: View {
  @Bindable var viewModel: InvoiceEditorViewModel
  @Bindable var toolbarState: InvoiceEditorToolbarState
  let previewInteraction: InvoicePreviewInspectorInteraction
  let saveState: InvoiceTemplateSaveState
  let retrySave: () -> Void
  let isCreatingInvoice: Bool
  let createInvoice: (() -> Void)?
  let openInvoices: (@MainActor () -> Void)?
  let inputValidityChange: (String, Bool) -> Void
  @SceneStorage("InvoiceTemplateEditor.FormatSection")
  private var selectedSectionRawValue = InvoiceTemplateFormatSection.template.rawValue
  @State private var showsResetConfirmation = false

  var body: some View {
    Form {
      templateWorkspaceNotice
      formatSectionPicker
      selectedSectionContent
    }
    .formStyle(.grouped)
    .controlSize(.regular)
    .textFieldStyle(.roundedBorder)
    .toggleStyle(.checkbox)
    .onAppear {
      reconcileDisabledNumericInputs(for: viewModel.tableStyle)
      revealRequestedSection()
      revealInvalidInputSectionIfNeeded()
    }
    .onChange(of: previewInteraction.formatInspectorRevealRevision) { _, _ in
      revealRequestedSection()
    }
    .onChange(of: toolbarState.invalidTemplateInputRecoveryRequestRevision) { _, _ in
      revealInvalidInputSectionIfNeeded()
    }
    .onChange(of: viewModel.tableStyle) { _, tableStyle in
      reconcileDisabledNumericInputs(for: tableStyle)
    }
    .confirmationDialog(
      "Reset invoice template?",
      isPresented: $showsResetConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset Template", role: .destructive) {
        viewModel.resetTemplateToDefaults()
        clearNumericInputDrafts()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("All formatting defaults return to the classic template. Invoice data is unaffected.")
    }
  }

  private var templateWorkspaceNotice: some View {
    Section {
      LabeledContent("Preview") {
        Label("Mock invoice", systemImage: "doc.text.image")
      }
      LabeledContent("Style") {
        Text(viewModel.matchingTemplatePreset?.displayName ?? "Custom")
      }
      LabeledContent("Changes") {
        saveStateLabel
      }

      if saveState == .invalid {
        Button("Review Invalid Values", systemImage: "exclamationmark.triangle.fill") {
          revealInvalidInputSection()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .tint(.orange)
        .help("Open the Format section containing an invalid exact value")
      } else if let createInvoice {
        Button(action: createInvoice) {
          if isCreatingInvoice {
            Label {
              Text("Creating Invoice…")
            } icon: {
              ProgressView().controlSize(.small)
            }
          } else if saveState == .saving {
            Label {
              Text("Saving Template…")
            } icon: {
              ProgressView().controlSize(.small)
            }
          } else {
            Label("Create Invoice", systemImage: "doc.badge.plus")
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(isCreatingInvoice || saveState == .saving)
        .help("Save this template, then create and open a new invoice")
      }

      if let openInvoices {
        Button("Open Invoices", systemImage: "list.bullet.rectangle") {
          openInvoices()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(isCreatingInvoice)
        .help("Return to invoice list without changing mock preview data")
      }
    } footer: {
      Text(templateWorkspaceFooter)
    }
  }

  private func reconcileDisabledNumericInputs(for tableStyle: InvoiceTableStyle) {
    for inputID in InvoiceTemplateInputRelevance.disabledInputIDs(tableStyle: tableStyle) {
      clearNumericDraft(inputID)
    }
  }

  private var templateWorkspaceFooter: String {
    if saveState == .invalid {
      return "Review highlighted exact values before creating an invoice. Other valid template changes remain saved; unfinished text returns when you reopen this workspace."
    }
    return "Changes become defaults for new invoices. Create Invoice saves this template first. Mock content never modifies invoice records."
  }

  @ViewBuilder
  private var saveStateLabel: some View {
    switch saveState {
    case .saved:
      Label(saveState.title, systemImage: saveState.systemImage)
        .foregroundStyle(.green)
    case .saving:
      HStack(spacing: 8) {
        ProgressView()
          .controlSize(.small)
          .accessibilityHidden(true)
        Text(saveState.title)
      }
      .foregroundStyle(.secondary)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Saving template changes")
    case .failed:
      HStack(spacing: 8) {
        Label(saveState.title, systemImage: saveState.systemImage)
          .foregroundStyle(.red)
        Button("Retry", action: retrySave)
          .buttonStyle(.borderless)
          .help("Try saving template changes again")
      }
    case .invalid:
      Label(saveState.title, systemImage: saveState.systemImage)
        .foregroundStyle(.red)
        .help("Correct highlighted exact values before continuing")
    }
  }

  private var formatSectionPicker: some View {
    Section {
      Picker("Format Section", selection: selectedSectionBinding) {
        ForEach(InvoiceTemplateFormatSection.allCases) { section in
          Label(section.title, systemImage: section.systemImage)
            .tag(section)
        }
      }
      .pickerStyle(.menu)

      InvoicePreviewZoomControls(toolbarState: toolbarState)
    } header: {
      Label("Format", systemImage: selectedSection.systemImage)
    } footer: {
      Text("Editing \(selectedSection.title.lowercased()) settings.")
    }
  }

  private var selectedSection: InvoiceTemplateFormatSection {
    InvoiceTemplateFormatSection(rawValue: selectedSectionRawValue) ?? .template
  }

  private var selectedSectionBinding: Binding<InvoiceTemplateFormatSection> {
    Binding(
      get: { selectedSection },
      set: { selectedSectionRawValue = $0.rawValue }
    )
  }

  private func revealRequestedSection() {
    guard let requestedSection = previewInteraction.requestedFormatSection,
          selectedSectionRawValue != requestedSection.rawValue
    else { return }
    selectedSectionRawValue = requestedSection.rawValue
  }

  private func revealInvalidInputSection() {
    guard let section = InvoiceTemplateInvalidInputDestination.firstSection(
      for: toolbarState.numericInputDrafts.inputIDs
    ) else { return }
    selectedSectionRawValue = section.rawValue
  }

  private func revealInvalidInputSectionIfNeeded() {
    guard saveState == .invalid else { return }
    revealInvalidInputSection()
  }

  @ViewBuilder
  private var selectedSectionContent: some View {
    switch selectedSection {
    case .template:
      templateTab
    case .layout:
      layoutTab
    case .design:
      designTab
    case .content:
      contentTab
    case .lineItems:
      lineItemsTab
    }
  }

  @ViewBuilder
  private var templateTab: some View {
    ribbonGroup("Templates") {
      ribbonRow {
        ribbonPicker(
          "Preset",
          selected: viewModel.matchingTemplatePreset,
          values: InvoiceTemplatePreset.allCases,
          label: { preset in Label(preset.displayName, systemImage: preset.toolbarIcon) },
          action: applyTemplatePreset
        )
        Button("Reset All", systemImage: "arrow.counterclockwise") {
          showsResetConfirmation = true
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isUsingDefaultTemplate)
        .help("Restore classic template defaults")
      }
    }
    ribbonGroup("Composition") {
      ribbonRow {
        ribbonPicker(
          "Header", selection: $viewModel.headerStyle, values: InvoiceHeaderStyle.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      ribbonRow {
        ribbonPicker(
          "Parties", selection: $viewModel.partyLayout, values: InvoicePartyLayout.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      ribbonRow {
        ribbonPicker(
          "Business Mark", selection: $viewModel.logoPlacement,
          values: InvoiceLogoPlacement.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
    }
  }

  @ViewBuilder
  private var layoutTab: some View {
    ribbonGroup("Page Setup") {
      ribbonRow {
        ribbonPicker("Paper", selection: paperSizeBinding, values: PaperSize.allCases) {
          concisePickerOption(
            $0.displayName,
            accessibilityLabel: $0.menuLabel,
            systemImage: $0.toolbarIcon
          )
        }
      }
      ribbonRow {
        ribbonPicker(
          "Orientation", selection: pageOrientationBinding, values: PageOrientation.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      ribbonRow {
        geometryField(
          "Width",
          value: customPageWidthBinding,
          inputID: InvoiceTemplateGeometryInputID.pageWidth,
          validRange: InvoiceTemplateLayoutLimits.pageDimensionRange
        )
        geometryField(
          "Height",
          value: customPageHeightBinding,
          inputID: InvoiceTemplateGeometryInputID.pageHeight,
          validRange: InvoiceTemplateLayoutLimits.pageDimensionRange
        )
      }
      ribbonRow {
        Button("Use \(viewModel.paperSize.displayName)", systemImage: "arrow.uturn.backward") {
          viewModel.useSelectedPaperSize()
          clearPageSizeDrafts()
        }
        .buttonStyle(.bordered)
        .disabled(!viewModel.hasCustomPageSize)
        .help("Restore selected paper dimensions")
      }
    }
    ribbonGroup("Margins") {
      ribbonRow {
        ribbonPicker(
          "Margins", selection: marginPresetBinding, values: InvoiceMarginPreset.allCases
        ) {
          concisePickerOption(
            $0.displayName,
            accessibilityLabel: $0.menuLabel,
            systemImage: $0.toolbarIcon
          )
        }
      }
      ribbonRow {
        geometryField(
          "Margin",
          value: customMarginBinding,
          inputID: InvoiceTemplateGeometryInputID.margin,
          validRange: 0...InvoiceTemplateLayoutLimits.maximumMargin(for: viewModel.pageSizePoints)
        )
      }
      ribbonRow {
        Button("Use Preset", systemImage: "arrow.uturn.backward") {
          viewModel.useSelectedMarginPreset()
          clearNumericDraft(InvoiceTemplateGeometryInputID.margin)
        }
        .buttonStyle(.bordered)
        .disabled(!viewModel.hasCustomMargin)
        .help("Restore selected margin preset")
      }
    }
  }

  @ViewBuilder
  private var designTab: some View {
    ribbonGroup("Accent colour") {
      ribbonRow {
        ribbonPicker("Theme", selection: accentThemeBinding, values: InvoiceAccentTheme.allCases) {
          Label($0.displayName, systemImage: "paintpalette.fill")
        }
      }
      ribbonRow {
        ribbonColorPicker("Custom", selection: customAccentBinding)
      }
      ribbonRow {
        Button("Use Theme", systemImage: "paintpalette") {
          viewModel.customAccentColor = nil
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.customAccentColor == nil)
      }
    }
    ribbonGroup("Typography") {
      ribbonRow {
        ribbonPicker(
          "Font", selection: $viewModel.fontFamily, values: InvoiceFontFamilyPreset.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      ribbonRow {
        ribbonPicker(
          "Density", selection: typographyDensityBinding, values: InvoiceTypographyDensity.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      granularControl(
        "Scale",
        value: typographyScaleBinding,
        inputID: InvoiceTemplateGeometryInputID.typographyScale,
        range: 0.75...2,
        step: 0.01,
        suffix: "×",
        resetAvailable: viewModel.customTypographyScale != nil,
        reset: { viewModel.customTypographyScale = nil }
      )
    }
    ribbonGroup("Spacing") {
      ribbonRow {
        ribbonPicker(
          "Spacing", selection: documentSpacingBinding,
          values: InvoiceDocumentSpacingPreset.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
      granularControl(
        "Scale",
        value: spacingScaleBinding,
        inputID: InvoiceTemplateGeometryInputID.spacingScale,
        range: 0.5...1.75,
        step: 0.05,
        suffix: "×",
        resetAvailable: viewModel.customSpacingScale != nil,
        reset: { viewModel.customSpacingScale = nil }
      )
    }
    ribbonGroup("Rules") {
      ribbonRow {
        ribbonPicker(
          "Weight", selection: borderWeightBinding, values: InvoiceBorderWeight.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
        .disabled(viewModel.tableStyle == .borderless)
      }
      granularControl(
        "Width",
        value: borderWidthBinding,
        inputID: InvoiceTemplateGeometryInputID.borderWidth,
        range: 0.25...3,
        step: 0.25,
        suffix: " pt",
        resetAvailable: viewModel.customBorderWidth != nil,
        reset: { viewModel.customBorderWidth = nil }
      )
      .disabled(viewModel.tableStyle == .borderless)
    }
    ribbonGroup("Party cards") {
      ribbonRow {
        toggle("Borders", image: "rectangle.dashed", isOn: $viewModel.showPartyCardBorders)
        toggle("Fill", image: "rectangle.fill", isOn: $viewModel.showPartyCardFill)
      }
    }
    ribbonGroup("Payment cards") {
      ribbonRow {
        toggle(
          "Borders", image: "rectangle.on.rectangle",
          isOn: $viewModel.showPaymentCardBorders)
        toggle(
          "Fill", image: "rectangle.fill.on.rectangle.fill",
          isOn: $viewModel.showPaymentCardFill)
      }
    }
    ribbonGroup("Invoice metadata") {
      ribbonRow {
        toggle(
          "Outline", image: "rectangle.inset.filled",
          isOn: $viewModel.showInvoiceDetailsBorders)
        toggle("Grid", image: "tablecells", isOn: $viewModel.showInvoiceDetailGridLines)
      }
      ribbonRow {
        toggle("Labels", image: "text.alignleft", isOn: $viewModel.showInvoiceDetailLabels)
      }
    }
  }

  @ViewBuilder
  private var contentTab: some View {
    ribbonGroup("Header") {
      ribbonRow {
        ribbonPicker(
          "Date", selection: $viewModel.dateFormatStyle,
          values: InvoiceDateFormatStyle.allCases
        ) {
          concisePickerOption(
            $0.styleName,
            accessibilityLabel: $0.menuLabel,
            systemImage: $0.toolbarIcon
          )
        }
        toggle("Title", image: "textformat", isOn: $viewModel.showTitleOnDocument)
      }
      ribbonRow {
        toggle("Number", image: "number", isOn: $viewModel.showInvoiceNumberOnDocument)
        toggle("Issued", image: "calendar", isOn: $viewModel.showIssueDateOnDocument)
      }
      ribbonRow {
        toggle(
          "Due", image: "calendar.badge.exclamationmark",
          isOn: $viewModel.showDueDateOnDocument)
        toggle("Underline", image: "text.underline", isOn: $viewModel.showTitleUnderline)
          .disabled(viewModel.headerStyle == .fullBleed || !viewModel.showTitleOnDocument)
      }
    }
    ribbonGroup("Payments") {
      ribbonRow {
        toggle("Details", image: "banknote", isOn: $viewModel.showPaymentDetails)
        toggle("Terms", image: "calendar.badge.clock", isOn: $viewModel.showPaymentTerms)
      }
      ribbonRow {
        toggle("Labels", image: "text.alignleft", isOn: $viewModel.showPaymentDetailLabels)
          .disabled(!viewModel.showPaymentDetails)
        toggle(
          "Rules", image: "line.3.horizontal",
          isOn: $viewModel.showPaymentDetailRowRules
        )
        .disabled(!viewModel.showPaymentDetails)
      }
    }
    ribbonGroup("Document flow") {
      ribbonRow {
        toggle("Numbers", image: "list.number", isOn: $viewModel.showPageNumbers)
        toggle(
          "Frame", image: "rectangle.inset.filled",
          isOn: $viewModel.showPageNumberChrome
        )
        .disabled(!viewModel.showPageNumbers)
      }
    }
    ribbonGroup("Parties") {
      ribbonRow {
        toggle("Labels", image: "tag", isOn: $viewModel.showPartyLabels)
        toggle("Contacts", image: "text.alignleft", isOn: $viewModel.showPartyContactLabels)
      }
      ribbonRow {
        toggle(
          "Participant", image: "person.crop.circle",
          isOn: $viewModel.showParticipantSection
        )
        .disabled(viewModel.billParticipantDirectly)
      }
    }
    ribbonGroup("Provider details") {
      ribbonRow {
        toggle("Phone", image: "phone", isOn: $viewModel.showProviderPhone)
        toggle("Email", image: "envelope", isOn: $viewModel.showProviderEmail)
      }
      ribbonRow {
        toggle("ABN", image: "number.square", isOn: $viewModel.showProviderTaxID)
      }
    }
  }

  @ViewBuilder
  private var lineItemsTab: some View {
    ribbonGroup("Table style") {
      ribbonRow {
        ribbonPicker(
          "Style", selection: $viewModel.tableStyle, values: InvoiceTableStyle.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
        toggle("Grid", image: "tablecells", isOn: $viewModel.showTableGridLines)
          .disabled(viewModel.tableStyle == .borderless)
      }
      ribbonRow {
        toggle("Alternating", image: "rectangle.3.group", isOn: $viewModel.showTableZebraRows)
          .disabled(viewModel.tableStyle != .banded)
        toggle(
          "Header", image: "rectangle.topthird.inset.filled",
          isOn: $viewModel.showTableHeaderFill
        )
        .disabled(!viewModel.tableStyle.showsHeaderFill)
      }
    }
    ribbonGroup("Totals") {
      ribbonRow {
        ribbonPicker(
          "Emphasis", selection: $viewModel.totalsEmphasis, values: InvoiceTotalsEmphasis.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
        toggle(
          "Totals fill", image: "rectangle.bottomthird.inset.filled",
          isOn: $viewModel.showTotalsFill)
      }
    }
    ribbonGroup("Headings") {
      ribbonRow {
        toggle(
          "Section", image: "textformat.size", isOn: $viewModel.showLineItemsSectionTitle)
        toggle(
          "Columns", image: "rectangle.split.1x2", isOn: $viewModel.showLineItemsTableHeader
        )
      }
    }
    ribbonGroup("Columns") {
      ribbonRow {
        toggle("Date", image: "calendar", isOn: $viewModel.showDateColumn)
        toggle("Code", image: "number", isOn: $viewModel.showItemCode)
      }
      ribbonRow {
        toggle("Qty", image: "sum", isOn: $viewModel.showQtyColumn)
        toggle("Unit", image: "ruler", isOn: $viewModel.showUnitColumn)
      }
      ribbonRow {
        toggle("Rate", image: "dollarsign.circle", isOn: $viewModel.showRateColumn)
        toggle(
          "Dates", image: "calendar.day.timeline.left",
          isOn: $viewModel.showServiceDatesInDescription)
      }
    }
    ribbonGroup("Amount format") {
      ribbonRow {
        ribbonPicker(
          "Currency", selection: $viewModel.currencyDisplayStyle,
          values: InvoiceCurrencyDisplayStyle.allCases
        ) {
          concisePickerOption(
            $0.toolbarSummary,
            accessibilityLabel: $0.displayName,
            systemImage: $0.toolbarIcon
          )
        }
      }
      ribbonRow {
        ribbonPicker(
          "Tax", selection: $viewModel.taxLabelStyle, values: InvoiceTaxLabelStyle.allCases
        ) {
          Label($0.displayName, systemImage: $0.toolbarIcon)
        }
      }
    }
  }

  @ViewBuilder
  private func ribbonGroup<Content: View>(
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
  private func ribbonRow<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    GridRow {
      content()
    }
  }

  private func sectionIcon(for title: String) -> String {
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

  private func ribbonPicker<Value: Hashable, OptionLabel: View>(
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

  private func concisePickerOption(
    _ title: String,
    accessibilityLabel: String,
    systemImage: String
  ) -> some View {
    Label(title, systemImage: systemImage)
      .accessibilityLabel(accessibilityLabel)
  }

  private func ribbonPicker<Value: Hashable, OptionLabel: View>(
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

  private func toggle(_ title: String, image: String, isOn: Binding<Bool>) -> some View {
    Toggle(isOn: isOn) {
      Label(title, systemImage: image)
    }
    .toggleStyle(.checkbox)
  }

  @ViewBuilder
  private func granularControl(
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

  private func geometryField(
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

  private func ribbonColorPicker(_ title: String, selection: Binding<Color>) -> some View {
    ColorPicker(title, selection: selection, supportsOpacity: true)
  }

  private func applyTemplatePreset(_ preset: InvoiceTemplatePreset) {
    viewModel.applyTemplatePreset(preset)
    clearNumericInputDrafts()
  }

  private func clearNumericInputDrafts() {
    for inputID in toolbarState.resetNumericInputDrafts() {
      inputValidityChange(inputID, false)
    }
  }

  private var customAccentBinding: Binding<Color> {
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

  private var accentThemeBinding: Binding<InvoiceAccentTheme> {
    Binding(
      get: { viewModel.accentTheme },
      set: {
        viewModel.accentTheme = $0
        viewModel.customAccentColor = nil
      }
    )
  }

  private var typographyDensityBinding: Binding<InvoiceTypographyDensity> {
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

  private var documentSpacingBinding: Binding<InvoiceDocumentSpacingPreset> {
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

  private var borderWeightBinding: Binding<InvoiceBorderWeight> {
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

  private var typographyScaleBinding: Binding<Double> {
    Binding(
      get: { viewModel.customTypographyScale ?? Double(viewModel.typographyDensity.scale) },
      set: viewModel.updateCustomTypographyScale
    )
  }

  private var spacingScaleBinding: Binding<Double> {
    Binding(
      get: { viewModel.customSpacingScale ?? Double(viewModel.documentSpacing.scale) },
      set: viewModel.updateCustomSpacingScale
    )
  }

  private var borderWidthBinding: Binding<Double> {
    Binding(
      get: { viewModel.customBorderWidth ?? Double(viewModel.borderWeight.detailsBorderWidth) },
      set: viewModel.updateCustomBorderWidth
    )
  }

  private var marginPresetBinding: Binding<InvoiceMarginPreset> {
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

  private var paperSizeBinding: Binding<PaperSize> {
    Binding(
      get: { viewModel.paperSize },
      set: {
        viewModel.paperSize = $0
        viewModel.customPageWidthPoints = nil
        viewModel.customPageHeightPoints = nil
        clearPageSizeDrafts()
      })
  }

  private var pageOrientationBinding: Binding<PageOrientation> {
    Binding(
      get: { viewModel.pageOrientation },
      set: {
        viewModel.updatePageOrientation($0)
        clearPageSizeDrafts()
      }
    )
  }

  private var customPageWidthBinding: Binding<Double> {
    Binding(
      get: {
        viewModel.customPageWidthPoints
          ?? Double(viewModel.paperSize.sizePoints(for: viewModel.pageOrientation).width)
      }, set: {
        viewModel.customPageWidthPoints = InvoiceTemplateLayoutLimits.pageDimension($0)
      })
  }

  private var customPageHeightBinding: Binding<Double> {
    Binding(
      get: {
        viewModel.customPageHeightPoints
          ?? Double(viewModel.paperSize.sizePoints(for: viewModel.pageOrientation).height)
      }, set: {
        viewModel.customPageHeightPoints = InvoiceTemplateLayoutLimits.pageDimension($0)
      })
  }

  private var customMarginBinding: Binding<Double> {
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

  private func clearPageSizeDrafts() {
    clearNumericDraft(InvoiceTemplateGeometryInputID.pageWidth)
    clearNumericDraft(InvoiceTemplateGeometryInputID.pageHeight)
  }

  private func clearNumericDraft(_ inputID: String) {
    toolbarState.resetNumericInputDraft(inputID)
    inputValidityChange(inputID, false)
  }

  private func replaceNumericDraft(
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
