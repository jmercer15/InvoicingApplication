import SwiftUI

import SwiftData

struct ClientPickerView: View {
    @Environment(\.modelContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Callback when a client is selected
    let onClientSelected: (ClientEntity) -> Void
    var showCancelButton: Bool = true
    var showSearchField: Bool = true

    @State private var searchText = ""
    
    // Fetch Request for Clients
    @Query(
        sort: [SortDescriptor(\ClientEntity.fullName, order: .forward)]
    ) private var clients: [ClientEntity]

    // Filtered clients based on search text
    private var filteredClients: [ClientEntity] {
        if searchText.isEmpty {
            return Array(clients)
        } else {
            return clients.filter {
                ($0.fullName.localizedCaseInsensitiveContains(searchText)) ||
                ($0.ndisNumber.localizedCaseInsensitiveContains(searchText))
                // Add other searchable fields if needed (email, phone?)
            }
        }
    }

    var body: some View {
        Group {
            if showCancelButton {
                // Standalone mode: VStack with header and buttons
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Select Client")
                            .font(.title2.bold())
                        
                        Spacer()
                        
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.glass)
                    }
                    .padding(.horizontal)
                    
                    content
                }
            } else {
                // Embedded mode: glassmorphic card, no nav chrome
                content
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 4)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(8)
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            // Optional: Section header for assignment context
            if !showCancelButton {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                        .shadow(radius: 2)
                    Text("Choose a Client")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.bottom, 8)
                .padding(.top, 4)
            }
            List(filteredClients) { client in
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: client.colorHex))
                        .frame(width: 4, height: 32)
                    VStack(alignment: .leading) {
                        Text(client.fullName)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Text(client.ndisNumber)
                            .font(.subheadline)
                            .foregroundColor(.accentColor.opacity(0.7))
                    }
                    Spacer()
                    StatusBadge(status: client.status)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onClientSelected(client)
                    if showCancelButton {
                        dismiss()
                    }
                }
                .appInteractiveCursor()
                .listRowBackground(Color.white.opacity(0.05))
            }
            .listStyle(.plain)
            .frame(minWidth: 400, idealWidth: 450, minHeight: 320, idealHeight: 400)
            .if(showSearchField) { view in
                view.searchable(text: $searchText, prompt: "Search Clients...")
            }
        }
        .padding(.horizontal, showCancelButton ? 0 : 16)
        .padding(.vertical, showCancelButton ? 0 : 12)
    }
}
