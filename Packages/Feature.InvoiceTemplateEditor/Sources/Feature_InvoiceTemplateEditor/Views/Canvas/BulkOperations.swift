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
    @State private var showMergeConfirm = false
    @State private var showResetConfirm = false
    @State private var isProcessing = false
    @State private var progressText: String? = nil
    
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
                                Label {
                                    Text(direction.displayName)
                                } icon: {
                                    Image(direction.icon, bundle: .module)
                                        .renderingMode(.template)
                                }
                                    .tag(direction)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Stepper(value: $splitCount, in: 2...6) {
                            Text("\(splitCount) sections")
                                .font(.caption)
                        }
                    }
                    
                    Button("Split All Sections") {
                        isProcessing = true
                        progressText = "Splitting..."
                        DispatchQueue.main.async {
                            onSplitAll(selectedDirection, splitCount)
                            isProcessing = false
                            progressText = nil
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(splitCount < 2 || isProcessing)
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
                        showMergeConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
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
                        showResetConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
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
        .alert("Merge All Sections?", isPresented: $showMergeConfirm) {
            Button("Merge", role: .destructive) {
                isProcessing = true
                progressText = "Merging..."
                DispatchQueue.main.async {
                    onMergeAll()
                    isProcessing = false
                    progressText = nil
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all splits and merge into a single section.")
        }
        .alert("Reset Layout?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                isProcessing = true
                progressText = "Resetting..."
                DispatchQueue.main.async {
                    onResetLayout()
                    isProcessing = false
                    progressText = nil
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset to the default layout. This action cannot be undone.")
        }
        .overlay {
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                        if let progressText {
                            Text(progressText)
                                .font(.footnote)
                                .foregroundColor(Color.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
                            .shadow(radius: 6, y: 3)
                    )
                }
            }
        }
    }
}

struct BulkOperationsButton: View {
    let onShowBulkOperations: () -> Void
    
    var body: some View {
        Button(action: onShowBulkOperations) {
            HStack(spacing: 6) {
                Image("fluent-ic_fluent_table_20_regular", bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                Text("Bulk Operations")
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
