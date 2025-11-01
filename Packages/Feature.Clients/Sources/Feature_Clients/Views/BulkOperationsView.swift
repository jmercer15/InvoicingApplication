import SwiftUI
import SwiftData
import Data
import SharedUI

struct BulkOperationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let selectedClients: [ClientEntity]
    let selectedPayees: [PayeeEntity]
    let selectedPlanManagers: [PlanManagerEntity]
    
    @State private var showingStatusChange = false
    @State private var showingDeleteConfirmation = false
    @State private var newStatus = "Active"
    @State private var isProcessing = false
    
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
        .background(Color.gray.opacity(0.1))
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var totalSelectedCount: Int {
        selectedClients.count + selectedPayees.count + selectedPlanManagers.count
    }
    
    private func changeStatus() {
        isProcessing = true
        
        // Change status for all selected entities
        for client in selectedClients {
            client.status = ClientStatus(rawValue: newStatus) ?? .active
        }
        
        for payee in selectedPayees {
            payee.status = newStatus
        }
        
        // Save changes
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving status changes: \(error)")
        }
        
        isProcessing = false
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
        
        // Delete all selected entities
        for client in selectedClients {
            modelContext.delete(client)
        }
        
        for payee in selectedPayees {
            modelContext.delete(payee)
        }
        
        for planManager in selectedPlanManagers {
            modelContext.delete(planManager)
        }
        
        // Save changes
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting entities: \(error)")
        }
        
        isProcessing = false
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
            .background(Color.gray.opacity(0.1))
        }
    }
} 
