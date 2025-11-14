//
//  ContentRectangleView.swift
//  Feature.InvoiceTemplateEditor
//
//  Leaf section view that displays components and handles drops
//

import SwiftUI
import UniformTypeIdentifiers
import Core

struct ContentRectangleView: View {
    let components: [InvoiceComponent]
    let containerSize: CGSize
    let sectionLabel: String?
    let contentAlignment: SectionSplit.LeafAlignment
    let sectionIndex: Int?
    let childIndex: Int?
    let onAddComponent: (InvoiceComponent) -> Void
    let onSplit: (SectionSplit.SplitDirection, Int, Int?, Int?) -> Void
    let onSetLabel: ((String?) -> Void)?
    let onSetAlignment: ((SectionSplit.LeafAlignment) -> Void)?
    let onComponentSelect: (InvoiceComponent) -> Void
    
    @EnvironmentObject private var document: InvoiceDocument
    
    @State private var isHovered = false
    @State private var showingSplitDialog = false
    @State private var selectedSplitDirection: SectionSplit.SplitDirection = .horizontal
    @State private var splitCount: Int = 2
    @State private var isProcessingSplit = false
    @State private var showSuccessIndicator = false
    @State private var isEditingLabel = false
    @State private var editingLabelText = ""
    
    var body: some View {
        ZStack {
            // Background rectangle with drop destination, constrained to container size
            Rectangle()
                .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.canvasBackground)
                .frame(width: containerSize.width, height: containerSize.height)
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .onDrop(of: [UTType.invoiceComponent], isTargeted: .constant(false)) { providers, location in
                    handleDrop(providers: providers, at: location)
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovered = hovering
                    }
                }
                .contextMenu {
                    // Alignment submenu
                    if onSetAlignment != nil {
                        Menu("Content Alignment") {
                            // Horizontal alignment
                            Menu("Horizontal") {
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.horizontal = .leading
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Leading", systemImage: contentAlignment.horizontal == .leading ? "checkmark" : "")
                                }
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.horizontal = .center
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Center", systemImage: contentAlignment.horizontal == .center ? "checkmark" : "")
                                }
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.horizontal = .trailing
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Trailing", systemImage: contentAlignment.horizontal == .trailing ? "checkmark" : "")
                                }
                            }
                            
