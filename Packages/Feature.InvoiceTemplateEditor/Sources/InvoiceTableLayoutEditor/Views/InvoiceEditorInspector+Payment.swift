import Core
import SwiftUI

extension InvoiceEditorInspector {
    // MARK: - Payment (Details | Terms)

    var paymentDetailsSection: some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .paymentDetails)) {
                TextField("Bank", text: $viewModel.bankName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedTarget, equals: .bankName)
                    .accessibilityLabel("Bank name")
                TextField("Account", text: $viewModel.bankAccountName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Account name")
                    .focused($focusedTarget, equals: .bankAccountName)
                TextField("BSB", text: $viewModel.bankBSB)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("BSB")
                    .focused($focusedTarget, equals: .bankBSB)
                TextField("Account no.", text: $viewModel.bankAccountNumber)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Account number")
                    .focused($focusedTarget, equals: .bankAccountNumber)
            } label: {
                Label("Payment Details", systemImage: "building.columns")
            }
        }
        .id(InvoiceInspectorSection.paymentDetails)
    }

    var paymentTermsSection: some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .paymentTerms)) {
                TextField(
                    "Terms",
                    text: $viewModel.paymentTerms,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedTarget, equals: .paymentTerms)
                .lineLimit(1 ... 3)
                .accessibilityLabel("Payment Terms")
                TextField(
                    "Notes",
                    text: $viewModel.notes,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedTarget, equals: .notes)
                .lineLimit(1 ... 5)
                .accessibilityLabel("Invoice Notes")
            } label: {
                Label("Payment Terms", systemImage: "doc.plaintext")
            }
        }
        .id(InvoiceInspectorSection.paymentTerms)
    }

    // MARK: - Editor-only (last, secondary)

    @ViewBuilder
    func validationSection(_ proxy: ScrollViewProxy) -> some View {
        if !viewModel.validationIssues.isEmpty {
            Section {
                ForEach(viewModel.validationIssues) { issue in
                    if let target = issue.target {
                        Button {
                            focus(
                                InvoicePreviewInspectorInteraction.FocusRequest(target: target),
                                proxy: proxy
                            )
                        } label: {
                            HStack {
                                Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.right.circle")
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .help("Show related field")
                        .accessibilityHint("Moves focus to related invoice field")
                    } else {
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            } header: {
                Label("Validation", systemImage: "exclamationmark.triangle")
            } footer: {
                Text("Editor only — not part of the printed invoice layout.")
            }
            .id(InvoiceInspectorSection.validation)
        }
    }

    var settingsSection: some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .settings)) {
                TextField("Currency", text: $viewModel.currencyCode)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Currency")
                    .focused($focusedTarget, equals: .currencyCode)
                    .onSubmit {
                        viewModel.currencyCode = InvoiceCurrencyCode.normalized(viewModel.currencyCode)
                    }
                validatedDecimalField(
                    "Tax %",
                    value: $viewModel.defaultTaxRate,
                    inputID: "invoice.defaultTaxRate",
                    focusTarget: .defaultTaxRate
                )
                .accessibilityLabel("Default Tax Rate")
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } footer: {
            if isExpanded(.settings) {
                Text("Used for new line items. Edit each row’s Tax % to change an existing rate.")
            }
        }
        .id(InvoiceInspectorSection.settings)
    }

    func validatedDecimalField(
        _ title: String,
        value: Binding<Decimal>,
        inputID: String,
        focusTarget: InvoiceInspectorFocusTarget
    ) -> some View {
        InvoiceValidatedDecimalField(
            title,
            value: value,
            inputID: inputID,
            focusTarget: focusTarget,
            focus: $focusedTarget,
            draftStore: toolbarState.numericInputDrafts,
            resetRevision: toolbarState.numericInputResetRevision,
            onValidityChange: viewModel.updateNumericInputValidity
        )
    }

    @ViewBuilder
    func sectionNavigator(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(visibleSections) { section in
                    Button {
                        navigate(to: section, proxy: proxy)
                    } label: {
                        Label(section.displayName, systemImage: section.systemImage)
                    }
                }

                Divider()

                Button("Collapse All", systemImage: "rectangle.compress.vertical") {
                    withAnimation(subtleAnimation) {
                        collapseAllSections()
                    }
                }
            } label: {
                Label("Sections", systemImage: "list.bullet")
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Inspector sections")

            Spacer(minLength: 0)

            InvoicePreviewZoomControls(toolbarState: toolbarState)
        }
        .padding(.horizontal, InspectorLayout.scrollHorizontalPadding)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
