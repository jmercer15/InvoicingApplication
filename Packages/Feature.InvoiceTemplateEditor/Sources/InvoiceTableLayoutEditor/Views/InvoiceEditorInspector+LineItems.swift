import Core
import PersistenceModels
import SwiftUI

extension InvoiceEditorInspector {
    // MARK: - Line items & totals (unified table group)

    var lineItemsSection: some View {
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

    func lineItemLabel(_ item: InvoiceLineItemSnapshot, displayIndex: Int) -> some View {
        let description = item.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return Label(
            description.isEmpty ? "Line Item \(displayIndex)" : description,
            systemImage: "list.number"
        )
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

}
