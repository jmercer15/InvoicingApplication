import SwiftUI
import SwiftData // Import SwiftData (still needed for ModelContext access in NDIS service)
import Foundation
import EventKit
import SharedUI
import Data
import Core

// Represents a single session instance (recurring or not)
struct InvoiceSessionInstance: Identifiable, Hashable, Equatable {
    let id: UUID = UUID()
    let session: Session // Changed to domain model
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
    @Environment(\.modelContext) private var modelContext // Still needed for NDIS service and InvoiceNumberingService
    @Environment(\.dismiss) private var dismiss
    
    // Dependencies injected from parent
    let clientsRepository: ClientsRepository
    let sessionsRepository: SessionsRepository
    let invoicesRepository: InvoicesRepository
    let clientServicesRepository: ClientServicesRepository

    @State private var allClients: [Client] = [] // Changed to domain model
    @State private var selectedInstances: Set<InvoiceSessionInstance> = []
    @State private var showingGenerateConfirmation = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate: Date = .now
    @State private var sessionInstancesByClient: [UUID: (Client, [InvoiceSessionInstance])] = [:] // Changed to domain model
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            titleView
            datePickerView
            Divider()
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                clientSessionSelectionView
            }
            Divider()
            actionButtonsView
        }
        .task {
            await loadData()
        }
        .onChange(of: startDate) { _, _ in
            Task { await loadSessionInstances() }
        }
        .onChange(of: endDate) { _, _ in
            Task { await loadSessionInstances() }
        }
        .background(Color("Background", bundle: .sharedUI))
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusMedium)
        .shadow(radius: 8)
        .frame(minWidth: 700, idealWidth: 800, minHeight: 500, idealHeight: 600)
        .confirmationDialog(
            "Generate Invoices",
            isPresented: $showingGenerateConfirmation,
            actions: {
                Button("Generate", role: .none) {
                    Task { await generateInvoices() }
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
    
    private func loadData() async {
        isLoading = true
        do {
            allClients = try await clientsRepository.fetchAll()
            await loadSessionInstances()
        } catch {
            print("Error loading clients: \(error)")
        }
        isLoading = false
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
                    ForEach(allClients) { client in
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

    private func loadSessionInstances() async {
        var result: [UUID: (Client, [InvoiceSessionInstance])] = [:]
        let start = startDate
        let end = endDate
        
        for client in allClients {
            do {
                // Fetch all sessions for this client using repository
                let sessions = try await sessionsRepository.fetch(byClientId: client.id)
                var instances: [InvoiceSessionInstance] = []
                
                for session in sessions {
                    // Filter by date range
                    guard let sessionStart = session.startTime, 
                          let sessionEnd = session.endTime else { continue }
                    
                    // Handle recurring sessions
                    if let ruleData = session.recurrenceRuleData,
                       let rule = RecurrenceService().decodeRecurrenceRule(from: ruleData) {
                        if let recurrenceEnd = rule.recurrenceEnd?.endDate, recurrenceEnd < start {
                            continue
                        }
                        let expanded = RecurrenceExpansion.expandInstances(
                            for: session,
                            rule: rule,
                            masterStartTime: sessionStart,
                            masterEndTime: sessionEnd,
                            rangeStart: start,
                            rangeEnd: end
                        )
                        for occ in expanded {
                            instances.append(InvoiceSessionInstance(
                                session: session,
                                instanceStart: occ.instanceStart,
                                instanceEnd: occ.instanceEnd
                            ))
                        }
                    } else if sessionStart >= start && sessionStart <= end {
                        // Non-recurring session within date range
                        instances.append(InvoiceSessionInstance(
                            session: session,
                            instanceStart: sessionStart,
                            instanceEnd: sessionEnd
                        ))
                    }
                }
                
                // Note: Detached sessions are not yet supported via repository
                // This is a limitation - detached sessions would need a separate repository method
                // For now, we skip detached sessions as they require direct entity access
                
                result[client.id] = (client, instances.sorted { $0.instanceStart < $1.instanceStart })
            } catch {
                print("Error loading sessions for client \(client.id): \(error)")
            }
        }
        
        sessionInstancesByClient = result

        // Filter selected instances to only include those still available
        selectedInstances = selectedInstances.filter { inst in
            guard let clientID = inst.session.clientId else { return false }
            return sessionInstancesByClient[clientID]?.1.contains(inst) ?? false
        }
    }

    private func generateInvoices() async {
        // Group selected instances by client.id
        let instancesByClientID = Dictionary(grouping: selectedInstances) { $0.session.clientId }
        
        for (clientID, instances) in instancesByClientID {
            guard let clientID = clientID, let (client, _) = sessionInstancesByClient[clientID] else { continue }
            
            // Check if client has NDIS services
            // Note: This requires fetching client services to check for NDIS items
            var hasNDISServices = false
            do {
                let clientServices = try await clientServicesRepository.fetch(for: clientID)
                hasNDISServices = instances.contains { instance in
                    guard let serviceId = instance.session.clientServiceId else { return false }
                    return clientServices.contains { $0.id == serviceId && $0.ndisItemId != nil }
                }
            } catch {
                print("Error checking NDIS services: \(error)")
            }
            
            if hasNDISServices {
                // Use NDIS billing algorithm with domain models
                do {
                    let ndisIntegrationService = NDISBillingIntegrationService(modelContext: modelContext)
                    let sessions = instances.map { $0.session }
                    let invoice = try ndisIntegrationService.generateNDISInvoice(for: sessions, client: client)
                    
                    // Save via repository
                    _ = try await invoicesRepository.update(invoice)
                    
                    print("Generated NDIS invoice for client: \(client.fullName), Total: \(invoice.totalAmount)")
                } catch {
                    print("Error generating NDIS invoice, falling back to simple billing: \(error)")
                    _ = try? await generateSimpleInvoice(for: instances, client: client)
                }
            } else {
                // Use simple billing with domain models
                do {
                    _ = try await generateSimpleInvoice(for: instances, client: client)
                } catch {
                    print("Error generating simple invoice: \(error)")
                }
            }
        }
        
        dismiss()
    }
    
    // MARK: - Simple Invoice Generation
    
    private func generateSimpleInvoice(for instances: [InvoiceSessionInstance], client: Client) async throws -> Invoice {
        // Generate invoice number using domain model
        let invoiceNumber = InvoiceNumberingService.nextNumber(for: client, context: modelContext)
        
        // Create invoice domain model
        let invoice = Invoice(
            id: UUID(),
            invoiceNumber: invoiceNumber,
            totalAmount: 0.0,
            taxRate: UserDefaults.standard.double(forKey: "defaultTaxRate"),
            creditApplied: 0.0,
            discount: 0.0,
            date: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: AppConstants.defaultInvoiceDueDays, to: Date()),
            invoiceID: nil,
            issueDate: Date(),
            notes: nil,
            paidDate: nil,
            paymentTerms: UserDefaults.standard.string(forKey: "defaultPaymentTerms") ?? "Payment due within \(AppConstants.defaultInvoiceDueDays) days.",
            status: AppConstants.invoiceStatusDraft,
            sentDate: nil,
            currencyCode: "AUD",
            clientId: client.id,
            sessionIds: instances.map { $0.session.id }
        )
        
        // Save invoice via repository
        let savedInvoice = try await invoicesRepository.create(invoice)
        
        // Fetch client services for creating invoice items
        let clientServices = try await clientServicesRepository.fetch(for: client.id)
        var totalAmount: Double = 0.0
        
        // Create invoice items
        for (index, instance) in instances.enumerated() {
            guard let serviceId = instance.session.clientServiceId,
                  let clientService = clientServices.first(where: { $0.id == serviceId }) else {
                continue
            }
            
            let quantity: Double
            if clientService.unit.lowercased() == "hour" {
                quantity = instance.instanceEnd.timeIntervalSince(instance.instanceStart) / 3600.0
            } else {
                quantity = 1.0
            }
            
            // Note: InvoiceItem domain model doesn't include unit or serviceDate
            // These are stored at the entity level but not exposed in the domain model
            let invoiceItem = InvoiceItem(
                id: UUID(),
                invoiceId: savedInvoice.id,
                sessionId: instance.session.id,
                clientServiceId: serviceId,
                itemDescription: clientService.serviceName,
                quantity: quantity,
                rate: clientService.rate,
                position: Int32(index)
            )
            
            _ = try await invoicesRepository.addItem(invoiceItem)
            totalAmount += (quantity * clientService.rate)
        }
        
        // Calculate totals and update invoice
        let discountAmount = totalAmount * (invoice.discount / 100.0)
        let taxableSubtotal = totalAmount - discountAmount
        let taxAmount = taxableSubtotal * (invoice.taxRate / 100.0)
        let finalTotal = taxableSubtotal + taxAmount - invoice.creditApplied
        
        // Create updated invoice with new total (Invoice is immutable)
        let updatedInvoice = Invoice(
            id: savedInvoice.id,
            invoiceNumber: savedInvoice.invoiceNumber,
            totalAmount: finalTotal,
            taxRate: savedInvoice.taxRate,
            creditApplied: savedInvoice.creditApplied,
            discount: savedInvoice.discount,
            date: savedInvoice.date,
            dueDate: savedInvoice.dueDate,
            invoiceID: savedInvoice.invoiceID,
            issueDate: savedInvoice.issueDate,
            notes: savedInvoice.notes,
            paidDate: savedInvoice.paidDate,
            paymentTerms: savedInvoice.paymentTerms,
            status: savedInvoice.status,
            sentDate: savedInvoice.sentDate,
            currencyCode: savedInvoice.currencyCode,
            businessName: savedInvoice.businessName,
            businessABN: savedInvoice.businessABN,
            businessEmail: savedInvoice.businessEmail,
            businessAddress: savedInvoice.businessAddress,
            businessPhone: savedInvoice.businessPhone,
            clientName: savedInvoice.clientName,
            clientNDISNumber: savedInvoice.clientNDISNumber,
            clientEmail: savedInvoice.clientEmail,
            clientPhone: savedInvoice.clientPhone,
            clientAddress: savedInvoice.clientAddress,
            billingAuthority: savedInvoice.billingAuthority,
            billToName: savedInvoice.billToName,
            billToEmail: savedInvoice.billToEmail,
            billToAddress: savedInvoice.billToAddress,
            payeeName: savedInvoice.payeeName,
            payeeEmail: savedInvoice.payeeEmail,
            payeePhone: savedInvoice.payeePhone,
            payeeAddress: savedInvoice.payeeAddress,
            bankName: savedInvoice.bankName,
            bankAccountName: savedInvoice.bankAccountName,
            bankBSB: savedInvoice.bankBSB,
            bankAccountNumber: savedInvoice.bankAccountNumber,
            clientId: savedInvoice.clientId,
            businessId: savedInvoice.businessId,
            payeeId: savedInvoice.payeeId,
            sessionIds: savedInvoice.sessionIds
        )
        
        return try await invoicesRepository.update(updatedInvoice)
    }
}

// Updated row for selecting session instances
struct InvoiceClientSessionSelectionRow: View {
    let client: Client // Changed to domain model
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
