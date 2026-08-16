import Foundation
import AppKit

/// Writes plain text to the system pasteboard.
public enum ClipboardCopy {
    @discardableResult
    public static func string(_ text: String?) -> Bool {
        guard let text, !text.isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
