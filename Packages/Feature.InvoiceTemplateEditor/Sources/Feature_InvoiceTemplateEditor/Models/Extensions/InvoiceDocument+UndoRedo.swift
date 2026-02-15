import Foundation
import CoreGraphics

// MARK: - Undo/Redo Functionality

extension InvoiceDocument {
    var canUndo: Bool {
        return undoManager?.canUndo ?? false
    }
    
    var canRedo: Bool {
        return undoManager?.canRedo ?? false
    }
    
    func undo() {
        undoManager?.undo()
    }
    
    func redo() {
        undoManager?.redo()
    }
    
    func saveStateForUndo(actionName: String? = nil) {
        // If we don't have an undo manager, do nothing
        guard let undoManager = undoManager else { return }
        
        // Capture current state
        let oldState = DocumentState(
            components: components,
            sectionSplits: sectionSplits,
            margins: margins,
            sectionHeightRatios: sectionHeightRatios,
            selectedComponentID: selectedComponentID,
            selectedSplitSelection: selectedSplitSelection,
            selectedTableElement: selectedTableElement
        )
        
        undoManager.registerUndo(withTarget: self) { document in
            document.restoreState(oldState)
        }
        
        if let actionName = actionName {
            undoManager.setActionName(actionName)
        }
    }
    
    private func restoreState(_ state: DocumentState) {
        // Register the reverse operation (Redo)
        // Since we are executing inside an undo closure, this will register to the Redo stack
        saveStateForUndo()
        
        // Restore state properties
        self.components = state.components
        self.sectionSplits = state.sectionSplits
        self.margins = state.margins
        self.sectionHeightRatios = state.sectionHeightRatios
        
        // Restore selection
        self.selectedComponentID = state.selectedComponentID
        self.selectedSplitSelection = state.selectedSplitSelection
        self.selectedTableElement = state.selectedTableElement
    }
    
    func clearUndoRedoStacks() {
        undoManager?.removeAllActions()
    }
}

