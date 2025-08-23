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
                    .foregroundColor(.white)
                
                if !client.ndisNumber.isEmpty {
                    Text("NDIS: \(client.ndisNumber)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Navigation actions (show on hover)
            NavigationRowActions(entity: .client(id: client.id, name: client.fullName))
                .opacity(isHovered ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            if !client.status.isEmpty {
                StatusBadge(status: client.status)
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
            EntityNavigationContextMenu(entity: .client(id: client.id, name: client.fullName))
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
                    .foregroundColor(.white)
                
                if let relation = payee.relationToClient, !relation.isEmpty {
                    Text("Relation: \(relation)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Navigation actions (show on hover)
            NavigationRowActions(entity: .payee(id: payee.id, name: payee.fullName))
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
            EntityNavigationContextMenu(entity: .payee(id: payee.id, name: payee.fullName))
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
                Text(planManager.businessName ?? "Unknown Plan Manager")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("ABN: \(planManager.abn)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
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