import Core
import Observation
import SwiftUI

enum InvoiceInspectorFocusTarget: Hashable {
    // Legacy section targets remain while document renderers migrate to the
    // field-level targets below.
    case header
    case invoiceNumber
    case issueDate
    case dueDate
    case from
    case billedTo
    case recipient
    case lineItems
    case lineItem(UUID)
    case totals
    case paymentDetails
    case paymentTerms
    case notes

    case sellerName, sellerAddress, sellerEmail, sellerPhone, sellerTaxID
    case billParticipantDirectly
    case billToName, billToAddress, billToEmail, billToPhone, billingAuthority
    case clientName, clientAddress, clientEmail, clientPhone, clientTaxID
    case lineItemServiceDate(UUID)
    case lineItemDescription(UUID)
    case lineItemCode(UUID)
    case lineItemQuantity(UUID)
    case lineItemUnit(UUID)
    case lineItemUnitPrice(UUID)
    case lineItemTaxRate(UUID)
    case discountPercent, discountAmount, creditApplied
    case bankName, bankAccountName, bankBSB, bankAccountNumber
    case currencyCode, defaultTaxRate
}

@Observable
@MainActor
final class InvoicePreviewInspectorInteraction {
    enum Mode: Equatable {
        case invoiceData
        case templateFormatting
        case disabled
    }

    struct FocusRequest: Equatable {
        let id = UUID()
        let target: InvoiceInspectorFocusTarget
    }

    let mode: Mode
    private(set) var focusRequest: FocusRequest?
    private(set) var formatInspectorRevealRevision = 0
    private(set) var requestedFormatSection: InvoiceTemplateFormatSection?

    var allowsFieldTargeting: Bool { mode == .invoiceData }
    var allowsFormatInspectorReveal: Bool { mode == .templateFormatting }
    var allowsPreviewTargetSelection: Bool { mode != .disabled }

    init(isEnabled: Bool = true) {
        mode = isEnabled ? .invoiceData : .disabled
    }

    init(mode: Mode) {
        self.mode = mode
    }

    func select(_ target: InvoiceInspectorFocusTarget) {
        switch mode {
        case .invoiceData:
            focusRequest = FocusRequest(target: target)
        case .templateFormatting:
            requestedFormatSection = InvoiceTemplateFormatSection.destination(for: target)
            revealFormatInspector()
        case .disabled:
            return
        }
    }

    func revealFormatInspector() {
        guard allowsFormatInspectorReveal else { return }
        formatInspectorRevealRevision &+= 1
    }

    func completeFocusRequest(id: UUID) {
        guard focusRequest?.id == id else { return }
        focusRequest = nil
    }

    func accessibilityLabel(for target: InvoiceInspectorFocusTarget) -> String {
        switch mode {
        case .invoiceData:
            "Edit \(target.previewInteractionLabel)"
        case .templateFormatting:
            "Format \(target.previewInteractionLabel)"
        case .disabled:
            target.previewInteractionLabel
        }
    }

    func accessibilityHint(for target: InvoiceInspectorFocusTarget) -> String {
        switch mode {
        case .invoiceData:
            return "Opens related invoice data controls"
        case .templateFormatting:
            let section = InvoiceTemplateFormatSection.destination(for: target)
            return "Opens \(section.title) format section without changing mock invoice data"
        case .disabled:
            return ""
        }
    }

    func helpText(for target: InvoiceInspectorFocusTarget) -> String {
        switch mode {
        case .invoiceData:
            return "Edit \(target.previewInteractionLabel) in inspector"
        case .templateFormatting:
            let section = InvoiceTemplateFormatSection.destination(for: target)
            return "Format \(target.previewInteractionLabel) in \(section.title)"
        case .disabled:
            return target.previewInteractionLabel
        }
    }
}

struct InvoiceInspectorDeferredFocusLease: Equatable {
    let id: UUID
    let documentID: UUID?

    init(id: UUID = UUID(), documentID: UUID?) {
        self.id = id
        self.documentID = documentID
    }

    func isCurrent(activeLeaseID: UUID?, selectedDocumentID: UUID?) -> Bool {
        activeLeaseID == id && selectedDocumentID == documentID
    }
}

enum InvoiceEditorInspectorMode: Equatable, Sendable {
    case invoiceData
    case templateFormatting
}

