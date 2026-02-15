import SwiftUI
import AppKit

struct GridInputResponder: NSViewRepresentable {
    var onKeyPress: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> InputView {
        let view = InputView()
        view.onKeyPress = onKeyPress
        return view
    }
    
    func updateNSView(_ nsView: InputView, context: Context) {
        nsView.onKeyPress = onKeyPress
    }
    
    class InputView: NSView {
        var onKeyPress: ((NSEvent) -> Bool)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            if let onKeyPress = onKeyPress, onKeyPress(event) {
                return
            }
            super.keyDown(with: event)
        }
    }
}
