import Core
import SwiftUI

extension InvoiceEditorInspector {
    // MARK: - Parties (From | Billed To | For)

    var fromSection: some View {
        InvoiceEditorSection(title: "From", systemImage: "building.2") {
            partyFields(
                name: $viewModel.sellerName,
                address: $viewModel.sellerAddress,
                email: $viewModel.sellerEmail,
                phone: $viewModel.sellerPhone,
                taxID: $viewModel.sellerTaxID,
                taxIDLabel: "ABN",
                nameSystemImage: "building.2",
                focusTargets: (.sellerName, .sellerAddress, .sellerEmail, .sellerPhone, .sellerTaxID)
            )
        }
        .id(InvoiceInspectorSection.from)
    }

    /// Matches document party order: From | Billed To | For.
    var billedToSection: some View {
        InvoiceEditorSection(title: "Billed To", systemImage: "person.text.rectangle") {
            InvoiceEditorIconField(systemImage: "building.columns", help: "Billing Authority") {
                Picker("Authority", selection: billingAuthorityBinding) {
                    Text("Unspecified").tag(Core.BillingAuthority?.none)
                    ForEach(Core.BillingAuthority.allCases, id: \.self) { authority in
                        Text(authority.displayName).tag(Optional(authority))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Billing Authority")
                .focused($focusedTarget, equals: .billingAuthority)
            }

            if !viewModel.billParticipantDirectly {
                InvoiceEditorIconField(systemImage: "person", help: "Name") {
                    TextField("Name", text: $viewModel.billToName)
                        .accessibilityLabel("Name")
                        .focused($focusedTarget, equals: .billToName)
                }
                InvoiceEditorIconField(systemImage: "mappin.and.ellipse", help: "Address") {
                    TextField("Address", text: $viewModel.billToAddress, axis: .vertical)
                        .accessibilityLabel("Address")
                        .lineLimit(1 ... 2)
                        .focused($focusedTarget, equals: .billToAddress)
                }
                InvoiceEditorIconField(systemImage: "envelope", help: "Email") {
                    TextField("Email", text: $viewModel.billToEmail)
                        .accessibilityLabel("Email")
                        .textContentType(.emailAddress)
                        .focused($focusedTarget, equals: .billToEmail)
                }
                InvoiceEditorIconField(systemImage: "phone", help: "Phone") {
                    TextField("Phone", text: $viewModel.billToPhone)
                        .accessibilityLabel("Phone")
                        .textContentType(.telephoneNumber)
                        .focused($focusedTarget, equals: .billToPhone)
                }
            } else {
                Label("Participant billed directly", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        InvoiceEditorSection(title: "For", systemImage: "person") {
            InvoiceEditorIconField(systemImage: "person.crop.circle", help: "Client") {
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
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Client")
                .disabled(viewModel.isLoadingClientOptions)
            }

            if viewModel.isLoadingClientOptions {
                ProgressView("Loading clients…")
                    .controlSize(.small)
            } else if let message = viewModel.clientOptionsLoadError {
                VStack(alignment: .leading, spacing: InspectorLayout.compactFieldSpacing) {
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
        }
        .id(InvoiceInspectorSection.recipient)
    }

}
