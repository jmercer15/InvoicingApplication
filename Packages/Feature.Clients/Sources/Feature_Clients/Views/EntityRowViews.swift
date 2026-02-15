//
//  EntityRowViews.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//  Refactored to support Domain Models and Glass UI on 9/4/2025.
//

import SwiftUI
import SwiftData
import Data
import Core
import SharedUI

// MARK: - Client Row
struct ClientRow: View {
    let client: Client
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isMultiSelectMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                        .padding(4)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
            
            HStack {
                Text(client.fullName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Spacer()
                
                StatusBadge(status: client.status)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(.rect(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.04 : 0))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .onHover { isHovering = $0 }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                onTap()
            }
        }
        .pointerStyle(.link)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

// MARK: - Payee Row
struct PayeeRow: View {
    let payee: Payee
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isMultiSelectMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                        .padding(4)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
            
            HStack {
                Text(payee.fullName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Spacer()
                
                StatusBadge(status: payee.status ?? "Active")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(.rect(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.04 : 0))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .onHover { isHovering = $0 }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                onTap()
            }
        }
        .pointerStyle(.link)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

// MARK: - Plan Manager Row
struct PlanManagerRow: View {
    let planManager: PlanManager
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isMultiSelectMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                        .padding(4)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
            
            HStack {
                Text(planManager.name ?? "Unnamed")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Spacer()
                
                // Active badge for Plan Managers (assuming active if present)
                StatusBadge(status: "Active")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(.rect(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.04 : 0))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .onHover { isHovering = $0 }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                onTap()
            }
        }
        .pointerStyle(.link)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}

// MARK: - Custom Section Header
struct CustomSectionHeader: View {
    let title: String
    let count: Int
    let icon: String
    let accentColor: Color
    let isCollapsed: Bool
    let onToggle: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Icon with neutral color
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Text("\(count) \(count == 1 ? "item" : "items")")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                
                Spacer()
                
                // Collapse/expand indicator
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .animation(.easeInOut(duration: 0.3), value: isCollapsed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect(cornerRadius: 12))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .glassEffect(.regular, in: .rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accentColor.opacity(isHovering ? 0.06 : 0))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accentColor.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .pointerStyle(.link)
    }
}
