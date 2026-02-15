import SwiftUI
import SwiftData
import Core
import Data
import SharedUI

struct BulkOperationsView: View {
    @Environment(\.dismiss) private var dismiss
    
    let selectedClients: [ClientEntity]
    let selectedPayees: [PayeeEntity]
    let selectedPlanManagers: [PlanManagerEntity]
    
    // Repositories - should be injected, but using environment for now
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingStatusChange = false
    @State private var showingDeleteConfirmation = false
    @State private var newStatus = "Active"
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Lazy repositories (created from modelContext)
    private var clientsRepository: ClientsRepository {
        ClientsRepositorySwiftData(modelContext: modelContext)
    }
    
    private var payeesRepository: PayeeRepository {
        PayeeRepositorySwiftData(modelContext: modelContext)
    }
    
    private var planManagersRepository: PlanManagerRepository {
        PlanManagerRepositorySwiftData(modelContext: modelContext)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Bulk Operations")
                    .font(.title2.bold())
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal)
            
            // Summary
            summarySection
            
            // Operations
            operationsSection
            
            Spacer()
        }
        .padding()
        .alert("Change Status", isPresented: $showingStatusChange) {
            Picker("New Status", selection: $newStatus) {
                ForEach(["Active", "Inactive", "Archived"], id: \.self) { status in
                    Text(status).tag(status)
                }
            }
            Button("Cancel", role: .cancel) { }
            Button("Change") { changeStatus() }
        } message: {
            Text("Change status for \(totalSelectedCount) selected items?")
        }
        .alert("Delete Items", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteSelected() }
        } message: {
            Text("Are you sure you want to delete \(totalSelectedCount) selected items? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .background { AppMeshBackdrop() }
        .overlay {
            if isProcessing {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(.thickMaterial)
                    .cornerRadius(8)
            }
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Items")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(selectedClients.count) Clients")
                        .foregroundColor(Color("Primary", bundle: .sharedUI))
                    Text("\(selectedPayees.count) Payees")
                        .foregroundColor(Color("Active", bundle: .sharedUI))
                    Text("\(selectedPlanManagers.count) Plan Managers")
                        .foregroundColor(Color("Inactive", bundle: .sharedUI))
                }
                
                Spacer()
                
                Text("Total: \(totalSelectedCount)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
        .cornerRadius(8)
    }
    
    private var operationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Operations")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Status Change
                Button(action: { showingStatusChange = true }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Change Status")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.glass)
                .disabled(totalSelectedCount == 0)
                
                // Export
                Button(action: exportSelected) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Selected")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.glass)
                .disabled(totalSelectedCount == 0)
                
                // Delete
                Button(action: { showingDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Selected")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.glass)
                .foregroundColor(Color("Cancelled", bundle: .sharedUI))
                .disabled(totalSelectedCount == 0)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
        .cornerRadius(8)
    }
    
    private var totalSelectedCount: Int {
        selectedClients.count + selectedPayees.count + selectedPlanManagers.count
    }
    
    private func changeStatus() {
        isProcessing = true
        
        Task {
            do {
                // Update clients using repository
                for clientEntity in selectedClients {
                    let clientDomain = ClientMapper().mapToDomain(clientEntity)
                    // Create updated client with new status
                    let updatedClient = Client(
                        id: clientDomain.id,
                        ndisNumber: clientDomain.ndisNumber,
                        fullName: clientDomain.fullName,
                        status: newStatus,
                        email: clientDomain.email,
                        notes: clientDomain.notes,
                        phone: clientDomain.phone,
                        creditAmount: clientDomain.creditAmount,
                        isMinor: clientDomain.isMinor,
                        hasNdisPlan: clientDomain.hasNdisPlan,
                        planManagementType: clientDomain.planManagementType,
                        billingAuthority: clientDomain.billingAuthority,
                        address: clientDomain.address,
                        planManager: clientDomain.planManager,
                        payee: clientDomain.payee,
                        sendInvoicesToClient: clientDomain.sendInvoicesToClient,
                        sendInvoicesToPayee: clientDomain.sendInvoicesToPayee,
                        sendInvoicesToPlanManager: clientDomain.sendInvoicesToPlanManager
                    )
                    try await clientsRepository.update(updatedClient)
                }
                
                // Update payees using repository
                for payeeEntity in selectedPayees {
                    let payeeDomain = PayeeMapper().mapToDomain(payeeEntity)
                    // Create updated payee with new status
                    let updatedPayee = Payee(
                        id: payeeDomain.id,
                        fullName: payeeDomain.fullName,
                        email: payeeDomain.email,
                        phone: payeeDomain.phone,
                        address: payeeDomain.address,
                        status: newStatus,
                        relationToClient: payeeDomain.relationToClient
                    )
                    try await payeesRepository.update(updatedPayee)
                }
                
                // Note: Plan managers don't have a status field in the domain model
                // If status changes are needed for plan managers, add status field to PlanManager domain model
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error saving status changes: \(error.localizedDescription)"
                    showingError = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func exportSelected() {
        // Create export data
        var exportData: [String: Any] = [:]
        
        if !selectedClients.isEmpty {
            exportData["clients"] = selectedClients.map { client in
                [
                    "id": client.id.uuidString,
                    "fullName": client.fullName,
                    "ndisNumber": client.ndisNumber,
                    "status": client.status,
                    "email": client.email ?? "",
                    "phone": client.phone ?? ""
                ]
            }
        }
        
        if !selectedPayees.isEmpty {
            exportData["payees"] = selectedPayees.map { payee in
                [
                    "id": payee.id.uuidString,
                    "fullName": payee.fullName,
                    "status": payee.status ?? "Active",
                    "email": payee.email ?? "",
                    "phone": payee.phone ?? ""
                ]
            }
        }
        
        if !selectedPlanManagers.isEmpty {
            exportData["planManagers"] = selectedPlanManagers.map { planManager in
                [
                    "id": planManager.id.uuidString,
                    "businessName": planManager.name ?? "",
                    "abn": planManager.abn,
                    "email": planManager.email ?? "",
                    "phone": planManager.phone ?? ""
                ]
            }
        }
        
        // Convert to JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            // Copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType: .string)
            
            // Show success message
            // In a real app, you might want to show a proper alert or notification
            print("Exported data copied to clipboard")
        }
    }
    
    private func deleteSelected() {
        isProcessing = true
        
        Task {
            do {
                // Delete clients using repository
                for clientEntity in selectedClients {
                    try await clientsRepository.delete(id: clientEntity.id)
                }
                
                // Delete payees using repository
                for payeeEntity in selectedPayees {
                    try await payeesRepository.delete(id: payeeEntity.id)
                }
                
                // Delete plan managers using repository
                for planManagerEntity in selectedPlanManagers {
                    try await planManagersRepository.delete(id: planManagerEntity.id)
                }
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error deleting entities: \(error.localizedDescription)"
                    showingError = true
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Bulk Operations Toolbar
struct BulkOperationsToolbar: View {
    let selectedCount: Int
    let onBulkOperations: () -> Void
    
    var body: some View {
        if selectedCount > 0 {
            HStack {
                Text("\(selectedCount) selected")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                
                Spacer()
                
                Button("Bulk Operations") {
                    onBulkOperations()
                }
                .buttonStyle(.glassProminent)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect())
        }
    }
} 