/// Inspector sidebar with all editable invoice fields.
///
/// Layout mirrors the invoice document top-to-bottom:
/// Header → Parties → Line Items (+ Totals) → Payment → editor-only.
/// Uses a native `Form` so macOS owns field spacing, keyboard traversal, and scrolling.
/// The line-items section still chooses its table or compact-card presentation from its
/// measured content requirement.
struct InvoiceEditorInspector: View {
    @Bindable var viewModel: InvoiceEditorViewModel
    @Bindable var toolbarState: InvoiceEditorToolbarState
    let previewInteraction: InvoicePreviewInspectorInteraction
    let mode: InvoiceEditorInspectorMode
    let templateSaveState: InvoiceTemplateSaveState
    let retryTemplateSave: () -> Void
    let isCreatingInvoiceFromTemplate: Bool
    let createInvoiceFromTemplate: (() -> Void)?
    let openInvoices: (@MainActor () -> Void)?
    let openTemplateEditor: (@MainActor () -> Void)?
    let isPreparingWorkspaceHandoff: Bool
    let templateInputValidityChange: (String, Bool) -> Void

    /// The inspector is an accordion: exactly one document path may be open.
    /// `nil` is used only by the explicit Collapse All command.
    @State private var expandedSection: InvoiceInspectorSection? = .header
    /// Nested accordion state for the Line Items path.
    @State private var expandedLineItemID: UUID?
    @State private var lineItemUndo = InvoiceLineItemUndoCoordinator()
    @State private var handledAddLineItemRequestRevision = 0
    @State private var activeDeferredFocusLeaseID: UUID?
    @FocusState private var focusedTarget: InvoiceInspectorFocusTarget?
    @Environment(\.undoManager) private var undoManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        switch mode {
        case .invoiceData:
            invoiceForm
                .accessibilityLabel("Invoice data inspector")
        case .templateFormatting:
            InvoiceTemplateRibbon(
                viewModel: viewModel,
                toolbarState: toolbarState,
                previewInteraction: previewInteraction,
                saveState: templateSaveState,
                retrySave: retryTemplateSave,
                isCreatingInvoice: isCreatingInvoiceFromTemplate,
                createInvoice: createInvoiceFromTemplate,
                openInvoices: openInvoices,
                inputValidityChange: templateInputValidityChange
            )
            .accessibilityLabel("Invoice template format inspector")
        }
    }

    private var invoiceForm: some View {
        ScrollViewReader { proxy in
            Form {
                documentActionsSection
                headerSection
                fromSection
                billedToSection
                forSection
                lineItemsSection
                totalsSection
                paymentDetailsSection
                paymentTermsSection
                validationSection(proxy)
                settingsSection
            }
            .formStyle(.grouped)
            .controlSize(.regular)
            .textFieldStyle(.roundedBorder)
            .toggleStyle(.checkbox)
            .disclosureGroupStyle(InspectorDisclosureGroupStyle())
            .safeAreaInset(edge: .top, spacing: 0) {
                sectionNavigator(proxy)
            }
            .onChange(of: previewInteraction.focusRequest) { _, request in
                guard let request else { return }
                focus(request, proxy: proxy)
            }
            .onChange(of: toolbarState.addLineItemRequestRevision) { _, _ in
                handleAddLineItemRequest()
            }
            .onChange(of: viewModel.selectedInvoiceID) { _, selectedInvoiceID in
                lineItemUndo.activateDocument(
                    id: selectedInvoiceID,
                    undoManager: undoManager
                )
                activeDeferredFocusLeaseID = nil
                expandedLineItemID = nil
                focusedTarget = nil
            }
            .onAppear {
                lineItemUndo.activateDocument(
                    id: viewModel.selectedInvoiceID,
                    undoManager: undoManager
                )
                if let request = previewInteraction.focusRequest {
                    focus(request, proxy: proxy)
                }
                handleAddLineItemRequest()
            }
            .onDisappear {
                activeDeferredFocusLeaseID = nil
                focusedTarget = nil
            }
        }
    }

    private var documentActionsSection: some View {
        Section {
            Picker("Status", selection: $viewModel.status) {
                ForEach(InvoiceStatus.allCases, id: \.self) { status in
                    Label(status.displayName, systemImage: status.toolbarIcon)
                        .tag(status)
                }
            }

            LabeledContent("Changes") {
                let activityState = InvoiceEditorActivityState.resolve(viewModel)
                if activityState.isActive {
                    Label {
                        Text(activityState.title)
                    } icon: {
                        ProgressView().controlSize(.small)
                    }
                    .foregroundStyle(.secondary)
                } else if activityState == .conflict {
                    Label(activityState.title, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else if activityState == .unsaved {
                    Label("Not saved", systemImage: "circle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Button {
                Task { await viewModel.saveCurrentInvoice() }
            } label: {
                if viewModel.isSaving {
                    Label {
                        Text("Saving")
                    } icon: {
                        ProgressView().controlSize(.small)
                    }
                } else {
                    Label("Save Invoice", systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!viewModel.hasUnsavedChanges || viewModel.isBusy)

            HStack {
                Button("Duplicate", systemImage: "doc.on.doc") {
                    Task { await viewModel.duplicateSelectedInvoice() }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isBusy)

                Spacer()

                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Export PDF", systemImage: "square.and.arrow.up") {
                        Task { await viewModel.exportCurrentInvoicePDF() }
                    }
                    Button("Print", systemImage: "printer") {
                        Task { await viewModel.printCurrentInvoice() }
                    }

                    Divider()

                    Button("Delete Invoice", systemImage: "trash", role: .destructive) {
                        toolbarState.showsDeleteConfirmation = true
                    }
                }
                .menuStyle(.borderlessButton)
                .disabled(viewModel.isBusy)
            }

            if let openTemplateEditor {
                Button {
                    openTemplateEditor()
                } label: {
                    if isPreparingWorkspaceHandoff {
                        Label {
                            Text("Opening Template Editor…")
                        } icon: {
                            ProgressView().controlSize(.small)
                        }
                    } else {
                        Label("Edit New-Invoice Template", systemImage: "paintbrush")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isBusy || isPreparingWorkspaceHandoff)
                .help("Open Template Editor. Changes apply to newly created invoices only.")
                .accessibilityHint("Opens Template Editor without changing this invoice")
            }
        } header: {
            Label("Invoice", systemImage: "doc.text")
        } footer: {
            Text("Edit persisted invoice data here. Template Editor manages formatting defaults for new invoices.")
        }
    }

    // MARK: - Header (document banner)

    private var headerSection: some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .header)) {
                TextField("Invoice Number", text: $viewModel.invoiceNumber)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedTarget, equals: .invoiceNumber)
                    .accessibilityLabel("Invoice number")
                TextField("Title", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedTarget, equals: .header)
                    .accessibilityLabel("Invoice title")
                DatePicker(
                    "Issued",
                    selection: Binding(
                        get: { viewModel.issueDate },
                        set: { viewModel.updateIssueDate($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .focused($focusedTarget, equals: .issueDate)
                .accessibilityLabel("Issue Date")
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { viewModel.dueDate },
                        set: { viewModel.updateDueDate($0) }
                    ),
                    in: viewModel.issueDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .focused($focusedTarget, equals: .dueDate)
                .accessibilityLabel("Due Date")
            } label: {
                Label("Header", systemImage: "doc.text")
            }
        } footer: {
            if isExpanded(.header) {
                Text("Title and dates shown in the invoice banner.")
            }
        }
        .id(InvoiceInspectorSection.header)
    }

    // MARK: - Parties (From | Billed To | For)

    private var fromSection: some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .from)) {
                partyFields(
                    name: $viewModel.sellerName,
                    address: $viewModel.sellerAddress,
                    email: $viewModel.sellerEmail,
                    phone: $viewModel.sellerPhone,
                    taxID: $viewModel.sellerTaxID,
                    taxIDLabel: "ABN",
                    focusTargets: (.sellerName, .sellerAddress, .sellerEmail, .sellerPhone, .sellerTaxID)
                )
            } label: {
                Label("From", systemImage: "building.2")
            }
        } footer: {
            if isExpanded(.from) {
                Text("Your business details on the invoice.")
            }
        }
        .id(InvoiceInspectorSection.from)
    }

    /// Matches document party order: From | Billed To | For.
    private var billedToSection: some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .billedTo)) {
                Picker("Authority", selection: billingAuthorityBinding) {
                    Text("Unspecified").tag(Core.BillingAuthority?.none)
                    ForEach(Core.BillingAuthority.allCases, id: \.self) { authority in
                        Text(authority.displayName).tag(Optional(authority))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Billing Authority")
                .focused($focusedTarget, equals: .billingAuthority)

                if !viewModel.billParticipantDirectly {
                    TextField("Name", text: $viewModel.billToName)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedTarget, equals: .billToName)
                    TextField("Address", text: $viewModel.billToAddress, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2 ... 4)
                        .focused($focusedTarget, equals: .billToAddress)
                    TextField("Email", text: $viewModel.billToEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .focused($focusedTarget, equals: .billToEmail)
                    TextField("Phone", text: $viewModel.billToPhone)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.telephoneNumber)
                        .focused($focusedTarget, equals: .billToPhone)
                }
            } label: {
                Label("Billed To", systemImage: "person.text.rectangle")
            }
        } footer: {
            if isExpanded(.billedTo) {
                Text(
                    viewModel.billParticipantDirectly
                        ? "Invoice is addressed to the participant (same as For)."
                        : "Choose billing authority, then edit recipient snapshot for this invoice."
                )
            }
        }
        .id(InvoiceInspectorSection.billedTo)
    }

    private var billingAuthorityBinding: Binding<Core.BillingAuthority?> {
        Binding(
            get: {
                InvoiceBillingAuthorityResolution.resolve(
                    rawValue: viewModel.billingAuthority,
                    billsParticipantDirectly: viewModel.billParticipantDirectly
                )
            },
            set: viewModel.updateBillingAuthority
        )
    }

    private var forSection: some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .recipient)) {
                Picker("Client", selection: clientSelectionBinding) {
                    Text("Manual details").tag(UUID?.none)
                    if let selectedClientID = viewModel.selectedClientID,
                       !viewModel.clientOptions.contains(where: { $0.id == selectedClientID }) {
                        Text(viewModel.clientName.isEmpty ? "Unavailable client" : viewModel.clientName)
                            .tag(Optional(selectedClientID))
                    }
                    ForEach(viewModel.clientOptions) { client in
                        Text(client.name).tag(Optional(client.id))
                    }
                }
                .pickerStyle(.menu)
                .disabled(viewModel.isLoadingClientOptions)

                if viewModel.isLoadingClientOptions {
                    ProgressView("Loading clients…")
                        .controlSize(.small)
                } else if let message = viewModel.clientOptionsLoadError {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Clients couldn't be loaded", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Try Again", systemImage: "arrow.clockwise") {
                            Task { await viewModel.loadClientOptions() }
                        }
                        .buttonStyle(.borderless)
                    }
                }

                partyFields(
                    name: $viewModel.clientName,
                    address: $viewModel.clientAddress,
                    email: $viewModel.clientEmail,
                    phone: $viewModel.clientPhone,
                    taxID: $viewModel.clientTaxID,
                    taxIDLabel: "NDIS No.",
                    nameLabel: "Name",
                    focusTargets: (.clientName, .clientAddress, .clientEmail, .clientPhone, .clientTaxID)
                )
            } label: {
                Label("For", systemImage: "person")
            }
        } footer: {
            if isExpanded(.recipient) {
                Text("Choose an application client to load current billing details, then adjust this invoice snapshot if needed.")
            }
        }
        .id(InvoiceInspectorSection.recipient)
    }

    // MARK: - Line items & totals (unified table group)

    private var lineItemsSection: some View {
        return Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .lineItems)) {
                if viewModel.lineItems.isEmpty {
                    ContentUnavailableView(
                        "No Line Items",
                        systemImage: "list.bullet",
                        description: Text("Add an item to begin this invoice.")
                    )
                } else {
                    ForEach(Array(viewModel.lineItems.enumerated()), id: \.element.id) { index, item in
                        DisclosureGroup(isExpanded: lineItemExpansionBinding(for: item.id)) {
                            lineItemFormFields(itemID: item.id, displayIndex: index + 1)
                        } label: {
                            lineItemLabel(item, displayIndex: index + 1)
                        }
                        .id(item.id)
                        if item.id != viewModel.lineItems.last?.id {
                            Divider()
                        }
                    }
                }

                Button("Add Item", systemImage: "plus") {
                    addLineItem()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add Line Item")
            } label: {
                Label("Line Items", systemImage: "list.bullet.rectangle")
            }
        }
        .id(InvoiceInspectorSection.lineItems)
    }

    private var discountPercentBinding: Binding<Decimal> {
        Binding(
            get: { viewModel.discountPercent },
            set: { viewModel.updateDiscountPercent($0) }
        )
    }

    private var discountAmountBinding: Binding<Decimal> {
        Binding(
            get: { viewModel.discountAmount },
            set: { viewModel.updateDiscountAmount($0) }
        )
    }

    @ViewBuilder
    private func lineItemFormFields(itemID: UUID, displayIndex: Int) -> some View {
        Button("Remove", systemImage: "trash", role: .destructive) {
            lineItemUndo.removeLineItem(
                id: itemID,
                from: viewModel,
                undoManager: undoManager
            )
        }
        .help("Remove line item \(displayIndex)")
        .accessibilityLabel("Remove Line Item")

        TextField("Description", text: lineItemDescriptionBinding(itemID))
            .textFieldStyle(.roundedBorder)
            .focused($focusedTarget, equals: .lineItemDescription(itemID))
        DatePicker(
            "Date",
            selection: lineItemServiceDateBinding(itemID),
            displayedComponents: .date
        )
        .datePickerStyle(.compact)
        .focused($focusedTarget, equals: .lineItemServiceDate(itemID))
        .accessibilityLabel("Service Date")
        TextField("Code", text: lineItemCodeBinding(itemID))
            .accessibilityLabel("Item Code")
            .textFieldStyle(.roundedBorder)
            .focused($focusedTarget, equals: .lineItemCode(itemID))
        validatedDecimalField(
            "Qty",
            value: lineItemQuantityBinding(itemID),
            inputID: "lineItem.\(itemID.uuidString).quantity",
            focusTarget: .lineItemQuantity(itemID)
        )
        .accessibilityLabel("Quantity")
        TextField("Unit", text: lineItemUnitBinding(itemID))
            .textFieldStyle(.roundedBorder)
            .focused($focusedTarget, equals: .lineItemUnit(itemID))
        validatedDecimalField(
            rateFieldLabel,
            value: lineItemUnitPriceBinding(itemID),
            inputID: "lineItem.\(itemID.uuidString).unitPrice",
            focusTarget: .lineItemUnitPrice(itemID)
        )
        validatedDecimalField(
            "Tax %",
            value: lineItemTaxRateBinding(itemID),
            inputID: "lineItem.\(itemID.uuidString).taxRate",
            focusTarget: .lineItemTaxRate(itemID)
        )
        Text(
            "Total: \(money(viewModel.lineItems.first(where: { $0.id == itemID })?.lineTotal ?? 0))"
        )
        .monospacedDigit()
    }

    private func lineItemLabel(_ item: InvoiceLineItemSnapshot, displayIndex: Int) -> some View {
        let description = item.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return Label(
            description.isEmpty ? "Line Item \(displayIndex)" : description,
            systemImage: "list.number"
        )
    }

    private func lineItemDescriptionBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.itemDescription ?? "" },
            set: { viewModel.updateLineItemDescription(id: id, description: $0) }
        )
    }

    private func lineItemServiceDateBinding(_ id: UUID) -> Binding<Date> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.serviceDate ?? .now },
            set: { viewModel.updateLineItemServiceDate(id: id, serviceDate: $0) }
        )
    }

    private func lineItemCodeBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.itemCode ?? "" },
            set: { viewModel.updateLineItemCode(id: id, itemCode: $0) }
        )
    }

    private func lineItemQuantityBinding(_ id: UUID) -> Binding<Decimal> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.quantity ?? 0 },
            set: { viewModel.updateLineItemQuantity(id: id, quantity: $0) }
        )
    }

    private func lineItemUnitBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.unit ?? "" },
            set: { viewModel.updateLineItemUnit(id: id, unit: $0) }
        )
    }

    private func lineItemUnitPriceBinding(_ id: UUID) -> Binding<Decimal> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.unitPrice ?? 0 },
            set: { viewModel.updateLineItemUnitPrice(id: id, unitPrice: $0) }
        )
    }

    private func lineItemTaxRateBinding(_ id: UUID) -> Binding<Decimal> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.taxRate ?? 0 },
            set: { viewModel.updateLineItemTaxRate(id: id, taxRate: $0) }
        )
    }

    private var totalsSection: some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: .totals)) {
                Text("Subtotal: \(money(viewModel.liveTotals.subtotal))")
                    .monospacedDigit()

                validatedDecimalField(
                    "Discount %",
                    value: discountPercentBinding,
                    inputID: "invoice.discountPercent",
                    focusTarget: .discountPercent
                )

                if viewModel.discountPercent == 0 {
                    validatedDecimalField(
                        rateFieldLabel.replacingOccurrences(of: "Rate", with: "Discount"),
                        value: discountAmountBinding,
                        inputID: "invoice.discountAmount",
                        focusTarget: .discountAmount
                    )
                } else {
                    let calculatedDiscount = InvoiceCalculations.discountValue(
                        subtotal: viewModel.liveTotals.subtotal,
                        discountAmount: viewModel.discountAmount,
                        discountPercent: viewModel.discountPercent
                    )
                    Text("Discount: \(money(calculatedDiscount))")
                        .monospacedDigit()
                }

                Text("Tax: \(money(viewModel.liveTotals.taxTotal))")
                    .monospacedDigit()

                validatedDecimalField(
                    rateFieldLabel.replacingOccurrences(of: "Rate", with: "Credit"),
                    value: $viewModel.creditApplied,
                    inputID: "invoice.creditApplied",
                    focusTarget: .creditApplied
                )

                Divider()

                Text("Total: \(money(viewModel.liveTotals.grandTotal))")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } label: {
                Label("Totals", systemImage: "sum")
            }
        } footer: {
            if isExpanded(.totals) {
                Text("Shown at the bottom of the line items table on the document.")
            }
        }
        .id(InvoiceInspectorSection.totals)
    }

    private var moneyPrefix: String? {
        InvoiceMoneyFormatter.editablePrefix(
            currencyCode: viewModel.currencyCode,
            displayStyle: viewModel.currencyDisplayStyle
        )
    }

    private var clientSelectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedClientID },
            set: viewModel.selectClient
        )
    }

    private var moneySuffix: String? {
        InvoiceMoneyFormatter.editableSuffix(
            currencyCode: viewModel.currencyCode,
            displayStyle: viewModel.currencyDisplayStyle
        )
    }

    private var rateFieldLabel: String {
        let affix = [moneyPrefix, moneySuffix]
            .compactMap { $0 }
            .joined(separator: " ")
        return affix.isEmpty ? "Rate" : "Rate (\(affix))"
    }

    private func money(_ amount: Decimal) -> String {
        InvoiceMoneyFormatter.string(
            for: amount,
            currencyCode: viewModel.currencyCode,
            displayStyle: viewModel.currencyDisplayStyle
        )
    }

    @ViewBuilder
    private func partyFields(
        name: Binding<String>,
        address: Binding<String>,
        email: Binding<String>,
        phone: Binding<String>,
        taxID: Binding<String>,
        taxIDLabel: String,
        nameLabel: String = "Name",
        focusTargets: (
            name: InvoiceInspectorFocusTarget, address: InvoiceInspectorFocusTarget,
            email: InvoiceInspectorFocusTarget, phone: InvoiceInspectorFocusTarget,
            taxID: InvoiceInspectorFocusTarget
        )
    ) -> some View {
        TextField(nameLabel, text: name)
            .textFieldStyle(.roundedBorder)
            .focused($focusedTarget, equals: focusTargets.name)
        TextField("Address", text: address, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(2 ... 4)
            .focused($focusedTarget, equals: focusTargets.address)
        TextField("Email", text: email)
            .textFieldStyle(.roundedBorder)
            .textContentType(.emailAddress)
            .focused($focusedTarget, equals: focusTargets.email)
        TextField("Phone", text: phone)
            .textFieldStyle(.roundedBorder)
            .textContentType(.telephoneNumber)
            .focused($focusedTarget, equals: focusTargets.phone)
        TextField(taxIDLabel, text: taxID)
            .textFieldStyle(.roundedBorder)
            .focused($focusedTarget, equals: focusTargets.taxID)
    }

    // MARK: - Payment (Details | Terms)

    private var paymentDetailsSection: some View {
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

    private var paymentTermsSection: some View {
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
    private func validationSection(_ proxy: ScrollViewProxy) -> some View {
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

    private var settingsSection: some View {
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

    private func validatedDecimalField(
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
    private func sectionNavigator(_ proxy: ScrollViewProxy) -> some View {
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

    private var visibleSections: [InvoiceInspectorSection] {
        InvoiceInspectorSection.allCases.filter { section in
            section != .validation || !viewModel.validationErrors.isEmpty
        }
    }

    private var motionAnimation: Animation? {
        reduceMotion ? nil : .snappy
    }

    private var subtleAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.15)
    }

    private func navigate(to section: InvoiceInspectorSection, proxy: ScrollViewProxy) {
        activeDeferredFocusLeaseID = nil
        withAnimation(subtleAnimation) {
            expand(section)
            proxy.scrollTo(section, anchor: .top)
        }
    }

    private func focus(
        _ request: InvoicePreviewInspectorInteraction.FocusRequest,
        proxy: ScrollViewProxy
    ) {
        let target = request.target
        let resolvedFocusTarget: InvoiceInspectorFocusTarget =
            target == .billParticipantDirectly ? .billingAuthority : target
        let section: InvoiceInspectorSection
        switch target {
        case .header, .invoiceNumber, .issueDate, .dueDate:
            section = .header
        case .from, .sellerName, .sellerAddress, .sellerEmail, .sellerPhone, .sellerTaxID:
            section = .from
        case .billedTo, .billParticipantDirectly, .billToName, .billToAddress, .billToEmail,
             .billToPhone, .billingAuthority:
            section = .billedTo
        case .recipient, .clientName, .clientAddress, .clientEmail, .clientPhone, .clientTaxID:
            section = .recipient
        case .lineItems, .lineItem, .lineItemServiceDate, .lineItemDescription, .lineItemCode,
             .lineItemQuantity, .lineItemUnit, .lineItemUnitPrice, .lineItemTaxRate:
            section = .lineItems
        case .totals, .discountPercent, .discountAmount, .creditApplied:
            section = .totals
        case .paymentDetails, .bankName, .bankAccountName, .bankBSB, .bankAccountNumber:
            section = .paymentDetails
        case .paymentTerms, .notes:
            section = .paymentTerms
        case .currencyCode, .defaultTaxRate:
            section = .settings
        }
        expandedSection = section
        if let itemID = lineItemID(for: target) {
            expandedLineItemID = itemID
        }
        let lease = InvoiceInspectorDeferredFocusLease(
            id: request.id,
            documentID: viewModel.selectedInvoiceID
        )
        activeDeferredFocusLeaseID = lease.id
        withAnimation(motionAnimation) { proxy.scrollTo(section, anchor: .top) }
        Task { @MainActor in
            await Task.yield()
            previewInteraction.completeFocusRequest(id: request.id)
            guard lease.isCurrent(
                activeLeaseID: activeDeferredFocusLeaseID,
                selectedDocumentID: viewModel.selectedInvoiceID
            ) else { return }
            if let itemID = lineItemID(for: target) {
                withAnimation(motionAnimation) { proxy.scrollTo(itemID, anchor: .center) }
            }
            focusedTarget = resolvedFocusTarget
        }
    }

    private func expand(_ section: InvoiceInspectorSection) {
        guard section != .validation else { return }
        expandedSection = section
    }

    private func collapseAllSections() {
        activeDeferredFocusLeaseID = nil
        expandedSection = nil
        expandedLineItemID = nil
        focusedTarget = nil
    }

    private func isExpanded(_ section: InvoiceInspectorSection) -> Bool {
        expandedSection == section
    }

    private func expansionBinding(for section: InvoiceInspectorSection) -> Binding<Bool> {
        Binding(
            get: { isExpanded(section) },
            set: { isNowExpanded in
                activeDeferredFocusLeaseID = nil
                withAnimation(motionAnimation) {
                    expandedSection = isNowExpanded ? section : nil
                }
            }
        )
    }

    private func lineItemExpansionBinding(for itemID: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedLineItemID == itemID },
            set: { isNowExpanded in
                activeDeferredFocusLeaseID = nil
                withAnimation(motionAnimation) {
                    expandedLineItemID = isNowExpanded ? itemID : nil
                }
            }
        )
    }

    private func lineItemID(for target: InvoiceInspectorFocusTarget) -> UUID? {
        switch target {
        case let .lineItem(itemID), let .lineItemServiceDate(itemID),
             let .lineItemDescription(itemID), let .lineItemCode(itemID),
             let .lineItemQuantity(itemID), let .lineItemUnit(itemID),
             let .lineItemUnitPrice(itemID), let .lineItemTaxRate(itemID):
            itemID
        default:
            nil
        }
    }

    private func addLineItemFromCommand() {
        expandedSection = .lineItems
        let itemID = addLineItem()
        let lease = InvoiceInspectorDeferredFocusLease(
            documentID: viewModel.selectedInvoiceID
        )
        activeDeferredFocusLeaseID = lease.id
        // The Invoice tab is created after this command changes the selected tab.
        // Yield once so SwiftUI can install the field before assigning focus.
        Task { @MainActor [itemID, lease] in
            await Task.yield()
            guard lease.isCurrent(
                activeLeaseID: activeDeferredFocusLeaseID,
                selectedDocumentID: viewModel.selectedInvoiceID
            ) else { return }
            focusedTarget = .lineItemDescription(itemID)
        }
    }

    private func handleAddLineItemRequest() {
        let revision = toolbarState.addLineItemRequestRevision
        guard revision > 0,
              revision != handledAddLineItemRequestRevision,
              !viewModel.isBusy
        else { return }
        handledAddLineItemRequestRevision = revision
        addLineItemFromCommand()
    }

    @discardableResult
    private func addLineItem() -> UUID {
        let itemID = lineItemUndo.addLineItem(
            to: viewModel,
            undoManager: undoManager
        )
        expandedLineItemID = itemID
        return itemID
    }
}

// MARK: - Layout tokens

private enum InspectorLayout {
    static let scrollHorizontalPadding: CGFloat = 12
    static let tableInset: CGFloat = 8

    static var tableHeaderFill: Color {
        Color.primary.opacity(0.04)
    }

    static var tableRowAltFill: Color {
        Color.primary.opacity(0.025)
    }
}

private enum InvoiceInspectorSection: String, CaseIterable, Identifiable {
    case header
    case from
    case billedTo
    case recipient
    case lineItems
    case totals
    case paymentDetails
    case paymentTerms
    case validation
    case settings

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .header: "Header"
        case .from: "From"
        case .billedTo: "Billed To"
        case .recipient: "For"
        case .lineItems: "Line Items"
        case .totals: "Totals"
        case .paymentDetails: "Payment Details"
        case .paymentTerms: "Payment Terms"
        case .validation: "Validation"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .header: "doc.text"
        case .from: "building.2"
        case .billedTo: "person.text.rectangle"
        case .recipient: "person"
        case .lineItems: "list.bullet.rectangle"
        case .totals: "sum"
        case .paymentDetails: "building.columns"
        case .paymentTerms: "doc.plaintext"
        case .validation: "exclamationmark.triangle"
        case .settings: "gearshape"
        }
    }
}

