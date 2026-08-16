import Core
import PersistenceModels
import SwiftUI

extension InvoiceEditorInspector {
    // MARK: - Line items & totals (unified table group)

    var lineItemsSection: some View {
        InvoiceEditorSection(
            title: "Services",
            systemImage: "list.bullet.rectangle",
            contentPadding: 0,
            contentSpacing: 0
        ) {
            if viewModel.lineItems.isEmpty {
                Label("No services added", systemImage: "list.bullet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .padding(InspectorLayout.sectionContentPadding)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.lineItems.enumerated()), id: \.element.id) { index, item in
                        lineItemFormFields(itemID: item.id, displayIndex: index + 1)
                            .id(item.id)
                        if item.id != viewModel.lineItems.last?.id {
                            Divider()
                                .overlay(Color.primary.opacity(0.14))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Button {
                _ = addLineItem()
            } label: {
                Label("Add Service", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Add Line Item")
        }
        .id(InvoiceInspectorSection.lineItems)
    }

    var discountPercentBinding: Binding<Decimal> {
        Binding(
            get: { viewModel.discountPercent },
            set: { viewModel.updateDiscountPercent($0) }
        )
    }

    var discountAmountBinding: Binding<Decimal> {
        Binding(
            get: { viewModel.discountAmount },
            set: { viewModel.updateDiscountAmount($0) }
        )
    }

    @ViewBuilder
    func lineItemFormFields(itemID: UUID, displayIndex: Int) -> some View {
        HStack(alignment: .center, spacing: InspectorLayout.compactFieldSpacing) {
            serviceIndexColumn(displayIndex)

            Divider()
                .overlay(Color.primary.opacity(0.12))

            VStack(alignment: .leading, spacing: InspectorLayout.compactFieldSpacing) {
                HStack(alignment: .bottom, spacing: InspectorLayout.compactFieldSpacing) {
                    serviceDateField(itemID: itemID)
                    lineItemCodeField(itemID: itemID)
                    lineItemDescriptionField(itemID: itemID)
                        .layoutPriority(1)
                }

                lineItemMetricsRow(itemID: itemID)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(Color.primary.opacity(0.12))

            removeLineItemButton(itemID: itemID, displayIndex: displayIndex)
        }
        .padding(InspectorLayout.serviceRowPadding)
        .background(
            Color.primary.opacity(displayIndex.isMultiple(of: 2) ? 0.035 : 0.012)
        )
    }

    private func serviceIndexColumn(_ displayIndex: Int) -> some View {
        Text(displayIndex, format: .number)
            .font(.title3.weight(.bold))
            .foregroundStyle(Color.accentColor)
            .monospacedDigit()
            .frame(minWidth: 28, minHeight: 28, alignment: .center)
            .background(Color.accentColor.opacity(0.12), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
            }
            .accessibilityLabel("Service \(displayIndex)")
    }

    private func lineItemDescriptionField(itemID: UUID) -> some View {
        InvoiceEditorField(label: "Description", showsLabel: false) {
            TextField("Description", text: lineItemDescriptionBinding(itemID))
                .focused($focusedTarget, equals: .lineItemDescription(itemID))
        }
    }

    private func lineItemCodeField(itemID: UUID) -> some View {
        InvoiceEditorField(label: "Code", showsLabel: false) {
            HStack(spacing: InspectorLayout.fieldLabelSpacing) {
                serviceFieldAffix("#")
                TextField("Service code", text: lineItemCodeBinding(itemID))
                    .accessibilityLabel("Item Code")
                    .focused($focusedTarget, equals: .lineItemCode(itemID))
            }
        }
    }

    private func removeLineItemButton(itemID: UUID, displayIndex: Int) -> some View {
        Button("Remove item \(displayIndex)", systemImage: "trash", role: .destructive) {
            lineItemUndo.removeLineItem(
                id: itemID,
                from: viewModel,
                undoManager: undoManager
            )
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .foregroundStyle(.red)
        .font(.callout.weight(.semibold))
        .padding(6)
        .background(Color.red.opacity(0.08), in: Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.red.opacity(0.18), lineWidth: 1)
        }
        .frame(width: 28, alignment: .center)
        .help("Remove line item \(displayIndex)")
        .accessibilityLabel("Remove Line Item")
    }

    private func lineItemMetricsRow(itemID: UUID) -> some View {
        HStack(alignment: .center, spacing: InspectorLayout.compactFieldSpacing) {
            serviceMetricGroup {
                quantityField(itemID: itemID)
            }

            serviceMetricOperator("×")

            serviceMetricGroup {
                HStack(alignment: .center, spacing: InspectorLayout.compactFieldSpacing) {
                    rateField(itemID: itemID)
                    serviceMetricOperator("/")
                    unitField(itemID: itemID)
                }
            }

            serviceMetricOperator("+")

            serviceMetricGroup {
                taxField(itemID: itemID)
            }

            serviceMetricOperator("=")

            serviceMetricGroup(isEmphasized: true) {
                lineItemTotal(itemID: itemID)
            }
        }
    }

    private func serviceMetricGroup<Content: View>(
        isEmphasized: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: InspectorLayout.compactFieldSpacing) {
            content()
        }
        .padding(.horizontal, InspectorLayout.metricGroupHorizontalPadding)
        .padding(.vertical, InspectorLayout.metricGroupVerticalPadding)
        .background(
            Color.accentColor.opacity(isEmphasized ? 0.14 : 0.08),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    Color.accentColor.opacity(isEmphasized ? 0.3 : 0.18),
                    lineWidth: 1
                )
        }
    }

    private func serviceMetricOperator(_ symbol: String) -> some View {
        Text(symbol)
            .font(.title3.weight(.bold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, InspectorLayout.fieldLabelSpacing)
            .accessibilityHidden(true)
    }

    private func serviceFieldAffix(_ symbol: String) -> some View {
        Text(symbol)
            .font(.callout.weight(.medium))
            .foregroundStyle(Color.primary.opacity(0.72))
            .accessibilityHidden(true)
    }

    private func quantityField(itemID: UUID) -> some View {
        InvoiceEditorField(label: "Qty", showsLabel: false) {
            validatedDecimalField(
                "Qty",
                value: lineItemQuantityBinding(itemID),
                inputID: "lineItem.\(itemID.uuidString).quantity",
                focusTarget: .lineItemQuantity(itemID),
                step: 0.25,
                minimumValue: 0,
                usesPlainTextFieldStyle: true
            )
            .accessibilityLabel("Quantity")
        }
    }

    private func rateField(itemID: UUID) -> some View {
        InvoiceEditorField(label: rateFieldLabel, showsLabel: false) {
            HStack(spacing: InspectorLayout.fieldLabelSpacing) {
                serviceFieldAffix("$")
                validatedDecimalField(
                    rateFieldLabel,
                    value: lineItemUnitPriceBinding(itemID),
                    inputID: "lineItem.\(itemID.uuidString).unitPrice",
                    focusTarget: .lineItemUnitPrice(itemID),
                    step: 1,
                    minimumValue: 0,
                    usesPlainTextFieldStyle: true
                )
            }
        }
    }

    private func unitField(itemID: UUID) -> some View {
        InvoiceEditorField(label: "Unit", showsLabel: false) {
            TextField("Unit", text: lineItemUnitBinding(itemID))
                .textFieldStyle(.plain)
                .focused($focusedTarget, equals: .lineItemUnit(itemID))
        }
    }

    private func taxField(itemID: UUID) -> some View {
        InvoiceEditorField(label: "Tax %", showsLabel: false) {
            HStack(spacing: InspectorLayout.fieldLabelSpacing) {
                validatedDecimalField(
                    "Tax %",
                    value: lineItemTaxRateBinding(itemID),
                    inputID: "lineItem.\(itemID.uuidString).taxRate",
                    focusTarget: .lineItemTaxRate(itemID),
                    step: 1,
                    minimumValue: 0,
                    usesPlainTextFieldStyle: true
                )
                serviceFieldAffix("%")
            }
        }
    }

    private func serviceDateField(itemID: UUID) -> some View {
        InvoiceEditorField(label: "Service date", showsLabel: false) {
            DatePicker(
                "Date",
                selection: lineItemServiceDateBinding(itemID),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .focused($focusedTarget, equals: .lineItemServiceDate(itemID))
            .accessibilityLabel("Service Date")
        }
    }

    private func lineItemTotal(itemID: UUID) -> some View {
        InvoiceEditorField(label: "Line total", showsLabel: false) {
            let total = viewModel.lineItems.first(where: { $0.id == itemID })?.lineTotal ?? 0
            HStack(spacing: InspectorLayout.fieldLabelSpacing) {
                serviceFieldAffix("$")
                Text(InvoiceMoneyFormatter.editableString(for: total))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                    .monospacedDigit()
            }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Line total")
                .accessibilityValue(money(total))
        }
    }

    func lineItemDescriptionBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.itemDescription ?? "" },
            set: { viewModel.updateLineItemDescription(id: id, description: $0) }
        )
    }

    func lineItemServiceDateBinding(_ id: UUID) -> Binding<Date> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.serviceDate ?? .now },
            set: { viewModel.updateLineItemServiceDate(id: id, serviceDate: $0) }
        )
    }

