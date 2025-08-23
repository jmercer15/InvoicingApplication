import SwiftUI

struct TemplateBrowserDialog: View {
    @EnvironmentObject private var document: InvoiceDocument
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var templateManager = TemplateManager.shared
    @State private var templates: [TemplateMetadata] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedTemplate: TemplateMetadata?
    @State private var showingDeleteAlert = false
    @State private var templateToDelete: TemplateMetadata?
    
    var filteredTemplates: [TemplateMetadata] {
        if searchText.isEmpty {
            return templates
        } else {
            return templates.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.description.localizedCaseInsensitiveContains(searchText) ||
                template.author.localizedCaseInsensitiveContains(searchText) ||
                template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Template Browser")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding(20)
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search templates...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
            
            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading templates...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else if filteredTemplates.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(searchText.isEmpty ? "No templates found" : "No templates match your search")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if searchText.isEmpty {
                        Text("Create your first template by saving your current design")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredTemplates, id: \.id) { template in
                            TemplateCard(
                                template: template,
                                isSelected: selectedTemplate?.id == template.id,
                                onSelect: { selectedTemplate = template },
                                onLoad: { loadTemplate(template) },
                                onDelete: { deleteTemplate(template) }
                            )
                        }
                    }
                    .padding(20)
                }
            }
            
            // Footer
            if !filteredTemplates.isEmpty {
                Divider()
                
                HStack {
                    Text("\(filteredTemplates.count) template\(filteredTemplates.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let selectedTemplate = selectedTemplate {
                        Button("Load Template") {
                            loadTemplate(selectedTemplate)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 800, height: 600)
        .onAppear {
            loadTemplates()
        }
        .alert("Delete Template", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                templateToDelete = nil
            }
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
        } message: {
            if let template = templateToDelete {
                Text("Are you sure you want to delete '\(template.name)'? This action cannot be undone.")
            }
        }
    }
    
    private func loadTemplates() {
        isLoading = true
        
        Task {
            let loadedTemplates = await templateManager.browseTemplates()
            
            await MainActor.run {
                templates = loadedTemplates
                isLoading = false
            }
        }
    }
    
    private func loadTemplate(_ template: TemplateMetadata) {
        isLoading = true
        
        Task {
            if let templateData = await templateManager.loadTemplate(metadata: template) {
                await MainActor.run {
                    document.loadTemplate(templateData)
                    isLoading = false
                    dismiss()
                }
            } else {
                await MainActor.run {
                    isLoading = false
                    // Error is already set in TemplateManager
                }
            }
        }
    }
    
    private func deleteTemplate(_ template: TemplateMetadata) {
        templateToDelete = template
        showingDeleteAlert = true
    }
    
    private func confirmDelete() {
        guard let template = templateToDelete else { return }
        
        Task {
            let success = await templateManager.deleteTemplate(metadata: template)
            
            await MainActor.run {
                if success {
                    templates.removeAll { $0.id == template.id }
                    if selectedTemplate?.id == template.id {
                        selectedTemplate = nil
                    }
                }
                templateToDelete = nil
                showingDeleteAlert = false
            }
        }
    }
}

struct TemplateCard: View {
    let template: TemplateMetadata
    let isSelected: Bool
    let onSelect: () -> Void
    let onLoad: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail
            ZStack {
                if let thumbnailData = template.thumbnailData,
                   let image = NSImage(data: thumbnailData) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "doc.text")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                        )
                }
                
                // Overlay for selection
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(height: 120)
                }
            }
            
            // Template info
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if !template.description.isEmpty {
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    if !template.author.isEmpty {
                        Text("by \(template.author)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(template.modifiedAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Tags
                if !template.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(template.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            // Actions
            HStack {
                Button("Load") {
                    onLoad()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Spacer()
                
                Button("Delete") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isSelected ? 0.05 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

#Preview {
    TemplateBrowserDialog()
        .environmentObject(InvoiceDocument())
}
