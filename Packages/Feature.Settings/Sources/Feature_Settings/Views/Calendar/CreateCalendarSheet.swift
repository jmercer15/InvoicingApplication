import SwiftUI
import SharedUI

struct CreateCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var color: Color = .accentColor
    @State private var showError: Bool = false
    var onCreate: (String, CGColor?) -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Create New Calendar")
                .font(.title2).bold()
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                TextField("Calendar Title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                ColorPicker("", selection: $color)
            }
            if showError {
                Text("Title is required.")
                    .foregroundStyle(ColorSystem.Status.error)
                    .font(.caption)
            }
            HStack {
                Button("Cancel") {
                    onCancel?()
                    dismiss()
                }
                .buttonStyle(.glass)
                .pointerStyle(.link)
                
                Spacer()
                
                Button("Create") {
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showError = true
                    } else {
                        showError = false
                        onCreate(title, color.cgColor)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .fontWeight(.bold)
                .buttonStyle(.glassProminent)
                .pointerStyle(.link)
            }
        }
        .padding(StyleGuide.Dimensions.paddingXXLarge)
        .frame(width: StyleGuide.Dimensions.settingsCreateCalendarWidth)
    }
} 
