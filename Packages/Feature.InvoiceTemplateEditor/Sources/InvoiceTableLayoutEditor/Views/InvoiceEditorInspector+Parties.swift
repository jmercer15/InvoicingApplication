import Core
import SwiftUI

extension InvoiceEditorInspector {
    // MARK: - Parties (From | Billed To | For)

    var fromSection: some View {
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
    var billedToSection: some View {
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

    var billingAuthorityBinding: Binding<Core.BillingAuthority?> {
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

    var clientSelectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedClientID },
            set: viewModel.selectClient
        )
    }

    var forSection: some View {
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

}
