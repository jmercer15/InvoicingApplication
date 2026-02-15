//
//  SidePanel.swift
//  Feature.InvoiceTemplateEditor
//
//  Unified side panel component with consistent styling and layout
//

import SwiftUI
import SharedUI

/// Configuration for a side panel
struct SidePanelConfiguration {
    let defaultWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    
    static let palette = SidePanelConfiguration(
        defaultWidth: 340,
        minWidth: 300,
        maxWidth: 480
    )
    
    static let sections = SidePanelConfiguration(
        defaultWidth: 320,
        minWidth: 280,
        maxWidth: 420
    )
    
    static let inspector = SidePanelConfiguration(
        defaultWidth: 340,
        minWidth: 300,
        maxWidth: 480
    )
}

/// Unified side panel container with consistent styling
struct SidePanel<Content: View>: View {
    let configuration: SidePanelConfiguration
    let useGlassEffect: Bool
    let fixedVerticalSize: Bool
    @ViewBuilder let content: () -> Content
    
    init(
        configuration: SidePanelConfiguration,
        useGlassEffect: Bool = true,
        fixedVerticalSize: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.configuration = configuration
        self.useGlassEffect = useGlassEffect
        self.fixedVerticalSize = fixedVerticalSize
        self.content = content
    }
    
    var body: some View {
        content()
            .frame(
                minWidth: configuration.minWidth,
                idealWidth: configuration.defaultWidth,
                maxWidth: configuration.maxWidth,
                alignment: .top
            )
            .fixedSize(horizontal: true, vertical: fixedVerticalSize)
            .modifier(GlassEffectModifier(enabled: useGlassEffect))
            .padding(TemplateEditorPanelStyle.outerPadding)
    }
}

private struct GlassEffectModifier: ViewModifier {
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: TemplateEditorPanelStyle.cornerRadius))
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview("SidePanel - Configurations") {
    HStack(spacing: 20) {
        SidePanel(configuration: .palette) {
            VStack {
                Text("Component Library")
                    .font(.headline)
                Text("Palette Panel")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        }
        .frame(height: 200)
        
        SidePanel(configuration: .inspector) {
            VStack {
                Text("Properties")
                    .font(.headline)
                Text("Inspector Panel")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        }
        .frame(height: 200)
    }
    .padding()
}
