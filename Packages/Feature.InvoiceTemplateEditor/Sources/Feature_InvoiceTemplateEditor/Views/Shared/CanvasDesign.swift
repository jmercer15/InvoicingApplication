//
//  CanvasDesign.swift
//  Feature.InvoiceTemplateEditor
//
//  Shared design tokens for Canvas UI (spacing, z-index, shadows, radii)
//

import SwiftUI

enum CanvasZ {
    static let background: Double = 0
    static let content: Double = 1
    static let hover: Double = 2
    static let selection: Double = 3
    static let dividers: Double = 4
    static let handles: Double = 5
    static let overlays: Double = 10
}

enum CanvasSpacing {
    static let tight: CGFloat = 4
    static let standard: CGFloat = 8
    static let loose: CGFloat = 12
    static let paddingCompact: CGFloat = 6
    static let paddingStandard: CGFloat = 8
    static let paddingComfortable: CGFloat = 12
    static let paddingGenerous: CGFloat = 16
}

enum CanvasRadius {
    static let small: CGFloat = 3
    static let medium: CGFloat = 6
    static let large: CGFloat = 12
}

enum CanvasShadow {
    static let subtle = (color: Color.black.opacity(0.08), radius: CGFloat(3), y: CGFloat(1))
    static let medium = (color: Color.black.opacity(0.12), radius: CGFloat(6), y: CGFloat(3))
    static let strong = (color: Color.black.opacity(0.18), radius: CGFloat(12), y: CGFloat(6))
}

enum CanvasColor {
    static let subtleFill = Color(NSColor.windowBackgroundColor).opacity(0.9)
    static let hoverGlow = Color.accentColor.opacity(0.2)
    static let successFlash = Color(NSColor.systemGreen)
    static let neutralStroke = Color(NSColor.separatorColor).opacity(0.6)
    static let pulseFill = Color.accentColor.opacity(0.08)
}

// MARK: - Preview

#Preview("Canvas Design Tokens") {
    VStack(alignment: .leading, spacing: 20) {
        // Spacing demo
        VStack(alignment: .leading, spacing: 4) {
            Text("Spacing").font(.headline)
            HStack(spacing: 4) {
                Rectangle().fill(Color.blue).frame(width: CanvasSpacing.tight, height: 20)
                Text("Tight (4)")
                    .font(.caption)
            }
            HStack(spacing: 4) {
                Rectangle().fill(Color.blue).frame(width: CanvasSpacing.standard, height: 20)
                Text("Standard (8)")
                    .font(.caption)
            }
            HStack(spacing: 4) {
                Rectangle().fill(Color.blue).frame(width: CanvasSpacing.loose, height: 20)
                Text("Loose (12)")
                    .font(.caption)
            }
        }
        
        // Radius demo
        VStack(alignment: .leading, spacing: 4) {
            Text("Corner Radius").font(.headline)
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: CanvasRadius.small)
                    .fill(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .overlay(Text("S").foregroundColor(.white))
                
                RoundedRectangle(cornerRadius: CanvasRadius.medium)
                    .fill(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .overlay(Text("M").foregroundColor(.white))
                
                RoundedRectangle(cornerRadius: CanvasRadius.large)
                    .fill(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .overlay(Text("L").foregroundColor(.white))
            }
        }
        
        // Shadow demo
        VStack(alignment: .leading, spacing: 4) {
            Text("Shadows").font(.headline)
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 60, height: 40)
                    .shadow(
                        color: CanvasShadow.subtle.color,
                        radius: CanvasShadow.subtle.radius,
                        y: CanvasShadow.subtle.y
                    )
                    .overlay(Text("Subtle").font(.caption2))
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 60, height: 40)
                    .shadow(
                        color: CanvasShadow.medium.color,
                        radius: CanvasShadow.medium.radius,
                        y: CanvasShadow.medium.y
                    )
                    .overlay(Text("Medium").font(.caption2))
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 60, height: 40)
                    .shadow(
                        color: CanvasShadow.strong.color,
                        radius: CanvasShadow.strong.radius,
                        y: CanvasShadow.strong.y
                    )
                    .overlay(Text("Strong").font(.caption2))
            }
        }
        
        // Colors demo
        VStack(alignment: .leading, spacing: 4) {
            Text("Canvas Colors").font(.headline)
            HStack(spacing: 8) {
                Circle().fill(CanvasColor.subtleFill).frame(width: 24, height: 24)
                Circle().fill(CanvasColor.hoverGlow).frame(width: 24, height: 24)
                Circle().fill(CanvasColor.successFlash).frame(width: 24, height: 24)
                Circle().fill(CanvasColor.neutralStroke).frame(width: 24, height: 24)
                Circle().fill(CanvasColor.pulseFill).frame(width: 24, height: 24)
            }
        }
    }
    .padding()
}
