import SwiftUI

struct CreateCalendarSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var title: String = ""
    @State private var color: Color = .accentColor
    @State private var showError: Bool = false
    var onCreate: (String, CGColor?) -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Create New Calendar")
                .font(.title2).bold()
            FormTextField(label: "Title", text: $title)
            FormColorPicker(label: "Color", color: $color)
            if showError {
                Text("Title is required.")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            HStack {
                Button("Cancel") {
                    onCancel?()
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
                Button("Create") {
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showError = true
                    } else {
                        showError = false
                        onCreate(title, color.cgColor)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .fontWeight(.bold)
            }
        }
        .padding(32)
        .frame(width: 400)
    }
} 