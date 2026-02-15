import SwiftUI
import AppKit

/// Shared context for accessing the currently editing text view
@MainActor
class TextEditingContext: ObservableObject {
    @Published var currentTextView: NSTextView?
    
    /// Use NSFontManager to toggle text traits
    private func toggleTrait(_ trait: NSFontTraitMask) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? NSFont else { return }
            
            let fontManager = NSFontManager.shared
            let traits = fontManager.traits(of: font)
            let newFont: NSFont
            
            if traits.contains(trait) {
                newFont = fontManager.convert(font, toNotHaveTrait: trait)
            } else {
                newFont = fontManager.convert(font, toHaveTrait: trait)
            }
            
            storage.addAttribute(.font, value: newFont, range: subrange)
        }
    }
    
    /// Toggle Bold
    func toggleBold() {
        toggleTrait(.boldFontMask)
    }
    
    /// Toggle Italic
    func toggleItalic() {
        toggleTrait(.italicFontMask)
    }
    
    /// Toggle underline
    func toggleUnderline() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        // Check if any part has underline
        var hasUnderline = false
        storage.enumerateAttribute(.underlineStyle, in: range) { value, _, stop in
            if value != nil {
                hasUnderline = true
                stop.pointee = true
            }
        }
        
        if hasUnderline {
            storage.removeAttribute(.underlineStyle, range: range)
        } else {
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }
    
    /// Toggle strikethrough
    func toggleStrikethrough() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        // Check if any part of selection has strikethrough
        var hasStrikethrough = false
        storage.enumerateAttribute(.strikethroughStyle, in: range) { value, _, stop in
            if value != nil {
                hasStrikethrough = true
                stop.pointee = true
            }
        }
        
        // Toggle: if any has it, remove from all; otherwise add to all
        if hasStrikethrough {
            storage.removeAttribute(.strikethroughStyle, range: range)
        } else {
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }
    
    /// Set text alignment
    func setAlignment(_ alignment: NSTextAlignment) {
        guard let textView = currentTextView else { return }
        textView.alignment = alignment
    }
    
    /// Increase font size
    func makeFontBigger() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? NSFont else { return }
            let newSize = min(font.pointSize + 2, 144) // Max 144pt
            let newFont = NSFont(descriptor: font.fontDescriptor, size: newSize) ?? font
            storage.addAttribute(.font, value: newFont, range: subrange)
        }
    }
    
    /// Decrease font size
    func makeFontSmaller() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? NSFont else { return }
            let newSize = max(font.pointSize - 2, 8) // Min 8pt
            let newFont = NSFont(descriptor: font.fontDescriptor, size: newSize) ?? font
            storage.addAttribute(.font, value: newFont, range: subrange)
        }
    }
    
    /// Toggle superscript
    func toggleSuperscript() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.superscript, in: range) { value, subrange, _ in
            if let superscript = value as? Int, superscript > 0 {
                storage.removeAttribute(.superscript, range: subrange)
                storage.removeAttribute(.baselineOffset, range: subrange)
            } else {
                storage.addAttribute(.superscript, value: 1, range: subrange)
                storage.addAttribute(.baselineOffset, value: 5, range: subrange)
            }
        }
    }
    
    /// Toggle subscript
    func toggleSubscript() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.superscript, in: range) { value, subrange, _ in
            if let superscript = value as? Int, superscript < 0 {
                storage.removeAttribute(.superscript, range: subrange)
                storage.removeAttribute(.baselineOffset, range: subrange)
            } else {
                storage.addAttribute(.superscript, value: -1, range: subrange)
                storage.addAttribute(.baselineOffset, value: -5, range: subrange)
            }
        }
    }
    
    /// Set text color
    func setTextColor(_ color: NSColor) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.addAttribute(.foregroundColor, value: color, range: range)
    }
    
    /// Set background color
    func setBackgroundColor(_ color: NSColor) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.addAttribute(.backgroundColor, value: color, range: range)
    }
    
    /// Clear background color
    func clearBackgroundColor() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.removeAttribute(.backgroundColor, range: range)
    }
    
    /// Adjust kerning (character spacing)
    func adjustKerning(_ delta: CGFloat) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.kern, in: range) { value, subrange, _ in
            let currentKern = (value as? CGFloat) ?? 0
            let newKern = currentKern + delta
            storage.addAttribute(.kern, value: newKern, range: subrange)
        }
    }
    
    /// Reset kerning to default
    func resetKerning() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.removeAttribute(.kern, range: range)
    }
    
    /// Toggle ligatures
    func toggleLigatures() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.ligature, in: range) { value, subrange, _ in
            let currentLigature = (value as? Int) ?? 1
            let newValue = currentLigature == 0 ? 1 : 0
            storage.addAttribute(.ligature, value: newValue, range: subrange)
        }
    }
    
    // MARK: - Baseline Controls
    
    /// Raise baseline
    func raiseBaseline() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.baselineOffset, in: range) { value, subrange, _ in
            let current = (value as? CGFloat) ?? 0
            storage.addAttribute(.baselineOffset, value: current + 1, range: subrange)
        }
    }
    
    /// Lower baseline
    func lowerBaseline() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.baselineOffset, in: range) { value, subrange, _ in
            let current = (value as? CGFloat) ?? 0
            storage.addAttribute(.baselineOffset, value: current - 1, range: subrange)
        }
    }
    
    // MARK: - Advanced Ligatures
    
    /// Use standard ligatures
    func useStandardLigatures() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.addAttribute(.ligature, value: 1, range: range)
    }
    
    /// Use all ligatures
    func useAllLigatures() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.addAttribute(.ligature, value: 2, range: range)
    }
    
    /// Turn off ligatures
    func turnOffLigatures() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.addAttribute(.ligature, value: 0, range: range)
    }
    
    // MARK: - Advanced Kerning
    
    /// Use standard kerning
    func useStandardKerning() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.removeAttribute(.kern, range: range)
    }
    
    /// Turn off kerning (use nominal spacing)
    func turnOffKerning() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.addAttribute(.kern, value: 0.0, range: range)
    }
    
    // MARK: - Panels & UI
    
    /// Show link panel
    func showLinkPanel() {
        currentTextView?.orderFrontLinkPanel(nil)
    }
    
    /// Show list panel
    func showListPanel() {
        currentTextView?.orderFrontListPanel(nil)
    }
    
    /// Show spacing panel
    func showSpacingPanel() {
        currentTextView?.orderFrontSpacingPanel(nil)
    }
    
    /// Show substitutions panel
    func showSubstitutionsPanel() {
        currentTextView?.orderFrontSubstitutionsPanel(nil)
    }
    
    // MARK: - Text Completion
    
    /// Trigger text completion
    func complete() {
        currentTextView?.complete(nil)
    }
    
    // MARK: - Speaking
    
    /// Start speaking text
    func startSpeaking() {
        currentTextView?.startSpeaking(nil)
    }
    
    /// Stop speaking text
    func stopSpeaking() {
        currentTextView?.stopSpeaking(nil)
    }
    
    // MARK: - QuickLook
    
    /// Toggle QuickLook preview
    func toggleQuickLook() {
        currentTextView?.toggleQuickLookPreviewPanel(nil)
    }
    
    // MARK: - Spell Check & Grammar
    
    /// Toggle continuous spell checking
    func toggleContinuousSpellChecking() {
        guard let textView = currentTextView else { return }
        textView.isContinuousSpellCheckingEnabled.toggle()
    }
    
    /// Toggle grammar checking
    func toggleGrammarChecking() {
        guard let textView = currentTextView else { return }
        textView.isGrammarCheckingEnabled.toggle()
    }
    
    /// Check spelling in document
    func checkSpelling() {
        currentTextView?.checkTextInDocument(nil)
    }
    
    // MARK: - Substitutions
    
    /// Toggle automatic quote substitution
    func toggleAutomaticQuoteSubstitution() {
        guard let textView = currentTextView else { return }
        textView.isAutomaticQuoteSubstitutionEnabled.toggle()
    }
    
    /// Toggle automatic dash substitution
    func toggleAutomaticDashSubstitution() {
        guard let textView = currentTextView else { return }
        textView.isAutomaticDashSubstitutionEnabled.toggle()
    }
    
    /// Toggle automatic link detection
    func toggleAutomaticLinkDetection() {
        guard let textView = currentTextView else { return }
        textView.isAutomaticLinkDetectionEnabled.toggle()
    }
    
    /// Toggle automatic data detection
    func toggleAutomaticDataDetection() {
        guard let textView = currentTextView else { return }
        textView.isAutomaticDataDetectionEnabled.toggle()
    }
    
    /// Toggle automatic text replacement
    func toggleAutomaticTextReplacement() {
        guard let textView = currentTextView else { return }
        textView.isAutomaticTextReplacementEnabled.toggle()
    }
    
    /// Toggle automatic spelling correction
    func toggleAutomaticSpellingCorrection() {
        guard let textView = currentTextView else { return }
        textView.isAutomaticSpellingCorrectionEnabled.toggle()
    }
    
    /// Toggle automatic text completion
    func toggleAutomaticTextCompletion() {
        guard let textView = currentTextView else { return }
        textView.isAutomaticTextCompletionEnabled.toggle()
    }
    
    // MARK: - Performance Optimizations
    
    /// Batch multiple text storage updates for better performance
    func batchUpdates(_ updates: () -> Void) {
        guard let storage = currentTextView?.textStorage else { return }
        storage.beginEditing()
        updates()
        storage.endEditing()
    }
    
    /// Show font panel (enables usesFontPanel temporarily)
    func showFontPanel() {
        guard let textView = currentTextView else { return }
        textView.usesFontPanel = true
        NSFontManager.shared.orderFrontFontPanel(textView)
        
        // Re-disable after showing to maintain performance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak textView] in
            textView?.usesFontPanel = false
        }
    }
    
    // MARK: - Text Attachments
    
    /// Insert an image at the current insertion point or replace selection
    func insertImage(_ image: NSImage) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let attachment = NSTextAttachment()
        attachment.image = image
        
        let attrString = NSAttributedString(attachment: attachment)
        let range = textView.selectedRange()
        
        storage.replaceCharacters(in: range, with: attrString)
        
        // Move cursor after attachment
        textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
    }
    
    /// Insert an image from a file URL
    func insertImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        insertImage(image)
    }
    
    /// Insert a file attachment
    func insertFileAttachment(from url: URL) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let attachment = NSTextAttachment()
        attachment.fileWrapper = try? FileWrapper(url: url, options: .immediate)
        
        let attrString = NSAttributedString(attachment: attachment)
        let range = textView.selectedRange()
        
        storage.replaceCharacters(in: range, with: attrString)
        textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
    }
    
    /// Resize selected image attachment
    func resizeSelectedImage(to size: NSSize) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.attachment, in: range) { value, subrange, _ in
            guard let attachment = value as? NSTextAttachment,
                  let image = attachment.image else { return }
            
            // Create resized image
            let resized = NSImage(size: size)
            resized.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: size))
            resized.unlockFocus()
            
            attachment.image = resized
            
            // Trigger display update
            storage.edited(.editedAttributes, range: subrange, changeInLength: 0)
        }
    }
    
    // MARK: - Typography & Advanced Layout
    
    /// Set paragraph spacing
    func setParagraphSpacing(_ spacing: CGFloat) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.paragraphStyle, in: range) { value, subrange, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.paragraphSpacing = spacing
            storage.addAttribute(.paragraphStyle, value: style, range: subrange)
        }
    }
    
    /// Set line spacing
    func setLineSpacing(_ spacing: CGFloat) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.paragraphStyle, in: range) { value, subrange, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.lineSpacing = spacing
            storage.addAttribute(.paragraphStyle, value: style, range: subrange)
        }
    }
    
    /// Set line height multiple
    func setLineHeightMultiple(_ multiple: CGFloat) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.enumerateAttribute(.paragraphStyle, in: range) { value, subrange, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.lineHeightMultiple = multiple
            storage.addAttribute(.paragraphStyle, value: style, range: subrange)
        }
    }
    
    /// Set text expansion (condensed/expanded)
    func setExpansion(_ expansion: CGFloat) {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        storage.addAttribute(.expansion, value: expansion, range: range)
    }
    
    /// Make text uppercase
    func makeUppercase() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return}
        
        let text = storage.attributedSubstring(from: range)
        let uppercased = NSMutableAttributedString(attributedString: text)
        uppercased.mutableString.replaceCharacters(in: NSRange(location: 0, length: text.length), with: text.string.uppercased())
        
        storage.replaceCharacters(in: range, with: uppercased)
    }
    
    /// Make text lowercase
    func makeLowercase() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        let text = storage.attributedSubstring(from: range)
        let lowercased = NSMutableAttributedString(attributedString: text)
        lowercased.mutableString.replaceCharacters(in: NSRange(location: 0, length: text.length), with: text.string.lowercased())
        
        storage.replaceCharacters(in: range, with: lowercased)
    }
    
    /// Make text capitalized
    func makeCapitalized() {
        guard let textView = currentTextView,
              let storage = textView.textStorage else { return }
        
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        let text = storage.attributedSubstring(from: range)
        let capitalized = NSMutableAttributedString(attributedString: text)
        capitalized.mutableString.replaceCharacters(in: NSRange(location: 0, length: text.length), with: text.string.capitalized)
        
        storage.replaceCharacters(in: range, with: capitalized)
    }
    
    // MARK: - Custom Text Completion
    
    /// Invoice-specific completion terms
    private static let invoiceCompletions: [String] = [
        "Invoice", "Invoice Number", "Invoice Date",
        "Payment Terms", "Due Date", "Payment Due",
        "Subtotal", "Tax", "Total", "Grand Total",
        "Net 30", "Net 60", "Net 90",
        "% discount", "Discount",
        "Quantity", "Unit Price", "Amount",
        "Description", "Item", "Product",
        "Bill To", "Ship To", "Sold To",
        "Company Name", "Address", "Phone", "Email",
        "Thank you for your business"
    ]
    
    /// Get custom completions for partial word
    func customCompletions(for partialWord: String) -> [String] {
        guard !partialWord.isEmpty else { return [] }
        
        return Self.invoiceCompletions.filter {
            $0.localizedCaseInsensitiveContains(partialWord)
        }
    }
    
    /// Get text statistics for current selection or entire text
    func textStatistics() -> TextStatistics? {
        guard let textView = currentTextView else { return nil }
        
        let range = textView.selectedRange()
        let text: String
        
        if range.length > 0 {
            text = (textView.string as NSString).substring(with: range)
        } else {
            text = textView.string
        }
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let lines = text.components(separatedBy: .newlines)
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        
        return TextStatistics(
            characters: text.count,
            words: words.count,
            lines: lines.count,
            paragraphs: paragraphs.count
        )
    }
}

/// Text statistics structure
struct TextStatistics {
    let characters: Int
    let words: Int
    let lines: Int
    let paragraphs: Int
}
