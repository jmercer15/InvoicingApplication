import SwiftUI
import AppKit

/// Editable rich text view (Edit Mode)
/// NSTextView wrapper for editing cell content
struct RichTextEditor: View {
    @Binding var content: RichTextContent
    var style: CellStyle
    var onHeightChange: ((CGFloat) -> Void)?
    var onCommit: (() -> Void)?
    var onTab: ((Bool) -> Void)?  // Bool = isShiftPressed
    var onEnter: ((Bool) -> Void)?  // Bool = isShiftPressed
    @EnvironmentObject var textEditingContext: TextEditingContext
    
    var body: some View {
        GeometryReader { geo in
            RichTextEditorNSView(
                content: $content,
                style: style,
                containerHeight: geo.size.height,
                verticalAlignment: style.verticalAlignment,
                onHeightChange: onHeightChange,
                onCommit: onCommit,
                onTab: onTab,
                onEnter: onEnter,
                textEditingContext: textEditingContext
            )
        }
    }
}

private struct RichTextEditorNSView: NSViewRepresentable {
    @Binding var content: RichTextContent
    var style: CellStyle
    var containerHeight: CGFloat
    var verticalAlignment: CellVerticalAlignment
    var onHeightChange: ((CGFloat) -> Void)?
    var onCommit: (() -> Void)?
    var onTab: ((Bool) -> Void)?
    var onEnter: ((Bool) -> Void)?
    var textEditingContext: TextEditingContext
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let textView = NSTextView()
        
        // Edit-only configuration
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        
        // Enable rich text editing
        textView.isRichText = true
        textView.allowsUndo = true
        
        // Performance optimization: Only enable font panel when needed
        // This avoids slow Touch Bar API calls
        textView.usesFontPanel = false
        
        textView.usesRuler = false
        textView.usesFindBar = true
        textView.isAutomaticTextCompletionEnabled = true
        
        // Performance optimization: Enable noncontiguous layout for large documents
        textView.layoutManager?.allowsNonContiguousLayout = true
        
        // Enable image and attachment support
        textView.importsGraphics = true
        textView.allowsImageEditing = true
        
        // Register additional drag types
        textView.registerForDraggedTypes([
            .tiff, .png, .fileURL, .rtf, .html, .string
        ])
        
        // Enable specific text features
        textView.smartInsertDeleteEnabled = true
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Remove padding
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        
        // Store coordinator for key event handling
        context.coordinator.onTab = onTab
        context.coordinator.onEnter = onEnter
        
        containerView.addSubview(textView)
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let textView = nsView.subviews.first as? NSTextView else { return }
        
        // Register this text view as the active one (defer to avoid publishing during view update)
        DispatchQueue.main.async { [weak textEditingContext] in
            textEditingContext?.currentTextView = textView
        }
        
        // Update coordinator reference
        context.coordinator.parent = self
        
        // Update content if changed
        if textView.string != content.storage.string {
            textView.textStorage?.setAttributedString(content.storage)
        }
        
        // Set default typing attributes based on style (only affects NEW text)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = style.textAlignment.nsTextAlignment
        
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: style.fontSize, weight: style.isBold ? .bold : .regular),
            .foregroundColor: style.textColor.nsColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // Auto-focus when appearing
        DispatchQueue.main.async {
            if textView.window?.firstResponder != textView {
                textView.window?.makeFirstResponder(textView)
            }
        }
        
        // Calculate content height and position
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
                height: max(contentHeight, 20) // Minimum height for cursor
            )
            
            onHeightChange?(contentHeight)
        }
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        // Unregister when view disappears (defer to avoid publishing during view update)
        let context = coordinator.parent.textEditingContext
        DispatchQueue.main.async {
            context.currentTextView = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditorNSView
        var onTab: ((Bool) -> Void)?
        var onEnter: ((Bool) -> Void)?
        
        init(_ parent: RichTextEditorNSView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Sync changes back to SwiftUI
            if let storage = textView.textStorage {
                parent.content.storage = NSAttributedString(attributedString: storage)
            }
            
            // Notify height change
            if let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer {
                layoutManager.ensureLayout(for: textContainer)
                let usedRect = layoutManager.usedRect(for: textContainer)
                parent.onHeightChange?(usedRect.height)
            }
        }
        
        // Handle special key commands
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let event = NSApp.currentEvent
            let isShift = event?.modifierFlags.contains(.shift) ?? false
            
            switch commandSelector {
            case #selector(NSTextView.insertTab(_:)):
                // Tab key pressed
                if !isShift {
                    onTab?(false)
                    return true
                }
                return false
                
            case #selector(NSTextView.insertBacktab(_:)):
                // Shift+Tab pressed
                onTab?(true)
                return true
                
            case #selector(NSTextView.insertNewline(_:)):
                // Enter key pressed
                if isShift {
                    // Shift+Enter: insert actual newline (default behavior)
                    return false
                } else {
                    // Enter: commit and navigate
                    onEnter?(false)
                    return true
                }
                
            case #selector(NSTextView.cancelOperation(_:)):
                // Escape key
                parent.onCommit?()
                return true
                
            default:
                return false
            }
        }
    }
}

extension TextAlignment {
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        }
    }
}

extension ColorWrapper {
    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: opacity)
    }
}
