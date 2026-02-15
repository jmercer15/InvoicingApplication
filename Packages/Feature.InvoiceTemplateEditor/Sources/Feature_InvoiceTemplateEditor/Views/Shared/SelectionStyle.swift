//
//  SelectionStyle.swift
//  Feature.InvoiceTemplateEditor
//
//  Defines distinct visual styles for different selectable element types
//

import SwiftUI

/// Defines the visual style for selection and hover states of different element types
enum SelectionElementType {
    case split      // Parent container sections
    case leaf       // Child sections within splits
    case component  // Actual content items (grids, images, text, etc.)
    
    // Common opacity scale for harmony
    private var strongOpacity: Double { 0.9 }
    private var lightOpacity: Double { 0.06 }
    
    // MARK: - Colors
    
    /// Base color for this element type
    private var baseColor: Color {
        switch self {
        case .split:
            return Color(NSColor.systemPurple)
        case .leaf:
            return Color(NSColor.systemOrange)
        case .component:
            return Color.accentColor
        }
    }
    
    /// Primary color for selection frame
    var selectionColor: Color {
        baseColor.opacity(strongOpacity)
    }
    
    /// Fill color for hover state
    var hoverFillColor: Color {
        baseColor.opacity(lightOpacity)
    }
    
    // MARK: - Drop Target Colors
    
    /// Primary color for drop target state
    var dropTargetColor: Color {
        Color(NSColor.systemGreen).opacity(0.85)
    }
    
    /// Fill color for drop target state
    var dropTargetFillColor: Color {
        Color(NSColor.systemGreen).opacity(0.12)
    }
    
    /// Dash pattern for drop target
    var dropTargetDashPattern: [CGFloat] {
        [5, 3]
    }
    
    // MARK: - Line Styles
    
    /// Line width for selection
    var selectionLineWidth: CGFloat {
        switch self {
        case .split:
            return 2.0
        case .leaf:
            return 2.0
        case .component:
            return 2.0
        }
    }
    
    /// Dash pattern for selection (nil = solid)
    var selectionDashPattern: [CGFloat]? {
        switch self {
        case .split:
            return [3, 2]    // Dotted (same for split and leaf)
        case .leaf:
            return [3, 2]    // Dotted (same for split and leaf)
        case .component:
            return nil       // Solid
        }
    }
    
    // MARK: - Handle Style
    
    /// Handle background color when selected
    var handleSelectedColor: Color {
        selectionColor
    }
    
    /// Handle background color when not selected
    var handleNormalColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }
}


// MARK: - Selection Handle View

/// A reusable selection handle button with appropriate styling
struct SelectionHandle: View {
    let elementType: SelectionElementType
    let isSelected: Bool
    let action: () -> Void
    var onHover: ((Bool) -> Void)? = nil

    @State private var isHovering = false
    private let size: CGFloat = 18
    private let cornerRadius: CGFloat = 3

    var body: some View {
        ZStack {
            Image("fluent-ic_fluent_maximize_20_regular", bundle: .module)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 10, height: 10)
                .foregroundStyle(isSelected ? .white : elementType.selectionColor)
                .rotationEffect(isHovering ? .degrees(5) : .degrees(0))
        }
        .frame(width: size, height: size)
        .contentShape(.rect(cornerRadius: cornerRadius))
        /*.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    elementType.selectionColor.opacity(isSelected ? 0.55 : 0.35),
                    lineWidth: 0.5
                )
        )*/
        //.shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        //.scaleEffect(isHovering ? 1.1 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovering)
        .background(
            isSelected 
                ? elementType.selectionColor.opacity(0.2)
                : Color(NSColor.controlBackgroundColor).opacity(0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Select this \(accessibilityLabelText.lowercased())")
        .accessibilityAddTraits(.isButton)
        .onHover { hovering in
            isHovering = hovering
            onHover?(hovering)
        }
        .onTapGesture {
            action()
        }
        .pointerStyle(.link)
    }

    private var accessibilityLabelText: String {
        switch elementType {
        case .split:
            return "Split section"
        case .leaf:
            return "Leaf section"
        case .component:
            return "Component"
        }
    }
}

// MARK: - State Overlay View

/// Unified overlay for hover, selection, and drop target states.
/// Uses a clear visual hierarchy: drop target > selection > hover
struct StateOverlay: View {
    let elementType: SelectionElementType
    let isHovered: Bool
    let isSelected: Bool
    let isDropTarget: Bool
    
