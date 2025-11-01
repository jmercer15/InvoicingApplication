import SwiftUI
import Data
import Core
import SharedUI

extension String {
    func width(for font: Font = .body) -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (self as NSString).size(withAttributes: attributes)
        return size.width
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content
    let labelWidth: CGFloat

    init(label: String, labelWidth: CGFloat = 120, @ViewBuilder content: () -> Content) {
        self.label = label
        self.labelWidth = labelWidth
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .frame(width: labelWidth, alignment: .trailing)
                .lineLimit(1)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall) // Add some vertical spacing between rows
    }
} 
