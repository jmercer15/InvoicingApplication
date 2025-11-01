import Foundation
import CoreGraphics

// MARK: - Undo/Redo Functionality

extension InvoiceDocument {
    var canUndo: Bool {
        return !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        return !redoStack.isEmpty
    }
    
    func undo() {
        guard canUndo else { return }
        isUndoRedoOperation = true
        redoStack.append(DocumentState(components: components))
        let previousState = undoStack.removeLast()
        components = previousState.components
        isUndoRedoOperation = false
    }
    
    func redo() {
        guard canRedo else { return }
        isUndoRedoOperation = true
        undoStack.append(DocumentState(components: components))
        let nextState = redoStack.removeLast()
        components = nextState.components
        isUndoRedoOperation = false
    }
    
    func saveStateForUndo() {
        guard !isUndoRedoOperation else { return }
        undoStack.append(DocumentState(components: components))
        redoStack.removeAll()
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
    
    func clearUndoRedoStacks() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