/// Bridges discrete line-item edits to the standard macOS Edit > Undo / Redo commands.
@MainActor
final class InvoiceLineItemUndoCoordinator {
    private(set) var activeDocumentID: UUID?

    /// UndoManager belongs to the window, while invoice drafts change in place.
    /// Remove only this coordinator's actions when document identity changes so
    /// an old line-item action can never mutate the newly selected invoice.
    func activateDocument(id: UUID?, undoManager: UndoManager?) {
        guard activeDocumentID != id else { return }
        undoManager?.removeAllActions(withTarget: self)
        activeDocumentID = id
    }

    func addLineItem(
        to viewModel: InvoiceEditorViewModel,
        undoManager: UndoManager?
    ) -> UUID {
        let documentID = viewModel.selectedInvoiceID
        activateDocument(id: documentID, undoManager: undoManager)
        let itemID = viewModel.addLineItem()
        registerUndoForAddition(
            itemID: itemID,
            documentID: documentID,
            viewModel: viewModel,
            undoManager: undoManager
        )
        undoManager?.setActionName("Add Line Item")
        return itemID
    }

    func removeLineItem(
        id: UUID,
        from viewModel: InvoiceEditorViewModel,
        undoManager: UndoManager?
    ) {
        let documentID = viewModel.selectedInvoiceID
        activateDocument(id: documentID, undoManager: undoManager)
        guard let removal = viewModel.removeLineItemForUndo(id: id) else { return }
        registerUndoForRemoval(
            removal,
            documentID: documentID,
            viewModel: viewModel,
            undoManager: undoManager
        )
        undoManager?.setActionName("Remove Line Item")
        viewModel.statusMessage = "Line item removed. Use Edit > Undo to restore it."
    }