    private let cornerRadius: CGFloat = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Computed State
    
    private var activeState: ActiveState {
        if isDropTarget { return .dropTarget }
        if isSelected { return .selected }
        if isHovered { return .hovered }
        return .none
    }
    
    private enum ActiveState {
        case none, hovered, selected, dropTarget
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Fill layer
            if let fill = fillColor {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill)
            }
            
            // Stroke layer with subtle shadow
            if let (color, style) = strokeStyle {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(color, style: style)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 1)
            }
        }
        .animation(.easeOut(duration: 0.12), value: activeState)
        .allowsHitTesting(false)
    }
    
    // MARK: - Visual Properties
    
    private var fillColor: Color? {
        switch activeState {
        case .dropTarget:
            return elementType.dropTargetFillColor
        case .hovered:
            return elementType.hoverFillColor
        case .selected, .none:
            return nil
        }
    }
    
    private var strokeStyle: (Color, StrokeStyle)? {
        switch activeState {
        case .dropTarget:
            return (
                elementType.dropTargetColor,
                StrokeStyle(lineWidth: 2, dash: elementType.dropTargetDashPattern)
            )
        case .selected:
            let dash = elementType.selectionDashPattern
            return (
                elementType.selectionColor,
                dash != nil
                    ? StrokeStyle(lineWidth: elementType.selectionLineWidth, dash: dash!)
                    : StrokeStyle(lineWidth: elementType.selectionLineWidth)
            )
        case .hovered, .none:
            return nil
        }
    }
}

// MARK: - Previews

#Preview("SelectionHandle - States") {
    HStack(spacing: 20) {
        VStack {
            SelectionHandle(elementType: .split, isSelected: false) {}
            Text("Split").font(.caption)
        }
        VStack {
            SelectionHandle(elementType: .split, isSelected: true) {}
            Text("Split (sel)").font(.caption)
        }
        VStack {
            SelectionHandle(elementType: .leaf, isSelected: false) {}
            Text("Leaf").font(.caption)
        }
        VStack {
            SelectionHandle(elementType: .leaf, isSelected: true) {}
            Text("Leaf (sel)").font(.caption)
        }
        VStack {
            SelectionHandle(elementType: .component, isSelected: false) {}
            Text("Component").font(.caption)
        }
        VStack {
            SelectionHandle(elementType: .component, isSelected: true) {}
            Text("Comp (sel)").font(.caption)
        }
    }
    .padding()
}

#Preview("StateOverlay - All States") {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.2))
                StateOverlay(elementType: .split, isHovered: true, isSelected: false, isDropTarget: false)
                Text("Hovered").font(.caption)
            }
            .frame(width: 100, height: 60)
            
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.2))
                StateOverlay(elementType: .split, isHovered: false, isSelected: true, isDropTarget: false)
                Text("Selected").font(.caption)
            }
            .frame(width: 100, height: 60)
            
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.2))
                StateOverlay(elementType: .split, isHovered: false, isSelected: false, isDropTarget: true)
                Text("Drop Target").font(.caption)
            }
            .frame(width: 100, height: 60)
        }
        
        HStack(spacing: 16) {
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.2))
                StateOverlay(elementType: .leaf, isHovered: false, isSelected: true, isDropTarget: false)
                Text("Leaf Selected").font(.caption)
            }
            .frame(width: 100, height: 60)
            
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.2))
                StateOverlay(elementType: .component, isHovered: false, isSelected: true, isDropTarget: false)
                Text("Component").font(.caption)
            }
            .frame(width: 100, height: 60)
        }
    }
    .padding()
}
