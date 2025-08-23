import SwiftUI

struct SaveTemplateDialog: View {
    @EnvironmentObject private var document: InvoiceDocument
    @Environment(\.dismiss) private var dismiss
    
    @State private var templateName = ""
    @State private var templateDescription = ""
    @State private var templateAuthor = ""
    @State private var templateTags = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Save Template")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Form
            VStack(spacing: 16) {
                // Template Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Template Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter template name", text: $templateName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter description (optional)", text: $templateDescription, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .lineLimit(3...6)
                }
                
                // Author
                VStack(alignment: .leading, spacing: 6) {
                    Text("Author")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter author name (optional)", text: $templateAuthor)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                // Tags
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tags")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter tags separated by commas (optional)", text: $templateTags)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                // Preview
                VStack(alignment: .leading, spacing: 6) {
                    Text("Template Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TemplatePreviewCard()
                        .environmentObject(document)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
            }
            
            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save Template") {
                    saveTemplate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 500)
        .onAppear {
            // Auto-focus the name field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Focus logic would go here if we had a focus state
            }
        }
    }
    
    private func saveTemplate() {
        guard !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Template name is required"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        // Parse tags
        let tags = templateTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        Task {
            let success = await document.saveAsTemplate(
                name: templateName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: templateDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                author: templateAuthor.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: tags
            )
            
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                } else {
                    errorMessage = TemplateManager.shared.lastError ?? "Failed to save template"
                }
            }
        }
    }
}

struct TemplatePreviewCard: View {
    @EnvironmentObject private var document: InvoiceDocument
    
    var body: some View {
        ZStack {
            // Background
            Color.white
            
            // Document preview
            InvoiceCanvasView()
                .environmentObject(document)
                .scaleEffect(0.15) // Scale down to fit in preview
                .allowsHitTesting(false) // Disable interactions in preview
        }
    }
}

#Preview {
    SaveTemplateDialog()
        .environmentObject(InvoiceDocument())
}
