import SwiftUI
import SharedUI

/// Label + text field + copy button + optional validation error for relationship detail cards.
struct RelationshipDetailCopyableFieldRow: View {
    let label: String
    let maxLabelWidth: CGFloat
    let placeholder: String
    @Binding var text: String
    let errorMessage: String?
    let copyAccessibilityLabel: String
    let copyAccessibilityHint: String
    let onCopy: () -> Void
    let onTextChange: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
            Text(label)
                .frame(width: maxLabelWidth, alignment: .trailing)
                .foregroundStyle(StyleGuide.Colors.text)

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                HStack {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(errorMessage != nil ? ColorSystem.Status.error : StyleGuide.Colors.text)
                        .tint(errorMessage != nil ? ColorSystem.Status.error : ColorSystem.Status.info)
                        .onChange(of: text) { _, _ in onTextChange() }

                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .accessibilityLabel(copyAccessibilityLabel)
                    .accessibilityHint(copyAccessibilityHint)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .formErrorStyle()
                }
            }
        }
    }
}
