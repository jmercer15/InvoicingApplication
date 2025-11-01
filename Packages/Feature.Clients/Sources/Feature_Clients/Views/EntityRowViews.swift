//
//  ClientRow.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 4/4/2025.
//


//
//  EntityRowViews.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//  (Originally in RelationshipsView.swift)
//

import SwiftUI
import SwiftData
import Data
import Core
import SharedUI


// MARK: - Row Components

struct ClientRow: View {
    let client: ClientEntity
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(client.fullName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                if !client.ndisNumber.isEmpty {
                    Text("NDIS: \(client.ndisNumber)")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
            }
            
            Spacer()
            
            // Navigation actions (show on hover)
            HStack(spacing: 8) {
                Button("View") { }
                Button("Edit") { }
            }
            .opacity(isHovered ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            StatusBadge(status: client.status.rawValue)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 8))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("View Details") { }
            Button("Edit") { }
            Button("Delete") { }
        }
        .appInteractiveCursor()
    }
}

struct PayeeRow: View {
    let payee: PayeeEntity
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(payee.fullName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                if let relation = payee.relationToClient, !relation.isEmpty {
                    Text("Relation: \(relation)")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
            }
            
            Spacer()
            
            // Navigation actions (show on hover)
            HStack(spacing: 8) {
                Button("View") { }
                Button("Edit") { }
            }
            .opacity(isHovered ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            if let status = payee.status, !status.isEmpty {
                StatusBadge(status: status)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 8))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("View Details") { }
            Button("Edit") { }
            Button("Delete") { }
        }
        .appInteractiveCursor()
    }
}

struct PlanManagerRow: View {
    let planManager: PlanManagerEntity
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(planManager.name ?? "Unknown Plan Manager")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .lineLimit(1)
                
                Text("ABN: \(planManager.abn)")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            Spacer(minLength: 12)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 8))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .appInteractiveCursor()
    }
}