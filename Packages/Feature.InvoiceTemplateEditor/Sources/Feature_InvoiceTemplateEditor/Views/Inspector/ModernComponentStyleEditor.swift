//
//  ModernComponentStyleEditor.swift
//  Feature.InvoiceTemplateEditor
//
//  Modern component style editor using modular property sections
//

import SwiftUI
import Core

struct ModernComponentStyleEditor: View {
    @EnvironmentObject private var document: InvoiceDocument
    let component: InvoiceComponent
    
    @Binding var isTypographyExpanded: Bool
    @Binding var isContentExpanded: Bool
    @Binding var isSectionLayoutExpanded: Bool
    @Binding var isBackgroundExpanded: Bool
    @Binding var isBorderExpanded: Bool
    @Binding var isShadowExpanded: Bool
    @Binding var isShapeSpecificExpanded: Bool
    @Binding var isImageExpanded: Bool
    @Binding var isTableExpanded: Bool
    @Binding var isColumnWidthExpanded: Bool
    @Binding var isTableLayoutExpanded: Bool
    @Binding var isTableFillExpanded: Bool
    @Binding var isTableStrokeExpanded: Bool
    @Binding var isTableSpacingExpanded: Bool
    @Binding var isTableContentExpanded: Bool
    
    var body: some View {
        Form {
            // Content & Typography Section
            Section {
                // Typography section for text-based components
                if component.type.supportsTypography {
                    DisclosureGroup("Typography", isExpanded: $isTypographyExpanded) {
                        TypographySectionContent(component: component)
                    }
                }
                
                // Content section for textBox and notes
                if component.type == .textBox || component.type == .notes {
                    DisclosureGroup("Content", isExpanded: $isContentExpanded) {
                        ContentSectionContent(component: component)
                    }
                }
                
                // Section layout for section components that don't use table properties
                if component.type.isSection && !component.type.usesTableProperties {
                    DisclosureGroup("Section Layout", isExpanded: $isSectionLayoutExpanded) {
                        SectionLayoutSectionContent(component: component)
                    }
                }
            } header: {
                Text("Content & Typography")
            }
            
            // Appearance Section
            Section {
                // Background section for all components
                DisclosureGroup(
                    component.type == .lineShape ? "Line" : "Background & Border",
                    isExpanded: $isBackgroundExpanded
                ) {
                    BackgroundSectionContent(component: component)
                }
                
                // Shadow section for components that support shadows
                if component.type.supportsShadow {
                    DisclosureGroup("Shadow", isExpanded: $isShadowExpanded) {
                        ShadowSectionContent(component: component)
                    }
                }
            } header: {
                Text("Appearance")
            }
            
            // Component-Specific Section
            Section {
                // Shape-specific section for shape components
                if component.type.isShape {
                    DisclosureGroup("Shape Properties", isExpanded: $isShapeSpecificExpanded) {
                        ShapeSpecificSectionContent(component: component)
                    }
                }
                
                // Image section for image components
                if component.type.isImageComponent {
                    DisclosureGroup("Image Properties", isExpanded: $isImageExpanded) {
                        ImageSectionContent(component: component)
                    }
                }
            } header: {
                Text("Component-Specific")
            }
            
            // Table Properties Section
            if component.type.usesTableProperties {
                Section {
                    DisclosureGroup("Layout", isExpanded: $isTableLayoutExpanded) {
                        TableLayoutSectionContent(component: component)
                    }
                    
                    DisclosureGroup("Fill", isExpanded: $isTableFillExpanded) {
                        TableFillSectionContent(component: component)
                    }
                    
                    DisclosureGroup("Stroke", isExpanded: $isTableStrokeExpanded) {
                        TableStrokeSectionContent(component: component)
                    }
                    
                    DisclosureGroup("Spacing", isExpanded: $isTableSpacingExpanded) {
                        TableSpacingSectionContent(component: component)
                    }
                    
                    DisclosureGroup("Content", isExpanded: $isTableContentExpanded) {
                        TableContentSectionContent(component: component)
                    }
                } header: {
                    Text("Table Properties")
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity)
    }
}
