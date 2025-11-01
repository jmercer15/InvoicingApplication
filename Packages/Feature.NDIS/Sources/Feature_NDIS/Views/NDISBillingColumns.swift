import SwiftUI
import SwiftData
import Data
import Core
import SharedUI

public struct NDISBillingContentColumn: View {
    @ObservedObject private var viewModel: NDISBillingWorkspaceViewModel
    @Environment(\.modelContext) private var modelContext

    public init(viewModel: NDISBillingWorkspaceViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    private var clients: [ClientEntity] { viewModel.filteredClients() }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            clientPicker
            sessionsList
            generateInvoiceSection
        }
        .padding()
        .background(Color("Background", bundle: .sharedUI))
        .toolbar { toolbarContent }
        .onAppear { viewModel.updateContextIfNeeded(modelContext) }
    }

    private var clientPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Client")
                .font(.headline)
            TextField("Search", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Picker("Client", selection: Binding(
                get: { viewModel.selectedClient?.id },
                set: { id in
                    if let id, let match = clients.first(where: { $0.id == id }) {
                        viewModel.selectClient(match)
                    } else {
                        viewModel.selectClient(nil)
                    }
                })
            ) {
                Text("Select a client").tag(UUID?.none)
                ForEach(clients, id: \.id) { client in
                    Text(client.fullName).tag(Optional(client.id))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sessions")
                .font(.headline)

            if let client = viewModel.selectedClient {
                let sessions = viewModel.sessions(for: client)
                if sessions.isEmpty {
                    Text("No sessions available for the selected client.")
                        .foregroundColor(.secondary)
                } else {
                    List(sessions, id: \.id) { session in
                        Button {
                            viewModel.toggleSession(session)
                        } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(minHeight: 240)
                }
            } else {
                Text("Select a client to view sessions.")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func sessionRow(_ session: SessionEntity) -> some View {
        HStack {
            VStack(alignment: .leading) {
                if let start = session.startTime {
                    Text(start, style: .date)
                        .font(.subheadline)
                }
                if let code = session.clientService?.ndisCode {
                    Text(code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if viewModel.selectedSessions.contains(where: { $0.id == session.id }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color("Primary", bundle: .sharedUI))
            }
        }
    }

    private var generateInvoiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: viewModel.generateInvoice) {
                HStack {
                    if viewModel.isLoading { ProgressView() }
                    Text(viewModel.isLoading ? "Generating…" : "Generate Invoice")
                }
            }
            .disabled(viewModel.selectedSessions.isEmpty || viewModel.isLoading)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Text("NDIS Billing")
                .font(.headline)
        }
    }
}

public struct NDISBillingDetailColumn: View {
    @ObservedObject private var viewModel: NDISBillingWorkspaceViewModel
    @Environment(\.modelContext) private var modelContext

    public init(viewModel: NDISBillingWorkspaceViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let invoice = viewModel.generatedInvoice {
                GeneratedInvoiceSummaryView(invoice: invoice)
            } else if let session = viewModel.selectedSessions.first {
                NDISBillingContextView(
                    billingContext: viewModel.contextBinding(for: session),
                    session: session,
                    shouldAutoDetermine: viewModel.shouldAutoDetermine
                )
                .environment(\.modelContext, modelContext)
            } else {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Session Selected",
                    message: "Select a client and session to preview the invoice"
                )
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color("Background", bundle: .sharedUI))
    }
}

private struct GeneratedInvoiceSummaryView: View {
    let invoice: InvoiceEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Generated Invoice")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Invoice #: \(invoice.invoiceNumber)")
                .font(.body)
            Text("Date: \(invoice.date, style: .date)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Total: $\(String(format: "%.2f", invoice.totalAmount))")
                .font(.headline)
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}
