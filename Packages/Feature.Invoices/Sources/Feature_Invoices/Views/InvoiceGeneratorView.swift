import SwiftUI
import SwiftData // Import SwiftData
import Foundation
import EventKit
import SharedUI
import Data
import Core

// Represents a single session instance (recurring or not)
struct InvoiceSessionInstance: Identifiable, Hashable, Equatable {
    let id: UUID = UUID()
    let session: SessionEntity
    let instanceStart: Date
    let instanceEnd: Date
    var isRecurring: Bool { session.recurrenceRuleData != nil }

    static func == (lhs: InvoiceSessionInstance, rhs: InvoiceSessionInstance) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct InvoiceGeneratorView: View {
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\ClientEntity.fullName)]) // Use @Query
    private var clients: [ClientEntity]

    @State private var selectedInstances: Set<InvoiceSessionInstance> = []
    @State private var showingGenerateConfirmation = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate: Date = .now
    @State private var sessionInstancesByClient: [UUID: (ClientEntity, [InvoiceSessionInstance])] = [:]

    var body: some View {
        VStack(spacing: 0) {
            titleView
            datePickerView
            Divider()
            clientSessionSelectionView
            Divider()
            actionButtonsView
        }
        .onAppear(perform: loadSessionInstances)
        .onChange(of: startDate) { _, _ in loadSessionInstances() }
        .onChange(of: endDate) { _, _ in loadSessionInstances() }
        .background(Color("Background", bundle: .sharedUI))
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusMedium)
        .shadow(radius: 8)
        .frame(minWidth: 700, idealWidth: 800, minHeight: 500, idealHeight: 600)
        .confirmationDialog(
            "Generate Invoices",
            isPresented: $showingGenerateConfirmation,
            actions: {
                Button("Generate", role: .none) {
                    generateInvoices()
                }
                .appInteractiveCursor()
                Button("Cancel", role: .cancel) {}
                .appInteractiveCursor()
            },
            message: {
                Text("This will generate \(selectedInstances.count) new invoice(s) with \(selectedInstances.count) session(s). Continue?")
            }
        )
    }

    private var titleView: some View {
        Text("Generate Invoices from Schedule")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(Color.primary)
            .padding(.bottom, 20)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var datePickerView: some View {
        HStack {
            DatePicker("From", selection: $startDate, displayedComponents: .date)
            DatePicker("To", selection: $endDate, displayedComponents: .date)
        }
        .padding(.horizontal)
    }

    private var clientSessionSelectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Clients and Sessions:")
                .font(.headline)
                .padding([.horizontal, .top], 15)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(clients) { client in
                        let tuple = sessionInstancesByClient[client.id]
                        InvoiceClientSessionSelectionRow(
                            client: client,
                            sessionInstances: tuple?.1 ?? [],
                            selectedInstances: $selectedInstances
                        )
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 10)
            }
            .padding(.top, 5)
        }
        .background(Color.cardBackground)
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var actionButtonsView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .appInteractiveCursor()

            Spacer()

            Button("Generate Invoices (\(selectedInstances.count))", action: {
                showingGenerateConfirmation = true
            })
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .appInteractiveCursor()
            .disabled(selectedInstances.isEmpty)
        }
        .padding(20)
    }

    private func loadSessionInstances() {
        var result: [UUID: (ClientEntity, [InvoiceSessionInstance])] = [:]
        let start = startDate
        let end = endDate
        for client in clients {
            // Fetch all sessions for this client (no predicate on dynamic variables)
            let sessionsDescriptor = FetchDescriptor<SessionEntity>(sortBy: [SortDescriptor(\SessionEntity.startTime)])
            let sessions: [SessionEntity] = (try? modelContext.fetch(sessionsDescriptor)) ?? []
            var instances: [InvoiceSessionInstance] = []
            for session in sessions {
                // In-memory filtering for client and date
                guard session.client?.id == client.id else { continue }
                if let ruleData = session.recurrenceRuleData, let rule = RecurrenceService().decodeRecurrenceRule(from: ruleData), let masterStart = session.startTime, let masterEnd = session.endTime {
                    if let recurrenceEnd = rule.recurrenceEnd?.endDate, recurrenceEnd < start {
                        continue
                    }
                    let expanded = RecurrenceExpansion.expandInstances(
                        for: session,
                        rule: rule,
                        masterStartTime: masterStart,
                        masterEndTime: masterEnd,
                        rangeStart: start,
                        rangeEnd: end
                    )
                    for occ in expanded {
                        instances.append(InvoiceSessionInstance(session: session, instanceStart: occ.instanceStart, instanceEnd: occ.instanceEnd))
                    }
                } else if let s = session.startTime, let e = session.endTime, s >= start, s <= end {
                    instances.append(InvoiceSessionInstance(session: session, instanceStart: s, instanceEnd: e))
                }
            }
            // Fetch all detached sessions for this client (no predicate on dynamic variables)
            let detachedSessionsDescriptor = FetchDescriptor<SessionEntity>(sortBy: [SortDescriptor(\SessionEntity.startTime)])
            let detachedSessions: [SessionEntity] = (try? modelContext.fetch(detachedSessionsDescriptor)) ?? []
            for detached in detachedSessions {
                // In-memory filtering for detached, client, and date
                guard detached.client?.id == client.id, detached.isDetached == true, let occDate = detached.occurrenceDate, occDate >= start, occDate <= end else { continue }
                if let s = detached.startTime, let e = detached.endTime {
                    instances.append(InvoiceSessionInstance(session: detached, instanceStart: s, instanceEnd: e))
                }
            }
            result[client.id] = (client, instances.sorted { $0.instanceStart < $1.instanceStart })
        }
        sessionInstancesByClient = result

        selectedInstances = selectedInstances.filter { inst in
            guard let clientID = inst.session.client?.id else { return false }
            return sessionInstancesByClient[clientID]?.1.contains(inst) ?? false
        }
    }

    private func generateInvoices() {
        // Group selected instances by client.id
        let instancesByClientID = Dictionary(grouping: selectedInstances) { $0.session.client?.id }
        
        for (clientID, instances) in instancesByClientID {
            guard let clientID = clientID, let (client, _) = sessionInstancesByClient[clientID] else { continue }
            
            // Check if client has NDIS number and services with NDIS items
            let hasNDISServices = instances.contains { (instance: InvoiceSessionInstance) in
                instance.session.clientService?.ndisItem != nil
            }
            
            let newInvoice: InvoiceEntity
            
            if hasNDISServices {
                // Use NDIS billing algorithm
                do {
                    let ndisIntegrationService = NDISBillingIntegrationService(modelContext: modelContext)
                    let sessions = instances.map { $0.session }
                    newInvoice = try ndisIntegrationService.generateNDISInvoice(for: sessions, client: client)
                    print("Generated NDIS invoice for client: \(client.fullName), Total: \(newInvoice.totalAmount)")
                } catch {
                    print("Error generating NDIS invoice, falling back to simple billing: \(error)")
                    newInvoice = generateSimpleInvoice(for: instances, client: client)
                }
            } else {
                // Use simple billing
                newInvoice = generateSimpleInvoice(for: instances, client: client)
            }
            
            modelContext.insert(newInvoice)
        }
        
        do {
            try modelContext.save()
            print("Successfully generated and saved invoices.")
        } catch {
            print("Error saving generated invoices: \(error)")
        }
        dismiss()
    }
    
    private func generateSimpleInvoice(for instances: [InvoiceSessionInstance], client: ClientEntity) -> InvoiceEntity {
        let newInvoice = InvoiceEntity(id: UUID(), invoiceNumber: "")
        newInvoice.issueDate = Date()
        newInvoice.dueDate = Calendar.current.date(byAdding: .day, value: AppConstants.defaultInvoiceDueDays, to: newInvoice.issueDate) ?? Date()
        newInvoice.status = .draft
        newInvoice.client = client
        newInvoice.discount = 0.0
        newInvoice.taxRate = UserDefaults.standard.double(forKey: "defaultTaxRate")
        newInvoice.creditApplied = 0.0
        newInvoice.paymentTerms = UserDefaults.standard.string(forKey: "defaultPaymentTerms") ?? "Payment due within \(AppConstants.defaultInvoiceDueDays) days."
        newInvoice.currencyCode = "AUD"
        
        newInvoice.invoiceNumber = InvoiceNumberingService.nextNumber(for: client, context: modelContext)
        
        var totalAmount: Double = 0.0
        
        for (index, instance) in instances.enumerated() {
            if let clientService = instance.session.clientService {
                let newItem = InvoiceItemEntity(id: UUID(), itemDescription: clientService.computedServiceName)
                if clientService.computedUnit.lowercased() == "hour" {
                    let duration = instance.instanceEnd.timeIntervalSince(instance.instanceStart) / 3600.0
                    newItem.quantity = duration
                } else {
                    newItem.quantity = 1.0
                }
                newItem.rate = clientService.computedRate
                newItem.unit = clientService.computedUnit
                newItem.position = Int32(index)
                newItem.serviceDate = instance.instanceStart
                newItem.invoice = newInvoice
                newItem.session = instance.session
                newItem.date = instance.instanceStart
                totalAmount += (newItem.quantity * newItem.rate)
                modelContext.insert(newItem)
            }
        }
        
        let discountAmount = totalAmount * (newInvoice.discount / 100.0)
        let taxableSubtotal = totalAmount - discountAmount
        let taxAmount = taxableSubtotal * (newInvoice.taxRate / 100.0)
        newInvoice.totalAmount = taxableSubtotal + taxAmount - newInvoice.creditApplied
        newInvoice.date = Date()
        
        // Snapshot related entity data into the invoice's own properties
        // Note: InvoiceEntity stores data directly, no snapshot method needed
        
        print("Generated simple invoice for client: \(client.fullName), Total: \(newInvoice.totalAmount)")
        return newInvoice
    }
}