                            // Vertical alignment
                            Menu("Vertical") {
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.vertical = .top
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Top", systemImage: contentAlignment.vertical == .top ? "checkmark" : "")
                                }
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.vertical = .center
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Center", systemImage: contentAlignment.vertical == .center ? "checkmark" : "")
                                }
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.vertical = .bottom
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Bottom", systemImage: contentAlignment.vertical == .bottom ? "checkmark" : "")
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Split options
                    ForEach(SectionSplit.commonSplits, id: \.id) { splitOption in
                        Button(action: {
                            selectedSplitDirection = splitOption.direction
                            splitCount = splitOption.splitCount
                            showingSplitDialog = true
                        }) {
                            Label(splitOption.direction.displayName, systemImage: splitOption.direction.icon)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            // Section label header
            if let label = sectionLabel, !label.isEmpty {
                VStack {
                    HStack {
                        if isEditingLabel {
                            TextField("Section Label", text: $editingLabelText)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .onSubmit {
                                    onSetLabel?(editingLabelText.isEmpty ? nil : editingLabelText)
                                    isEditingLabel = false
                                }
                                .onAppear {
                                    editingLabelText = label
                                }
                        } else {
                            Text(label)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                                .onTapGesture {
                                    isEditingLabel = true
                                }
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
            
            // Render components within this section using configured alignment
            // Calculate available size accounting for padding (8 on each side = 16 total)
            let availableWidth = max(0, containerSize.width - 16)
            let availableHeight = max(0, containerSize.height - 16)
            
            // Use conditional layout: single component without VStack for perfect alignment,
            // multiple components with VStack for proper spacing
            Group {
                if components.count == 1, let component = components.first {
                    // Single component: render directly for perfect alignment
                    SelectableComponentView(
                        component: component,
                        onSelect: { onComponentSelect(component) }
                    )
                    .frame(
                        width: min(component.size.width, availableWidth),
                        height: min(component.size.height, availableHeight)
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8)),
                        removal: .scale(scale: 0.8).combined(with: .opacity).animation(.easeInOut(duration: 0.2))
                    ))
                } else {
                    // Multiple components: use VStack with spacing
                    VStack(spacing: 8) {
                        ForEach(components) { component in
                            SelectableComponentView(
                                component: component,
                                onSelect: { onComponentSelect(component) }
                            )
                            .frame(
                                width: min(component.size.width, availableWidth),
                                height: min(component.size.height, availableHeight)
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8)),
                                removal: .scale(scale: 0.8).combined(with: .opacity).animation(.easeInOut(duration: 0.2))
                            ))
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: components.count)
            .onAppear {
                if components.count == 1 {
                    let componentType = components.first?.type.rawValue ?? "unknown"
                    print("   🎨 Rendering single component: \(components.first?.id ?? UUID()) of type \(componentType)")
                } else {
                    print("   🎨 Rendering \(components.count) components")
                }
            }
            .padding(8)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: Alignment(
                    horizontal: contentAlignment.horizontal.swiftUIAlignment,
                    vertical: contentAlignment.vertical.swiftUIAlignment
                )
            )
            .clipped() // Ensure content doesn't overflow the container
            .onAppear {
                print("   📺 ContentRectangleView appeared with \(components.count) components")
                if !components.isEmpty {
                    print("      Component IDs: \(components.map { $0.id })")
                }
            }
            .onChange(of: components.count) { oldCount, newCount in
                print("   🔄 ContentRectangleView: Components count changed from \(oldCount) to \(newCount)")
                if newCount > oldCount {
                    print("      ✅ NEW COMPONENT DETECTED!")
                    print("      New component IDs: \(components.map { $0.id })")
                }
            }
            
            // Processing overlay
            if isProcessingSplit {
                Rectangle()
                    .fill(Color(NSColor.shadowColor).opacity(0.3))
                    .frame(width: containerSize.width, height: containerSize.height)
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(NSColor.labelColor)))
                            Text("Creating Split...")
                                .font(.caption)
                                .foregroundColor(Color(NSColor.labelColor))
                        }
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: isProcessingSplit)
            }
            
            // Success indicator
            if showSuccessIndicator {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(NSColor.systemGreen))
                            .font(.title2)
                            .background(
                                Circle()
                                    .fill(Color(NSColor.windowBackgroundColor))
                                    .frame(width: 32, height: 32)
                            )
                            .shadow(radius: 4)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showSuccessIndicator)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSuccessIndicator = false
                        }
                    }
                }
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .clipped()
        .sheet(isPresented: $showingSplitDialog) {
            SplitConfigurationDialog(
                direction: $selectedSplitDirection,
                splitCount: $splitCount,
                onConfirm: { direction, count, rows, columns in
                    // Show processing state
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isProcessingSplit = true
                    }
                    
                    // Simulate processing delay for visual feedback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSplit(direction, count, rows, columns)
                        
                        // Hide processing and show success
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isProcessingSplit = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showSuccessIndicator = true
                            }
                        }
                    }
                    showingSplitDialog = false
                },
                onCancel: {
                    showingSplitDialog = false
                }
            )
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        print("🎯 ContentRectangleView.handleDrop: Called with location: \(location)")
        print("   📦 Current components count: \(components.count)")
        
        guard let provider = providers.first else {
            print("   ❌ No provider found")
            return false
        }
        
        print("   ✅ Provider found, checking for invoiceComponent type")
        
        if provider.hasItemConformingToTypeIdentifier(UTType.invoiceComponent.identifier) {
            print("   ✅ Provider has invoiceComponent type, loading data...")
            
            provider.loadDataRepresentation(forTypeIdentifier: UTType.invoiceComponent.identifier) { data, error in
                if let error = error {
                    print("   ❌ Error loading data: \(error)")
                    return
                }
                
                DispatchQueue.main.async {
                    print("   📥 Data loaded on main thread")
                    
                    if let data = data {
                        print("   ✅ Data exists, size: \(data.count) bytes")
                        
                        do {
                            let decoder = JSONDecoder()
                            let component = try decoder.decode(InvoiceComponent.self, from: data)
                            
                            print("   ✅ Component decoded successfully:")
                            print("      - Type: \(component.type)")
                            print("      - ID: \(component.id)")
                            print("      - Size: \(component.size)")
                            
                            // First, check if component exists anywhere in document's splits (including nested)
                            // Remove from ALL locations to prevent duplicates
                            var componentExistsElsewhere = false
                            var removedFromSections: [Int] = []
                            
                            // Iterate through all sections and remove component from all locations
                            for (sectionIndex, var split) in document.sectionSplits {
                                // Keep trying to remove until it's not found anymore (handles nested duplicates)
                                var removed = true
                                var iterations = 0
                                while removed && iterations < 10 { // Safety limit
                                    removed = split.removeComponent(id: component.id)
                                    if removed {
                                        // Always update the document with the modified split
                                        document.sectionSplits[sectionIndex] = split
                                        componentExistsElsewhere = true
                                        if !removedFromSections.contains(sectionIndex) {
                                            removedFromSections.append(sectionIndex)
                                        }
                                        print("   🔄 Removed component \(component.id) from section \(sectionIndex)")
                                        // Get updated split for next iteration
                                        split = document.sectionSplits[sectionIndex] ?? split
                                    }
                                    iterations += 1
                                }
                            }
                            
                            // After removal, check if component still exists anywhere in the document
                            // We need to check the current state of the document, not the potentially stale components array
                            var componentStillExists = false
                            for (_, split) in document.sectionSplits {
                                if split.getAllComponents().contains(where: { $0.id == component.id }) {
                                    componentStillExists = true
                                    break
                                }
                            }
                            
                            print("   🔍 After removal check:")
                            print("      - Component still exists anywhere: \(componentStillExists)")
                            print("      - Current section components (may be stale): \(components.map { $0.id })")
                            
                            if componentStillExists {
                                print("   ℹ️ Component still exists somewhere (after removal), ignoring drop")
                                return
                            }
                            
                            // If component existed elsewhere (moved), add it here with same ID
                            // If component is new (from palette), add it with new ID
                            if componentExistsElsewhere {
                                print("   ➕ Moving component \(component.id) to this section (was in sections: \(removedFromSections))")
                                onAddComponent(component)
                            } else {
                                print("   ➕ Adding new component from palette...")
                                var newComponent = component
                                let oldId = newComponent.id
                                newComponent.id = UUID()
                                print("   🔄 Created new component with new ID: \(newComponent.id) (was: \(oldId))")
                                onAddComponent(newComponent)
                            }
                            
                            print("   ✅ Component operation completed successfully")
                        } catch {
                            print("   ❌ Failed to decode component: \(error)")
                            print("      Error details: \(error.localizedDescription)")
                        }
                    } else {
                        print("   ❌ Data is nil")
                    }
                }
            }
            return true
        }
        
        print("   ❌ Provider does not have invoiceComponent type")
        return false
    }
}

// MARK: - Selectable Component View

struct SelectableComponentView: View {
    let component: InvoiceComponent
    let onSelect: () -> Void
    
    @EnvironmentObject private var document: InvoiceDocument
    
    private var isSelected: Bool {
        document.selectedComponentID == component.id
    }
    
    var body: some View {
        ZStack {
            // Component content
            ModernComponentView(component: component, proposedSize: nil)
                .onTapGesture {
                    onSelect()
                }
            
            // Selection indicator
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .draggable(component)
    }
}

