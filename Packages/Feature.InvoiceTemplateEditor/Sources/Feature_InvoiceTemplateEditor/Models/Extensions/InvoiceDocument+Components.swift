import Foundation
import CoreGraphics

// MARK: - Component Management Helpers

extension InvoiceDocument {
    func updateComponent(id: UUID, update: (inout InvoiceComponent) -> Void) {
        // Update in legacy components array
        for i in 0..<components.count {
            if components[i].id == id {
                update(&components[i])
                objectWillChange.send()
                return
            }
        }
        
        // Update in section splits
        for sectionIndex in sectionSplits.keys {
            if var split = sectionSplits[sectionIndex] {
                if split.updateComponent(id: id, update: update) {
                    // Update synchronously - we're called from SwiftUI views which are on main actor
                    // This ensures immediate UI updates and proper binding propagation
                    sectionSplits[sectionIndex] = split
                    objectWillChange.send()
                    return
                }
            }
        }
    }
    
    func copyComponent(_ id: UUID) {
        guard let originalComponent = component(id) else { return }
        saveStateForUndo(actionName: "Duplicate Component")
        
        var copiedComponent = originalComponent
        copiedComponent.id = UUID()
        copiedComponent.position = CGPoint(
            x: originalComponent.position.x + 20,
            y: originalComponent.position.y + 20
        )
        
        // Check if original is in legacy components array
        if components.contains(where: { $0.id == id }) {
            components.append(copiedComponent)
            selectComponent(copiedComponent.id)
            return
        }
        
        // Try to add to the same section split location
        for sectionIndex in sectionSplits.keys {
            if var split = sectionSplits[sectionIndex] {
                if let location = split.findComponentLocation(id: id),
                   let childIndex = location.childIndex {
                    split.addComponent(copiedComponent, toChild: childIndex)
                    sectionSplits[sectionIndex] = split
                    selectComponent(copiedComponent.id)
                    objectWillChange.send()
                    return
                }
            }
        }
        
        // Fallback: add to legacy array if location not found
        components.append(copiedComponent)
        selectComponent(copiedComponent.id)
    }
    
    func removeComponent(with id: UUID) {
        saveStateForUndo(actionName: "Delete Component")
        
        // Try to remove from legacy components array
        if components.contains(where: { $0.id == id }) {
            components.removeAll { $0.id == id }
            if selectedComponentID == id {
                selectComponent(nil)
            }
            return
        }
        
        // Try to remove from section splits
        for sectionIndex in sectionSplits.keys {
            if var split = sectionSplits[sectionIndex] {
                if split.removeComponent(id: id) {
                    sectionSplits[sectionIndex] = split
                    if selectedComponentID == id {
                        selectComponent(nil)
                    }
                    objectWillChange.send()
                    return
                }
            }
        }
    }
    
    func removeSection(with id: UUID) {
        saveStateForUndo(actionName: "Delete Section")
        if let index = components.firstIndex(where: { $0.id == id }) {
            components.remove(at: index)
            if selectedComponentID == id {
                selectComponent(nil)
            }
        }
    }
    
    func remove(_ id: UUID) {
        removeComponent(with: id)
    }
    
    func resetComponentToDefaults(for id: UUID) {
        saveStateForUndo(actionName: "Reset Component")
        updateComponent(id: id) { component in
            component.style = ComponentStyle()
            let defaultSize = component.type.defaultSize
            component.size = defaultSize
            component.position = CGPoint(x: 595 / 2, y: 842 / 2)
        }
    }
    
    func bringToFront(_ id: UUID) {
        saveStateForUndo(actionName: "Bring to Front")
        if let index = components.firstIndex(where: { $0.id == id }) {
            let component = components.remove(at: index)
            components.append(component)
        }
    }
    
    func sendToBack(_ id: UUID) {
        saveStateForUndo(actionName: "Send to Back")
        if let index = components.firstIndex(where: { $0.id == id }) {
            let component = components.remove(at: index)
            components.insert(component, at: 0)
        }
    }
    
    func reorderComponent(_ id: UUID, to targetIndex: Int) {
        saveStateForUndo(actionName: "Reorder Component")
        guard let currentIndex = components.firstIndex(where: { $0.id == id }),
              targetIndex >= 0 && targetIndex < components.count,
              currentIndex != targetIndex else {
            return
        }
        let component = components.remove(at: currentIndex)
        components.insert(component, at: targetIndex)
    }
    
    func toggleVisibility(for id: UUID) {
        saveStateForUndo(actionName: "Toggle Visibility")
        var isVisibleAfterToggle = true
        updateComponent(id: id) { component in
            component.isVisible.toggle()
            isVisibleAfterToggle = component.isVisible
        }
        if !isVisibleAfterToggle && selectedComponentID == id {
            selectComponent(nil)
        }
    }
    
    func toggleLock(for id: UUID) {
        saveStateForUndo(actionName: "Toggle Lock")
        updateComponent(id: id) { component in
            component.isLocked.toggle()
        }
    }
    
    func moveLayerUp(_ id: UUID) {
        guard canMoveLayer(id: id, direction: 1) else { return }
        saveStateForUndo(actionName: "Move Layer Up")
        _ = moveLayer(id: id, direction: 1, in: &components)
    }
    
    func moveLayerDown(_ id: UUID) {
        guard canMoveLayer(id: id, direction: -1) else { return }
        saveStateForUndo(actionName: "Move Layer Down")
        _ = moveLayer(id: id, direction: -1, in: &components)
    }
    
    func canMoveLayerUp(_ id: UUID) -> Bool {
        canMoveLayer(id: id, direction: 1)
    }
    
    func canMoveLayerDown(_ id: UUID) -> Bool {
        canMoveLayer(id: id, direction: -1)
    }
    
    private func canMoveLayer(id: UUID, direction: Int) -> Bool {
        return canMoveLayer(id: id, direction: direction, in: components)
    }
    
    private func canMoveLayer(id: UUID, direction: Int, in array: [InvoiceComponent]) -> Bool {
        if let index = array.firstIndex(where: { $0.id == id }) {
            let destination = index + direction
            return destination >= 0 && destination < array.count
        }
        return false
    }
    
    @discardableResult
    private func moveLayer(id: UUID, direction: Int, in array: inout [InvoiceComponent]) -> Bool {
        if let index = array.firstIndex(where: { $0.id == id }) {
            let destination = index + direction
            guard destination >= 0 && destination < array.count else { return true }
            array.swapAt(index, destination)
            return true
        }
        return false
    }
    
    // MARK: - Section Split Alignment Management
    
    /// Update alignment for a leaf node in a section split
    func updateSplitAlignment(forSection sectionIndex: Int, childIndex: Int, alignment: SectionSplit.LeafAlignment) {
        guard var split = sectionSplits[sectionIndex] else { return }
        split.setAlignment(alignment, forChild: childIndex)
        sectionSplits[sectionIndex] = split
    }
    
    /// Get alignment for a leaf node in a section split
    func getSplitAlignment(forSection sectionIndex: Int, childIndex: Int) -> SectionSplit.LeafAlignment {
        guard let split = sectionSplits[sectionIndex] else { return .default }
        return split.getAlignment(forChild: childIndex)
    }
}
