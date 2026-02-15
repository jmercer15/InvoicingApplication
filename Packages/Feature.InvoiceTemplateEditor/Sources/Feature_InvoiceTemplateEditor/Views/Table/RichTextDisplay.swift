import SwiftUI
import AppKit

/// Display-only rich text view (Navigation Mode)
/// Read-only NSTextView wrapper for displaying cell content
struct RichTextDisplay: View {
    @Binding var content: RichTextContent
    var style: CellStyle
    var onHeightChange: ((CGFloat) -> Void)?
    
    var body: some View {
        GeometryReader { geo in
            RichTextDisplayNSView(
                content: $content,
                style: style,
                containerHeight: geo.size.height,
                verticalAlignment: style.verticalAlignment,
                onHeightChange: onHeightChange
            )
        }
    }
}

private struct RichTextDisplayNSView: NSViewRepresentable {
    @Binding var content: RichTextContent
    var style: CellStyle
    var containerHeight: CGFloat
    var verticalAlignment: CellVerticalAlignment
    var onHeightChange: ((CGFloat) -> Void)?
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let textView = NSTextView()
        
        // Display-only configuration
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        
        // Remove padding
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        
        containerView.addSubview(textView)
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let textView = nsView.subviews.first as? NSTextView else { return }
        
        // Update content if changed
        if textView.string != content.storage.string {
            textView.textStorage?.setAttributedString(content.storage)
        }
        
        // Calculate content height
        if let layoutManager = textView.layoutManager, let container = textView.textContainer {
            layoutManager.ensureLayout(for: container)
            let contentHeight = layoutManager.usedRect(for: container).height
            
            // Position textView based on vertical alignment
            let yPosition: CGFloat
            switch verticalAlignment {
            case .top:
                yPosition = 0
            case .center:
                yPosition = max(0, (containerHeight - contentHeight) / 2)
            case .bottom:
                yPosition = max(0, containerHeight - contentHeight)
            }
            
            textView.frame = NSRect(
                x: 0,
                y: yPosition,
                width: nsView.bounds.width,
                height: contentHeight
            )
            
            onHeightChange?(contentHeight)
        }
    }
}
