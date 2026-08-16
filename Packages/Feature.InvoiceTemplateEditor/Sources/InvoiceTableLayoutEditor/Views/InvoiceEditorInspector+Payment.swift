import Core
import SwiftUI

extension InvoiceEditorInspector {
    // MARK: - Payment (Details | Terms)

    var paymentDetailsSection: some View {
        InvoiceEditorSection(title: "Payment Details", systemImage: "building.columns") {
            HStack(spacing: InspectorLayout.fieldSpacing) {
                InvoiceEditorIconField(systemImage: "building.columns", help: "Bank name") {
                    TextField("Bank", text: $viewModel.bankName)
                        .focused($focusedTarget, equals: .bankName)
                        .accessibilityLabel("Bank name")
                }
                InvoiceEditorIconField(systemImage: "person.text.rectangle", help: "Account name") {
                    TextField("Account", text: $viewModel.bankAccountName)
                        .accessibilityLabel("Account name")
                        .focused($focusedTarget, equals: .bankAccountName)
                }
            }
            HStack(spacing: InspectorLayout.fieldSpacing) {
                InvoiceEditorIconField(systemImage: "number", help: "BSB") {
                    TextField("BSB", text: $viewModel.bankBSB)
                        .accessibilityLabel("BSB")
                        .focused($focusedTarget, equals: .bankBSB)
                }
                InvoiceEditorIconField(systemImage: "number.square", help: "Account number") {
                    TextField("Account no.", text: $viewModel.bankAccountNumber)
                        .accessibilityLabel("Account number")
                        .focused($focusedTarget, equals: .bankAccountNumber)
                }
            }
        }
        .id(InvoiceInspectorSection.paymentDetails)
    }

    var paymentTermsSection: some View {
        ViewThatFits(in: .horizontal) {
            IntrinsicPartyRowLayout(spacing: 0, expandsToFillWidth: true) {
                termsSection.frame(minWidth: 320)
                notesSection.frame(minWidth: 320)
            }

            VStack(spacing: 0) {
                termsSection
                notesSection
            }
        }
        .id(InvoiceInspectorSection.paymentTerms)
    }

    private var termsSection: some View {
        InvoiceEditorSection(title: "Terms & Conditions", systemImage: "doc.plaintext") {
            TextField("Payment terms", text: $viewModel.paymentTerms, axis: .vertical)
                .focused($focusedTarget, equals: .paymentTerms)
                .lineLimit(2 ... 3)
                .accessibilityLabel("Payment Terms")
        }
    }

    private var notesSection: some View {
        InvoiceEditorSection(title: "Notes", systemImage: "note.text") {
            TextField("Notes", text: $viewModel.notes, axis: .vertical)
                .focused($focusedTarget, equals: .notes)
                .lineLimit(2 ... 3)
                .accessibilityLabel("Invoice Notes")
        }
    }

    // MARK: - Editor-only (last, secondary)

    @ViewBuilder
    func validationSection(_ proxy: ScrollViewProxy) -> some View {
        if !viewModel.validationIssues.isEmpty {
            InvoiceEditorSection(title: "Validation", systemImage: "exclamationmark.triangle") {
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
                                Spacer(minLength: InspectorLayout.compactFieldSpacing)
                                Image(systemName: "arrow.right.circle")
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, InspectorLayout.fieldLabelSpacing)
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
                            .padding(.vertical, InspectorLayout.fieldLabelSpacing)
                    }
                }
            }
            .id(InvoiceInspectorSection.validation)
        }
    }

    func validatedDecimalField(
        _ title: String,
        value: Binding<Decimal>,
        inputID: String,
        focusTarget: InvoiceInspectorFocusTarget,
        showsValidationMessage: Bool = true,
        step: Decimal? = nil,
        minimumValue: Decimal? = nil,
        usesPlainTextFieldStyle: Bool = false
    ) -> some View {
        InvoiceValidatedDecimalField(
            title,
            value: value,
            inputID: inputID,
            focusTarget: focusTarget,
            focus: $focusedTarget,
            draftStore: toolbarState.numericInputDrafts,
            resetRevision: toolbarState.numericInputResetRevision,
            showsValidationMessage: showsValidationMessage,
            step: step,
            minimumValue: minimumValue,
            usesPlainTextFieldStyle: usesPlainTextFieldStyle,
            onValidityChange: viewModel.updateNumericInputValidity
        )
    }

}
