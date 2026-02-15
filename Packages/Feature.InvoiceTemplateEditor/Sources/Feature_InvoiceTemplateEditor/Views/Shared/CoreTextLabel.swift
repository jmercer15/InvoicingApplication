import SwiftUI
import CoreText

struct CoreTextLabel: NSViewRepresentable {
    let attributedString: NSAttributedString
    var numberOfLines: Int? = nil
    
    func makeNSView(context: Context) -> CoreTextLabelView {
        let view = CoreTextLabelView()
        view.attributedString = attributedString
        view.numberOfLines = numberOfLines
        return view
    }
    
    func updateNSView(_ nsView: CoreTextLabelView, context: Context) {
        if nsView.attributedString != attributedString {
            nsView.attributedString = attributedString
        }
        if nsView.numberOfLines != numberOfLines {
            nsView.numberOfLines = numberOfLines
        }
    }
}

class CoreTextLabelView: NSView {
    var attributedString: NSAttributedString? {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    
    var numberOfLines: Int? {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    
    override var isFlipped: Bool { true }
    
    override var intrinsicContentSize: NSSize {
        guard let attributedString = attributedString else { return .zero }
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
        
        let targetWidth = bounds.width > 0 ? bounds.width : CGFloat.greatestFiniteMagnitude
        let targetSize = CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
        
        // Measure full size
        let fullSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil, targetSize, nil)
        
        // If no line limit, return full size
        guard let maxLines = numberOfLines, maxLines > 0 else {
            return NSSize(width: ceil(fullSize.width), height: ceil(fullSize.height))
        }
        
        // If line limit, we need to estimate height.
        // We can't easily ask CTFramesetter for "height of N lines".
        // But we can create a frame and count lines? That's expensive for intrinsicContentSize.
        // Approximation: Get line height from font?
        // Better: Create a frame with the target width and infinite height, get lines, sum height of first N lines.
        
        let path = CGPath(rect: CGRect(origin: .zero, size: targetSize), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        
        if lines.isEmpty { return .zero }
        
        let linesToMeasure = min(lines.count, maxLines)
        
        // Get origins to calculate height
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: lines.count), &origins)
        
        // Height = (First Line Origin Y) - (Last Measured Line Origin Y) + (Last Line Descent + Leading)
        // Note: Origins are usually bottom-left in CoreText.
        // But we are in isFlipped view? No, CTFrameCreateFrame uses standard coords usually unless we transform.
        // Let's just use the suggested size if lines <= maxLines.
        
        if lines.count <= maxLines {
            return NSSize(width: ceil(fullSize.width), height: ceil(fullSize.height))
        }
        
        // If we have more lines, we need to calculate height of first N lines.
        // In a flipped context (which we handle in draw), origins might be different.
        // But here we just created a frame.
        // Let's use a simpler approach:
        // Measure the height of the first N lines by summing ascent + descent + leading.
        
        var height: CGFloat = 0
        for i in 0..<linesToMeasure {
            let line = lines[i]
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            height += ascent + descent + leading
            // Note: This is an approximation. Line spacing in paragraph style also affects this.
        }
        
        return NSSize(width: ceil(fullSize.width), height: ceil(height))
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let attributedString = attributedString,
              let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Flip context for CoreText
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
        let path = CGPath(rect: bounds, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        
        CTFrameDraw(frame, context)
        
        // Manual Strikethrough Drawing Removed
        // CoreText does not natively support strikethrough via CTFrameDraw on macOS without NSAttributedString keys.
        // Removed to enforce strict CoreText compliance.
        
        context.restoreGState()
    }
    
    override func layout() {
        super.layout()
        invalidateIntrinsicContentSize()
    }
}

// MARK: - Preview

#Preview("CoreTextLabel") {
    VStack(alignment: .leading, spacing: 20) {
        // Simple text
        CoreTextLabel(
            attributedString: NSAttributedString(
                string: "Hello, World!",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        )
        .frame(width: 200, height: 30)
        
        // Multi-line text
        CoreTextLabel(
            attributedString: NSAttributedString(
                string: "This is a longer text that should wrap to multiple lines when displayed in a narrow container.",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            ),
            numberOfLines: 2
        )
        .frame(width: 200, height: 40)
        
        // Styled text
        CoreTextLabel(
            attributedString: {
                let string = NSMutableAttributedString()
                string.append(NSAttributedString(string: "Bold ", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]))
                string.append(NSAttributedString(string: "and ", attributes: [.font: NSFont.systemFont(ofSize: 14)]))
                // Use NSFontManager to get italic font
                let regularFont = NSFont.systemFont(ofSize: 14)
                let italicFont = NSFontManager.shared.convert(regularFont, toHaveTrait: .italicFontMask)
                string.append(NSAttributedString(string: "Italic", attributes: [.font: italicFont]))
                return string
            }()
        )
        .frame(width: 200, height: 24)
    }
    .padding()
}

