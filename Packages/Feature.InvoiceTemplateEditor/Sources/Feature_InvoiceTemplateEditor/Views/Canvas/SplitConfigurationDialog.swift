//
//  SplitConfigurationDialog.swift
//  Feature.InvoiceTemplateEditor
//
//  Dialog for configuring split parameters (rows/columns/sections)
//

import SwiftUI
import SharedUI

struct SplitConfigurationDialog: View {
    @Binding var direction: SectionSplit.SplitDirection
    @Binding var splitCount: Int
    let onConfirm: (SectionSplit.SplitDirection, Int, Int?, Int?) -> Void
    let onCancel: () -> Void
    
    @State private var rows: Int = 2
    @State private var columns: Int = 2
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Split Section")
                .font(.headline)
                .transition(.opacity)
            
            VStack(spacing: 16) {
                // Direction picker
                Picker("", selection: $direction) {
                    ForEach(SectionSplit.SplitDirection.allCases, id: \.self) { dir in
                        Label(dir.displayName, systemImage: dir.icon)
                            .tag(dir)
                    }
                }
                .pickerStyle(.segmented)
                
                // Configuration controls
                if direction == .grid {
                    HStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Rows")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Stepper(value: $rows, in: 1...10) {
                                Text("\(rows)")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .animation(.easeInOut(duration: 0.2), value: rows)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .containerRelative)
                            .cornerRadius(8)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Columns")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Stepper(value: $columns, in: 1...10) {
                                Text("\(columns)")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .animation(.easeInOut(duration: 0.2), value: columns)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .containerRelative)
                            .cornerRadius(8)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Sections")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Stepper(value: $splitCount, in: 2...10) {
                            Text("\(splitCount)")
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .containerRelative)
                        .cornerRadius(8)
                    }
                }
            }
            
            // Preview section
            VStack(spacing: 8) {
                Text("Preview")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                SplitPreview(direction: direction, splitCount: direction == .grid ? rows * columns : splitCount, rows: direction == .grid ? rows : nil, columns: direction == .grid ? columns : nil)
                    .frame(height: 80)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Action buttons
            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Split") {
                    if direction == .grid {
                        onConfirm(direction, rows * columns, rows, columns)
                    } else {
                        onConfirm(direction, splitCount, nil, nil)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 320)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: direction)
        .onAppear {
            if direction == .grid {
                rows = 2
                columns = 2
            } else {
                splitCount = 2
            }
        }
    }
}

// MARK: - Split Preview Component
struct SplitPreview: View {
    let direction: SectionSplit.SplitDirection
    let splitCount: Int
    let rows: Int?
    let columns: Int?
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .cornerRadius(4)
            
            // Preview content based on direction
            switch direction {
            case .horizontal:
                HStack(spacing: 1) {
                    ForEach(0..<splitCount, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(4)
                
            case .vertical:
                VStack(spacing: 1) {
                    ForEach(0..<splitCount, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(maxHeight: .infinity)
                    }
                }
                .padding(4)
                
            case .grid:
                if let rows = rows, let columns = columns {
                    VStack(spacing: 1) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: 1) {
                                ForEach(0..<columns, id: \.self) { col in
                                    Rectangle()
                                        .fill(Color.accentColor.opacity(0.3))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }
                    }
                    .padding(4)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: direction)
        .animation(.easeInOut(duration: 0.2), value: splitCount)
    }
}

