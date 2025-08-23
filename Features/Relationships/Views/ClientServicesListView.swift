import SwiftUI
import SwiftData // Import SwiftData

struct ClientServicesListView: View {
    @Environment(\.modelContext) private var modelContext // Change to modelContext

    // The client whose services we want to display
    let client: ClientEntity

    // Actions handled by the parent view
    let onEditInSheet: (ClientServiceEntity) -> Void
    
    // Internal state for inline editing
    @State private var serviceToEditInline: ClientServiceEntity? = nil

    // Fetch Request specifically for the services of the provided client
    @Query(animation: .default)
    var allClientServices: [ClientServiceEntity]
    
    // Computed property to filter services for the specific client
    var fetchedClientServices: [ClientServiceEntity] {
        allClientServices.filter { $0.client?.id == client.id }
    }
    


    // Initializer to configure the FetchRequest based on the client
    init(
        client: ClientEntity,
        onEditInSheet: @escaping (ClientServiceEntity) -> Void
        ) {
        self.client = client
        self.onEditInSheet = onEditInSheet
        // No direct _fetchedClientServices initialization here, as @Query manages it
    }

    var body: some View {
        if fetchedClientServices.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "list.bullet.clipboard")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                Text("No services assigned to this client.")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(allClientServices.sorted {
                        if $0.isActive != $1.isActive {
                            return $0.isActive && !$1.isActive // Active first
                        }
                        return $0.serviceName.localizedCaseInsensitiveCompare($1.serviceName) == .orderedAscending
                    }) { service in
                        if service == serviceToEditInline {
                            // Show inline editor for the selected service
                            let isCustomService = serviceToEditInline?.ndisItem == nil
                            let editorId = "editor-\(service.id.uuidString)"
                            
                            ClientServiceEditorView(
                                service: $serviceToEditInline,
                                isEditingExistingService: true,
                                restrictEditing: true,
                                isCustomService: isCustomService,
                                onSave: { _ in
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        // Handle save error if necessary
                                        print("Failed to save inline service edit: \(error)")
                                        modelContext.rollback()
                                    }
                                    serviceToEditInline = nil // Close the editor
                                },
                                onCancel: {
                                    // Rollback any changes made in the editor
                                    if modelContext.hasChanges {
                                        modelContext.rollback()
                                    }
                                    serviceToEditInline = nil // Close the editor
                                }
                            )
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 5)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .id(editorId)
                            
                        } else {
                            // Show standard display row
                            ClientServiceRow(
                                service: service,
                                onEditInSheet: { onEditInSheet(service) },
                                onEditInline: { serviceToEditInline = service },
                                onToggleActive: { toggleServiceActiveStatus(service) },
                                onDelete: { deleteService(service) }
                            )
                            .transition(.asymmetric(insertion: .move(edge: .top), removal: .identity))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
        }
    }
    
    private func toggleServiceActiveStatus(_ service: ClientServiceEntity) {
        service.isActive.toggle()
        saveContext()
    }
    
    private func deleteService(_ service: ClientServiceEntity) {
        modelContext.delete(service)
        saveContext()
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

// MARK: - Client Service Row

struct ClientServiceRow: View {
    let service: ClientServiceEntity
    let onEditInSheet: () -> Void
    let onEditInline: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    @State private var showDeleteConfirmation = false
    
    private var accentColor: Color {
        Color(hex: "#3949AB")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            serviceInfoSection
            rateInfoSection
            StatusBadge(status: service.isActive ? "Active" : "Inactive")
                .frame(width: 75, alignment: .center)
            actionButtonsSection
        }
        .padding(12)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 5)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .appInteractiveCursor()
        .contextMenu {
            Button("Edit Inline") { onEditInline() }
            Button("Edit in Sheet...") { onEditInSheet() }
            Divider()
            Button(service.isActive ? "Deactivate" : "Activate") { onToggleActive() }
            Button("Delete", role: .destructive) { showDeleteConfirmation = true }
        }
        .alert("Delete Service", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete this service? This action cannot be undone.")
        }
    }
    
    private var serviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(service.computedServiceName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(service.isActive ? .primary : .secondary)
                .lineLimit(1)
            
            if let ndisCode = service.computedNdisCode, !ndisCode.isEmpty {
                ndisCodeBadge(ndisCode)
            } else {
                // Show a "Custom" badge for non-NDIS services
                customServiceBadge()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func ndisCodeBadge(_ code: String) -> some View {
        HStack(spacing: 6) {
            Text("NDIS")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.7))
                        .overlay(Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1))
                )
            
            Text(code)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                )
        }
    }
    
    private func customServiceBadge() -> some View {
        HStack(spacing: 6) {
            Text("CUSTOM")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.7))
                        .overlay(Capsule().stroke(Color.purple.opacity(0.3), lineWidth: 1))
                )
            
            if let description = service.ndisCode, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private var rateInfoSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(service.computedRate, format: .currency(code: "AUD"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(service.isActive ? .primary : .secondary)
            
            Text("per \(service.computedUnit)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 90, alignment: .trailing)
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 6) {
            ServiceActionButton(
                icon: "pencil",
                color: accentColor,
                action: onEditInline,
                helpText: "Edit service inline"
            )
            
            ServiceActionButton(
                icon: service.isActive ? "pause.fill" : "play.fill",
                color: service.isActive ? .orange : .green,
                action: onToggleActive,
                helpText: service.isActive ? "Deactivate service" : "Activate service"
            )
            
            ServiceActionButton(
                icon: "trash",
                color: .red,
                action: { showDeleteConfirmation = true },
                helpText: "Delete service"
            )
        }
    }
}

// MARK: - Service Action Button

struct ServiceActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    let helpText: String
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? color : .clear)
                
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(color, lineWidth: 1.5)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isHovering ? .white : color)
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .appInteractiveCursor()
        .help(helpText)
    }
}

// Helper View for List Row Background with Hover Effect
struct RowBackground: View {
    @State private var isHovering = false

    var body: some View {
        Color.clear // Default clear background
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovering ? Color.primary.opacity(0.05) : Color.clear)
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

// Helper extension for ClientServiceEntity to handle custom services
extension ClientServiceEntity {
    var computedServiceName: String {
        return serviceName
    }
    
    var computedRate: Double {
        return rate
    }
    
    var computedUnit: String {
        return unit
    }
    
    var computedNdisCode: String? {
        return ndisCode
    }
} 
