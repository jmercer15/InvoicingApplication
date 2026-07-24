import SwiftUI
import Core
import SharedUI

extension EditingPanel {
    
    internal var serviceTypeField: some View {
        TextField(text: $editedService) { Text("Service Type") }
            .submitLabel(.next)
            .focused($focusedField, equals: .serviceType)
            .textContentType(.name)
            .textFieldStyle(.roundedBorder)
            .help("The type of service provided during this session")
            .onAppear {
                switch card {
                case .session(let sessionData):
                    editedService = sessionData.serviceName
                case .invoice(let invoiceData):
                    editedService = invoiceData.serviceName
                }
            }
    }
    
    internal var durationAmountRow: some View {
        Group {
            switch card {
            case .session(let sessionData):
                TextField(text: $editedDuration) { Text("Duration") }
                    .submitLabel(.next)
                    .focused($focusedField, equals: .duration)
                    .textFieldStyle(.roundedBorder)
                    .help("The total duration of the session (e.g., 1h 30m)")
                    .onAppear {
                        editedDuration = sessionData.duration
                    }
            case .invoice(let invoiceData):
                LabeledContent("Amount", value: invoiceData.amount)
                    .monospacedDigit()
                    .help("Edit invoice line items and totals in Invoices workspace")
            }
        }
    }
    
    internal var clientField: some View {
        TextField(text: $editedClient) { Text("Client Name") }
            .submitLabel(.done)
            .focused($focusedField, equals: .client)
            .textContentType(.name)
            .textFieldStyle(.roundedBorder)
            .help("The name of the client associated with this record")
            .onAppear {
                switch card {
                case .session(let sessionData):
                    editedClient = sessionData.clientName
                case .invoice(let invoiceData):
                    editedClient = invoiceData.clientName
                }
            }
    }
    
    internal var priorityLevelSection: some View {
        Picker("Priority Level", selection: $selectedPriority) {
            Text("Low").tag(Priority.low)
            Text("Medium").tag(Priority.medium)
            Text("High").tag(Priority.high)
        }
        .pickerStyle(.segmented)
        .help("Set the urgency level for this session or invoice")
        .onAppear {
            switch card {
            case .session(let sessionData):
                selectedPriority = sessionData.priority
            case .invoice(let invoiceData):
                selectedPriority = invoiceData.priority
            }
        }
    }
}