// Updated row for selecting session instances
struct InvoiceClientSessionSelectionRow: View {
    let client: ClientEntity
    let sessionInstances: [InvoiceSessionInstance]
    @Binding var selectedInstances: Set<InvoiceSessionInstance>
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider().background(Color.accentColor.opacity(0.3))
            sessionInstancesView
        }
        .background(Color.cardBackground)
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
        .overlay(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall).stroke(Color.cardBorder, lineWidth: 1))
    }

    private var headerView: some View {
        HStack {
            Text(client.fullName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Color.primary)
            Spacer()
            if sessionInstances.contains(where: { selectedInstances.contains($0) }) {
                Text("\(sessionInstances.filter { selectedInstances.contains($0) }.count) of \(sessionInstances.count) Selected")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            Toggle(isOn: Binding(
                get: { !sessionInstances.isEmpty && sessionInstances.allSatisfy { selectedInstances.contains($0) } },
                set: { selectAll in
                    if selectAll {
                        selectedInstances.formUnion(sessionInstances)
                    } else {
                        for inst in sessionInstances { selectedInstances.remove(inst) }
                    }
                }
            )) {
                Text("Select All").font(.caption)
            }
            .toggleStyle(.switch)
            .appInteractiveCursor()
            .disabled(sessionInstances.isEmpty)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.accentColor.opacity(0.1))
    }

    private var sessionInstancesView: some View {
        VStack(alignment: .leading, spacing: 5) {
            if sessionInstances.isEmpty {
                Text("No sessions found for this client.")
                    .font(.callout)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(sessionInstances) { inst in
                    Toggle(isOn: Binding(
                        get: { selectedInstances.contains(inst) },
                        set: { isSelected in
                            if isSelected { selectedInstances.insert(inst) } else { selectedInstances.remove(inst) }
                        }
                    )) {
                        Text("\(inst.session.title) - \(inst.instanceStart, formatter: dateFormatter)")
                            .font(.body)
                            .foregroundColor(Color.secondary)
                    }
                    .toggleStyle(.checkbox)
                    .appInteractiveCursor()
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(12)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()
 
