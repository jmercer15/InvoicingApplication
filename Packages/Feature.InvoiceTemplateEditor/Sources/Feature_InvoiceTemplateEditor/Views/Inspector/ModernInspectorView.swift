import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Foundation

// MARK: - Modern Inspector View

struct ModernInspectorView: View {
    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    
    // Property editor section states
    @State private var isTypographyExpanded = true
    @State private var isContentExpanded = true
    @State private var isSectionLayoutExpanded = true
    @State private var isBackgroundExpanded = true
    @State private var isBorderExpanded = true
    @State private var isShadowExpanded = true
    @State private var isShapeSpecificExpanded = true
    @State private var isImageExpanded = true
    @State private var isTableExpanded = true
    @State private var isColumnWidthExpanded = true
    @State private var isTableLayoutExpanded = true
    @State private var isTableFillExpanded = true
    @State private var isTableStrokeExpanded = true
    @State private var isTableSpacingExpanded = true
    @State private var isTableContentExpanded = true

    var body: some View {
        Group {
            if let selectedComponent = document.component(document.selectedComponentID) {
                // Property editor content
        VStack(alignment: .leading, spacing: 0) {
                    // Property editor header
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundColor(Color.accentColor)
                
                Text("Properties")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryText)
            }
            
            Spacer()
            
                        // Component type tag
            if selectedComponent.type.supportsTypography {
                TagView(text: "Text")
            } else if selectedComponent.type.isSection {
                TagView(text: "Section")
            } else if selectedComponent.type.isImageComponent {
                TagView(text: "Image")
                        } else {
                            TagView(text: "Shape")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
                    
                    Divider()
                        .background(Color.primaryOutline.opacity(0.3))
                    
                    // Property editor content
        ScrollView(.vertical, showsIndicators: true) {
                ModernComponentStyleEditor(
                    component: selectedComponent,
                    isTypographyExpanded: $isTypographyExpanded,
                    isContentExpanded: $isContentExpanded,
                    isSectionLayoutExpanded: $isSectionLayoutExpanded,
                    isBackgroundExpanded: $isBackgroundExpanded,
                    isBorderExpanded: $isBorderExpanded,
                    isShadowExpanded: $isShadowExpanded,
                    isShapeSpecificExpanded: $isShapeSpecificExpanded,
                    isImageExpanded: $isImageExpanded,
                    isTableExpanded: $isTableExpanded,
                    isColumnWidthExpanded: $isColumnWidthExpanded,
                            isTableLayoutExpanded: $isTableLayoutExpanded,
                            isTableFillExpanded: $isTableFillExpanded,
                            isTableStrokeExpanded: $isTableStrokeExpanded,
                            isTableSpacingExpanded: $isTableSpacingExpanded,
                            isTableContentExpanded: $isTableContentExpanded
                        )
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 32))
                        .foregroundColor(Color.secondaryText)
                    
                    Text("No Component Selected")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(Color.primaryText)
                    
                    Text("Select a component to edit its properties")
                        .font(.body)
                        .foregroundColor(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primarySurface.opacity(0.95))
                    .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primaryOutline.opacity(0.2), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.25), value: document.selectedComponentID != nil)
        .foregroundColor(Color.primaryText)
    }
}

// MARK: - Tag View

private struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(Color.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(Color.accentColor.opacity(0.18), lineWidth: 0.5)
                    )
            )
    }
}