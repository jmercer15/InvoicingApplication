//
//  InvoiceEditorFormContent.swift
//  Feature.Invoices
//

import SwiftUI
import Core
import SharedUI

struct InvoiceEditorFormContent: View {
    @ObservedObject var viewModel: InvoiceEditorViewModel
    @State private var editingItemId: UUID?
    
    var body: some View {
        Form {
            detailsSection
            businessDetailsSection
            participantSection
            billingSection
            paymentDetailsSection
            lineItemsSection
            financialsSection
            notesSection
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Sections
    
    private var detailsSection: some View {
        Section {
            TextField("Invoice Number", text: $viewModel.invoiceNumber)
                .textFieldStyle(.roundedBorder)
            DatePicker("Issue Date", selection: $viewModel.issueDate, displayedComponents: .date)
            DatePicker("Due Date", selection: dueDateBinding, displayedComponents: .date)
            Picker("Status", selection: $viewModel.status) {
                ForEach(AppConstants.invoiceStatusOptions, id: \.self) {
                    Text(AppConstants.invoiceStatusDisplayName(for: $0)).tag($0 as String?)
                }
            }
            Picker("Currency", selection: $viewModel.currencyCode) {
                Text("AUD").tag("AUD")
                Text("USD").tag("USD")
                Text("GBP").tag("GBP")
                Text("EUR").tag("EUR")
            }
            
            Picker("Template", selection: $viewModel.selectedTemplateId) {
                Text("Default").tag(nil as UUID?)
                ForEach(viewModel.availableTemplates, id: \.id) { template in
                    Text(template.name).tag(template.id as UUID?)
                }
            }
            
            Divider()
            
            Toggle("Mark as Sent", isOn: isSentBinding)
            if viewModel.sentDate != nil {
                DatePicker("Sent Date", selection: sentDateBinding, displayedComponents: .date)
            }
            
            Toggle("Mark as Paid", isOn: isPaidBinding)
            if viewModel.paidDate != nil {
                DatePicker("Paid Date", selection: paidDateBinding, displayedComponents: .date)
            }
        } header: {
            sectionHeader("Invoice Details", icon: "doc.text")
        }
    }
    
    private var businessDetailsSection: some View {
        Section {
            Group {
                LabeledContent("Business", value: viewModel.invoice.businessName ?? "-")
                LabeledContent("ABN", value: viewModel.invoice.businessABN ?? "-")
                if let email = viewModel.invoice.businessEmail {
                    LabeledContent("Email", value: email)
                }
                if let phone = viewModel.invoice.businessPhone {
                    LabeledContent("Phone", value: phone)
                }
                if let address = viewModel.invoice.businessAddress {
                    LabeledContent("Address", value: address.fullFormattedAddress)
                }
            }
        } header: {
            sectionHeader("Business Details", icon: "building.2")
        }
    }
    
    private var participantSection: some View {
        Section {
            Picker("Client", selection: $viewModel.selectedClientId) {
                Text("Select Client").tag(nil as UUID?)
                ForEach(viewModel.allClients) { Text($0.fullName).tag($0.id as UUID?) }
                if let id = viewModel.selectedClientId, !viewModel.allClients.contains(where: { $0.id == id }) {
                    Text(viewModel.selectedClient?.fullName ?? "Loading...").tag(id as UUID?)
                }
            }
            
            if let c = viewModel.selectedClient {
                clientDetails(c)
            }
        } header: {
            sectionHeader("Participant", icon: "person.circle")
        }
    }
    
    private var billingSection: some View {
        Section {
            // Billing Method Selection
            Picker("Bill To Method", selection: $viewModel.billingSelection) {
                ForEach(InvoiceEditorViewModel.BillingSelection.allCases) { selection in
                    Text(selection.rawValue).tag(selection)
                }
            }
            .pickerStyle(.menu)
            
            // Contextual Entity Pickers
            if viewModel.billingSelection == .payee {
                Picker("Select Payee", selection: $viewModel.selectedPayeeId) {
                    Text("Select Payee").tag(nil as UUID?)
                    ForEach(viewModel.allPayees) { payee in
                        Text(payee.fullName).tag(payee.id as UUID?)
                    }
                }
            } else if viewModel.billingSelection == .planManager {
                Picker("Select Plan Manager", selection: $viewModel.selectedPlanManagerId) {
                    Text("Select Plan Manager").tag(nil as UUID?)
                    ForEach(viewModel.allPlanManagers) { pm in
                        Text(pm.name).tag(pm.id as UUID?)
                    }
                }
            }
            
            if viewModel.billingSelection != .client {
                Divider()
            }
            
            // Read-Only Display
            Group {
                if let auth = viewModel.billingAuthority, !auth.isEmpty {
                    LabeledContent("Authority", value: auth)
                }
                LabeledContent("Bill To Name", value: viewModel.billToName ?? "-")
                LabeledContent("Bill To Email", value: viewModel.billToEmail ?? "-")
                if let address = viewModel.billToAddress {
                    LabeledContent("Bill To Address", value: address)
                }
            }
        } header: {
            sectionHeader("Billing Details", icon: "envelope")
        }
    }
    
    private var paymentDetailsSection: some View {
        Section {
            LabeledContent("Bank Name", value: viewModel.invoice.bankName ?? "-")
            LabeledContent("Account Name", value: viewModel.invoice.bankAccountName ?? "-")
            LabeledContent("BSB", value: viewModel.invoice.bankBSB ?? "-")
            LabeledContent("Account Number", value: viewModel.invoice.bankAccountNumber ?? "-")
        } header: {
            sectionHeader("Payment Details", icon: "creditcard")
        }
    }
    
    private var lineItemsSection: some View {
        Section {
            if viewModel.invoiceItems.isEmpty {
                Text("No items added")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Grid(horizontalSpacing: 4, verticalSpacing: 10) {
                    GridRow {
                        Text("Description")
                            .gridColumnAlignment(.leading)
                        Text("Qty")
                            .gridColumnAlignment(.trailing)
                        Text("Rate")
                            .gridColumnAlignment(.trailing)
                        Text("Total")
                            .gridColumnAlignment(.trailing)
                        Color.clear
                            .gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    
                    Divider()
                        .gridCellColumns(5)
                        
                    ForEach(Array(viewModel.invoiceItems.enumerated()), id: \.element.id) { index, item in
                        GridRow {
                            // Description
                            Text(item.itemDescription.isEmpty ? "No description" : item.itemDescription)
                                .foregroundStyle(item.itemDescription.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .gridColumnAlignment(.leading)
                            
                            // Quantity
                            Text(item.quantity.formatted())
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                            
                            // Rate
                            Text(item.rate.formatted(.number.precision(.fractionLength(2))))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                            
                            // Total
                            Text(item.lineTotal, format: .currency(code: viewModel.currencyCode))
                                .monospacedDigit()
                                .fontWeight(.medium)
                                .gridColumnAlignment(.trailing)
                            
                            // Actions
                            HStack(spacing: 8) {
                                Button {
                                    editingItemId = item.id
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                
                                Button {
                                    if let index = viewModel.invoiceItems.firstIndex(where: { $0.id == item.id }) {
                                        viewModel.deleteInvoiceItems(at: IndexSet(integer: index))
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                            .gridColumnAlignment(.trailing)
                        }
                        
                        if index < viewModel.invoiceItems.count - 1 {
                            Divider()
                                .gridCellColumns(5)
                        }
                    }
                }
            }
            
            Button {
                withAnimation { viewModel.addNewInvoiceItem() }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Line Item")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
            }
            .buttonStyle(.borderless)
            .padding(.top, 8)
        } header: {
            HStack {
                sectionHeader("Line Items", icon: "list.bullet.rectangle")
                Spacer()
                if !viewModel.invoiceItems.isEmpty {
                    Text("\(viewModel.invoiceItems.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .popover(isPresented: Binding(
            get: { editingItemId != nil },
            set: { if !$0 { editingItemId = nil } }
        )) {
            if let id = editingItemId,
               let index = viewModel.invoiceItems.firstIndex(where: { $0.id == id }) {
                LineItemEditor(item: $viewModel.invoiceItems[index], currencyCode: viewModel.currencyCode)
                    .presentationCompactAdaptation(.popover)
            } else {
                Text("Item not found")
                    .padding()
            }
        }
    }
    

    
    private var financialsSection: some View {
        Section {
            percentField("Discount", value: $viewModel.discount)
            percentField("Tax Rate", value: $viewModel.taxRate)
            currencyField("Credit", value: $viewModel.creditApplied)
            
            Divider()
            
            LabeledContent("Subtotal", value: viewModel.subtotal, format: .currency(code: viewModel.currencyCode))
            LabeledContent("Tax", value: viewModel.taxAmount, format: .currency(code: viewModel.currencyCode))
            
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(viewModel.calculatedTotal, format: .currency(code: viewModel.currencyCode))
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
            }
            .padding(.top, 4)
        } header: {
            sectionHeader("Financials", icon: "banknote")
        }
    }
    
    private var notesSection: some View {
        Section {
            TextField("Payment Terms", text: paymentTermsBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            TextField("Notes", text: notesBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        } header: {
            sectionHeader("Notes", icon: "note.text")
        }
    }
    
    // MARK: - Components
    
    private func clientDetails(_ c: Client) -> some View {
        Group {
            if let v = c.email { LabeledContent("Email", value: v) }
            if let v = c.phone { LabeledContent("Phone", value: v) }
            if !c.ndisNumber.isEmpty { LabeledContent("NDIS", value: c.ndisNumber) }
            if let a = c.address { LabeledContent("Address", value: a.fullFormattedAddress) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    private func percentField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 2) {
                TextField("0", value: value, formatter: NumberFormatter.twoDecimal)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                Text("%").foregroundStyle(.tertiary)
            }
        }
    }
    
    private func currencyField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 2) {
                Text("$").foregroundStyle(.tertiary)
                TextField("0", value: value, formatter: NumberFormatter.decimal)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
    
    // MARK: - Bindings
    
    private var dueDateBinding: Binding<Date> {
        Binding(get: { viewModel.dueDate ?? Date() }, set: { viewModel.dueDate = $0 })
    }
    
    private var paymentTermsBinding: Binding<String> {
        Binding(get: { viewModel.paymentTerms ?? "" }, set: { viewModel.paymentTerms = $0 })
    }
    
    private var notesBinding: Binding<String> {
        Binding(get: { viewModel.notes ?? "" }, set: { viewModel.notes = $0 })
    }
    
    private var isSentBinding: Binding<Bool> {
        Binding(
            get: { viewModel.sentDate != nil },
            set: { viewModel.sentDate = $0 ? Date() : nil }
        )
    }
    
    private var sentDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.sentDate ?? Date() },
            set: { viewModel.sentDate = $0 }
        )
    }
    
    private var isPaidBinding: Binding<Bool> {
        Binding(
            get: { viewModel.paidDate != nil },
            set: { viewModel.paidDate = $0 ? Date() : nil }
        )
    }
    
    private var paidDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.paidDate ?? Date() },
            set: { viewModel.paidDate = $0 }
        )
    }
    

    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .textCase(nil)
    }
}

// MARK: - Line Item Editor

private struct LineItemEditor: View {
    @Binding var item: InvoiceItem
    let currencyCode: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Line Item")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Description", text: $item.itemDescription)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quantity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Qty", value: $item.quantity, formatter: NumberFormatter.decimal)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("$").foregroundStyle(.tertiary)
                        TextField("Rate", value: $item.rate, formatter: NumberFormatter.decimal)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("Total")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.lineTotal, format: .currency(code: currencyCode))
                    .font(.headline)
                    .monospacedDigit()
            }
        }
        .padding()
        .frame(width: 300)
    }
}
