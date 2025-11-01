import Foundation
import CoreGraphics

// MARK: - Component Management Helpers

extension InvoiceDocument {
    func updateComponent(id: UUID, update: (inout InvoiceComponent) -> Void) {
        // Update in legacy components array
        for i in 0..<components.count {
            if components[i].id == id {
                update(&components[i])
                return
            }
        }
        
        // Update in section splits
        for sectionIndex in sectionSplits.keys {
            if var split = sectionSplits[sectionIndex] {
                if split.updateComponent(id: id, update: update) {
                    sectionSplits[sectionIndex] = split
                    return
                }
            }
        }
    }
    
    func copyComponent(_ id: UUID) {
        guard let originalComponent = component(id) else { return }
        var copiedComponent = originalComponent
        copiedComponent.id = UUID()
        copiedComponent.position = CGPoint(
            x: originalComponent.position.x + 20,
            y: originalComponent.position.y + 20
        )
        components.append(copiedComponent)
        selectedComponentID = copiedComponent.id
    }
    
    func removeComponent(with id: UUID) {
        saveStateForUndo()
        components.removeAll { $0.id == id }
        if selectedComponentID == id {
            selectedComponentID = nil
        }
    }
    
    func removeSection(with id: UUID) {
        if let index = components.firstIndex(where: { $0.id == id }) {
            components.remove(at: index)
            if selectedComponentID == id {
                selectedComponentID = nil
            }
        }
    }
    
    func remove(_ id: UUID) {
        removeComponent(with: id)
    }
    
    func resetComponentToDefaults(for id: UUID) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style = ComponentStyle()
            let defaultSize = component.type.defaultSize
            component.size = defaultSize
            component.position = CGPoint(x: 595 / 2, y: 842 / 2)
        }
    }
    
    func bringToFront(_ id: UUID) {
        saveStateForUndo()
        if let index = components.firstIndex(where: { $0.id == id }) {
            let component = components.remove(at: index)
            components.append(component)
        }
    }
    
    func sendToBack(_ id: UUID) {
        saveStateForUndo()
        if let index = components.firstIndex(where: { $0.id == id }) {
            let component = components.remove(at: index)
            components.insert(component, at: 0)
        }
    }
    
    func reorderComponent(_ id: UUID, to targetIndex: Int) {
        saveStateForUndo()
        guard let currentIndex = components.firstIndex(where: { $0.id == id }),
              targetIndex >= 0 && targetIndex < components.count,
              currentIndex != targetIndex else {
            return
        }
        let component = components.remove(at: currentIndex)
        components.insert(component, at: targetIndex)
    }
    
    func toggleVisibility(for id: UUID) {
        saveStateForUndo()
        var isVisibleAfterToggle = true
        updateComponent(id: id) { component in
            component.isVisible.toggle()
            isVisibleAfterToggle = component.isVisible
        }
        if !isVisibleAfterToggle && selectedComponentID == id {
            selectedComponentID = nil
        }
    }
    
    func toggleLock(for id: UUID) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.isLocked.toggle()
        }
    }
    
    func moveLayerUp(_ id: UUID) {
        guard canMoveLayer(id: id, direction: 1) else { return }
        saveStateForUndo()
        _ = moveLayer(id: id, direction: 1, in: &components)
    }
    
    func moveLayerDown(_ id: UUID) {
        guard canMoveLayer(id: id, direction: -1) else { return }
        saveStateForUndo()
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
}