    private func registerUndoForAddition(
        itemID: UUID,
        documentID: UUID?,
        viewModel: InvoiceEditorViewModel,
        undoManager: UndoManager?
    ) {
        undoManager?.registerUndo(withTarget: self) { coordinator in
            guard coordinator.owns(documentID, in: viewModel) else { return }
            guard let removal = viewModel.removeLineItemForUndo(id: itemID) else { return }
            coordinator.registerUndoForRemoval(
                removal,
                documentID: documentID,
                viewModel: viewModel,
                undoManager: undoManager
            )
            undoManager?.setActionName("Add Line Item")
        }
    }

    private func registerUndoForRemoval(
        _ removal: InvoiceLineItemRemoval,
        documentID: UUID?,
        viewModel: InvoiceEditorViewModel,
        undoManager: UndoManager?
    ) {
        undoManager?.registerUndo(withTarget: self) { coordinator in
            guard coordinator.owns(documentID, in: viewModel) else { return }
            viewModel.restoreLineItem(removal)
            coordinator.registerUndoForAddition(
                itemID: removal.item.id,
                documentID: documentID,
                viewModel: viewModel,
                undoManager: undoManager
            )
            undoManager?.setActionName("Remove Line Item")
        }
    }

    private func owns(_ documentID: UUID?, in viewModel: InvoiceEditorViewModel) -> Bool {
        activeDocumentID == documentID && viewModel.selectedInvoiceID == documentID
    }
}

/// Makes the full inspector section label a native button target, rather than limiting
/// expansion to the disclosure chevron's hit area.
private struct InspectorDisclosureGroupStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    configuration.label
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows or hides this section's fields")

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
