//
//  ClientMultiSelector.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 4/4/2025.
//


//
//  ClientMultiSelector.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//  (Originally in RelationshipsView.swift)
//

import SwiftUI
import Core
import SharedUI

// Extracted Client Multi-Selector for Sheet (Domain Model-based)
struct ClientMultiSelector: View {
    let allClients: [Client]
    @Binding var selectedClientIDs: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredClients: [Client] {
        if searchText.isEmpty {
            return allClients
        } else {
            return allClients.filter {
                ($0.fullName.localizedCaseInsensitiveContains(searchText)) ||
                ($0.ndisNumber.localizedCaseInsensitiveContains(searchText))
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Select Clients")
                    .font(.title2.bold())
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                TextField("Search Clients", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            // Client list
            List {
                ForEach(filteredClients, id: \.id) { client in
                    Button {
                        toggleSelection(clientID: client.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.fullName)
                                    .foregroundColor(Color(NSColor.labelColor))
                                if !client.ndisNumber.isEmpty {
                                    Text("NDIS: \(client.ndisNumber)")
                                        .font(.caption)
                                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                                }
                            }
                            Spacer()
                            if selectedClientIDs.contains(client.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(NSColor.systemBlue))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                            }
                        }
                    }
                    .buttonStyle(.plain) // Make the whole row clickable
                    .appInteractiveCursor()
                }
            }
        }
        .frame(minWidth: 350, idealWidth: 400, minHeight: 400, idealHeight: 500) // Adjust frame
    }

    private func toggleSelection(clientID: UUID) {
        if selectedClientIDs.contains(clientID) {
            selectedClientIDs.remove(clientID)
        } else {
            selectedClientIDs.insert(clientID)
        }
    }
}
