//
//  BulkOperations.swift
//  Feature.InvoiceTemplateEditor
//
//  Bulk operations for split management
//

import SwiftUI

struct BulkOperationsView: View {
    let onSplitAll: (SectionSplit.SplitDirection, Int) -> Void
    let onMergeAll: () -> Void
    let onResetLayout: () -> Void
    let onCancel: () -> Void
    
    @State private var selectedDirection: SectionSplit.SplitDirection = .horizontal
    @State private var splitCount: Int = 2
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Bulk Operations")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Split All Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Split All Sections")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        Picker("Direction", selection: $selectedDirection) {
                            ForEach(SectionSplit.SplitDirection.allCases, id: \.self) { direction in
                                Label(direction.displayName, systemImage: direction.icon)
                                    .tag(direction)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Stepper(value: $splitCount, in: 2...6) {
                            Text("\(splitCount) sections")
                                .font(.caption)
                        }
                    }
                    
                    Button("Split All Sections") {
                        onSplitAll(selectedDirection, splitCount)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(splitCount < 2)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                // Merge All Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Merge All Sections")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Remove all splits and merge into single section")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Merge All Sections") {
                        onMergeAll()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                // Reset Layout Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reset Layout")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Reset to default 5-section layout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Reset Layout") {
                        onResetLayout()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action buttons
            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

struct BulkOperationsButton: View {
    let onShowBulkOperations: () -> Void
    
    var body: some View {
        Button(action: onShowBulkOperations) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3")
                Text("Bulk Operations")
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
