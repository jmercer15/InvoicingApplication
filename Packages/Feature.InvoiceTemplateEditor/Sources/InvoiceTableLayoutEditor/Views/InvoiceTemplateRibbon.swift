import SwiftUI

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
  var selectedSectionRawValue = InvoiceTemplateFormatSection.template.rawValue
  @State var showsResetConfirmation = false

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

  var templateWorkspaceNotice: some View {
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

  func reconcileDisabledNumericInputs(for tableStyle: InvoiceTableStyle) {
    for inputID in InvoiceTemplateInputRelevance.disabledInputIDs(tableStyle: tableStyle) {
      clearNumericDraft(inputID)
    }
  }

  var templateWorkspaceFooter: String {
    if saveState == .invalid {
      return "Review highlighted exact values before creating an invoice. Other valid template changes remain saved; unfinished text returns when you reopen this workspace."
    }
    return "Changes become defaults for new invoices. Create Invoice saves this template first. Mock content never modifies invoice records."
  }

  @ViewBuilder
  var saveStateLabel: some View {
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

  var formatSectionPicker: some View {
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

  var selectedSection: InvoiceTemplateFormatSection {
    InvoiceTemplateFormatSection(rawValue: selectedSectionRawValue) ?? .template
  }

  var selectedSectionBinding: Binding<InvoiceTemplateFormatSection> {
    Binding(
      get: { selectedSection },
      set: { selectedSectionRawValue = $0.rawValue }
    )
  }

  func revealRequestedSection() {
    guard let requestedSection = previewInteraction.requestedFormatSection,
          selectedSectionRawValue != requestedSection.rawValue
    else { return }
    selectedSectionRawValue = requestedSection.rawValue
  }

  func revealInvalidInputSection() {
    guard let section = InvoiceTemplateInvalidInputDestination.firstSection(
      for: toolbarState.numericInputDrafts.inputIDs
    ) else { return }
    selectedSectionRawValue = section.rawValue
  }

  func revealInvalidInputSectionIfNeeded() {
    guard saveState == .invalid else { return }
    revealInvalidInputSection()
  }

  @ViewBuilder
  var selectedSectionContent: some View {
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

}