    func lineItemCodeBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.itemCode ?? "" },
            set: { viewModel.updateLineItemCode(id: id, itemCode: $0) }
        )
    }

    func lineItemQuantityBinding(_ id: UUID) -> Binding<Decimal> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.quantity ?? 0 },
            set: { viewModel.updateLineItemQuantity(id: id, quantity: $0) }
        )
    }

    func lineItemUnitBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.unit ?? "" },
            set: { viewModel.updateLineItemUnit(id: id, unit: $0) }
        )
    }

    func lineItemUnitPriceBinding(_ id: UUID) -> Binding<Decimal> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.unitPrice ?? 0 },
            set: { viewModel.updateLineItemUnitPrice(id: id, unitPrice: $0) }
        )
    }

    func lineItemTaxRateBinding(_ id: UUID) -> Binding<Decimal> {
        Binding(
            get: { viewModel.lineItems.first(where: { $0.id == id })?.taxRate ?? 0 },
            set: { viewModel.updateLineItemTaxRate(id: id, taxRate: $0) }
        )
    }

    var totalsSection: some View {
        InvoiceEditorSection(title: "Summary", systemImage: "sum") {
            InvoiceEditorSummaryRow(label: "Subtotal") {
                Text(money(viewModel.liveTotals.subtotal))
                    .monospacedDigit()
            }

            InvoiceEditorSummaryRow(label: "Discount %") {
                validatedDecimalField(
                    "Discount %",
                    value: discountPercentBinding,
                    inputID: "invoice.discountPercent",
                    focusTarget: .discountPercent,
                    step: 1,
                    minimumValue: 0
                )
            }

            if viewModel.discountPercent == 0 {
                InvoiceEditorSummaryRow(label: "Discount amount") {
                    validatedDecimalField(
                        rateFieldLabel.replacingOccurrences(of: "Rate", with: "Discount"),
                        value: discountAmountBinding,
                        inputID: "invoice.discountAmount",
                        focusTarget: .discountAmount,
                        step: 1,
                        minimumValue: 0
                    )
                }
            } else {
                let calculatedDiscount = InvoiceCalculations.discountValue(
                    subtotal: viewModel.liveTotals.subtotal,
                    discountAmount: viewModel.discountAmount,
                    discountPercent: viewModel.discountPercent
                )
                InvoiceEditorSummaryRow(label: "Discount") {
                    Text(money(calculatedDiscount))
                        .monospacedDigit()
                }
            }

            InvoiceEditorSummaryRow(label: "Tax") {
                Text(money(viewModel.liveTotals.taxTotal))
                    .monospacedDigit()
            }

            InvoiceEditorSummaryRow(label: "Credit") {
                validatedDecimalField(
                    rateFieldLabel.replacingOccurrences(of: "Rate", with: "Credit"),
                    value: $viewModel.creditApplied,
                    inputID: "invoice.creditApplied",
                    focusTarget: .creditApplied,
                    step: 1,
                    minimumValue: 0
                )
            }

            Divider()

            InvoiceEditorSummaryRow(label: "Total", isEmphasized: true) {
                Text(money(viewModel.liveTotals.grandTotal))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
        .id(InvoiceInspectorSection.totals)
    }

    var moneyPrefix: String? {
        InvoiceMoneyFormatter.editablePrefix(
            currencyCode: viewModel.currencyCode,
            displayStyle: viewModel.currencyDisplayStyle
        )
    }

    var moneySuffix: String? {
        InvoiceMoneyFormatter.editableSuffix(
            currencyCode: viewModel.currencyCode,
            displayStyle: viewModel.currencyDisplayStyle
        )
    }

    var rateFieldLabel: String {
        let affix = [moneyPrefix, moneySuffix]
            .compactMap { $0 }
            .joined(separator: " ")
        return affix.isEmpty ? "Rate" : "Rate (\(affix))"
    }

    func money(_ amount: Decimal) -> String {
        InvoiceMoneyFormatter.string(
            for: amount,
            currencyCode: viewModel.currencyCode,
            displayStyle: viewModel.currencyDisplayStyle
        )
    }

    @ViewBuilder
    func partyFields(
        name: Binding<String>,
        address: Binding<String>,
        email: Binding<String>,
        phone: Binding<String>,
        taxID: Binding<String>,
        taxIDLabel: String,
        nameLabel: String = "Name",
        nameSystemImage: String = "person",
        focusTargets: (
            name: InvoiceInspectorFocusTarget, address: InvoiceInspectorFocusTarget,
            email: InvoiceInspectorFocusTarget, phone: InvoiceInspectorFocusTarget,
            taxID: InvoiceInspectorFocusTarget
        )
    ) -> some View {
        InvoiceEditorIconField(systemImage: nameSystemImage, help: nameLabel) {
            TextField(nameLabel, text: name)
                .accessibilityLabel(nameLabel)
                .focused($focusedTarget, equals: focusTargets.name)
        }
        InvoiceEditorIconField(systemImage: "mappin.and.ellipse", help: "Address") {
            TextField("Address", text: address, axis: .vertical)
                .accessibilityLabel("Address")
                .lineLimit(1 ... 2)
                .focused($focusedTarget, equals: focusTargets.address)
        }
        InvoiceEditorIconField(systemImage: "envelope", help: "Email") {
            TextField("Email", text: email)
                .accessibilityLabel("Email")
                .textContentType(.emailAddress)
                .focused($focusedTarget, equals: focusTargets.email)
        }
        InvoiceEditorIconField(systemImage: "phone", help: "Phone") {
            TextField("Phone", text: phone)
                .accessibilityLabel("Phone")
                .textContentType(.telephoneNumber)
                .focused($focusedTarget, equals: focusTargets.phone)
        }
        InvoiceEditorIconField(systemImage: "number.square", help: taxIDLabel) {
            TextField(taxIDLabel, text: taxID)
                .accessibilityLabel(taxIDLabel)
                .focused($focusedTarget, equals: focusTargets.taxID)
        }
    }

}
