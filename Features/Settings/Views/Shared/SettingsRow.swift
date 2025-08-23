import SwiftUI

struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content
    private let labelWidth: CGFloat = 120 // Adjust as needed

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4) // Add some vertical spacing between rows
    }
} 