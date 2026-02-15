//
//  ResizableDivider.swift
//  Feature.InvoiceTemplateEditor
//
//  Draggable divider for resizing sections
//

import SwiftUI

struct ResizableDivider: View {
    let direction: SectionSplit.SplitDirection
    let onResize: (CGFloat) -> Void
    var onResizeStart: (() -> Void)? = nil
    var onResizeEnd: (() -> Void)? = nil
    var isVisible: Bool = true
    
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    @State private var initialOffset: CGFloat = 0.0
    
    var body: some View {
        // Visual divider with enhanced design
        let isColumnDivider = direction == .horizontal
        let baseThickness: CGFloat = 1.5
        let scaleFactor: CGFloat = (isHovered || isDragging) ? 2.0 : 1.0
        let active = isHovered || isDragging
        let gradient = LinearGradient(
            colors: [
                Color.accentColor.opacity(active ? 0.9 : 0.35),
                Color.accentColor.opacity(active ? 0.7 : 0.25)
            ],
            startPoint: isColumnDivider ? .top : .leading,
            endPoint: isColumnDivider ? .bottom : .trailing
        )

        Rectangle()
            .fill(gradient)
            .frame(
                width: isColumnDivider ? baseThickness : nil,
                height: isColumnDivider ? nil : baseThickness
            )
            .frame(
                maxWidth: isColumnDivider ? nil : .infinity,
                maxHeight: isColumnDivider ? .infinity : nil
            )
            .scaleEffect(
                CGSize(
                    width: isColumnDivider ? scaleFactor : 1,
                    height: isColumnDivider ? 1 : scaleFactor
                ),
                anchor: .center
            )
            .shadow(
                color: active ? Color.accentColor.opacity(0.35) : Color.clear,
                radius: active ? 4 : 0,
                x: 0,
                y: 0
            )
            .overlay(
                grabberDots(isColumnDivider: isColumnDivider)
            )
            .overlay(
                directionIndicator(isColumnDivider: isColumnDivider)
                    .opacity(active ? 0.7 : 0)
            )
            .overlay(
                // Soft glow ring on drag
                Group {
                    if isDragging {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.35), lineWidth: 6)
                            .blur(radius: 4)
                            .scaleEffect(1.1)
                    }
                }
            )
            .animation(CanvasAnimation.standard, value: isHovered)
            .animation(CanvasAnimation.quick, value: isDragging)
            .opacity(isVisible ? (active ? 0.9 : 0.35) : 0)
            .accessibilityLabel(isColumnDivider ? "Vertical divider" : "Horizontal divider")
            .accessibilityHint("Drag to resize adjacent sections")
            .zIndex(CanvasZ.dividers)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .pointerStyle(direction == .horizontal ? .columnResize : .rowResize)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isDragging = true
                        }
                        dragStart = value.startLocation
                        initialOffset = 0.0
                        onResizeStart?()
                    }
                    
                    let delta: CGFloat
                    switch direction {
                    case .horizontal:
                        // Horizontal dividers always control width, regardless of alignment
                        delta = value.translation.width
                    case .vertical:
                        // Vertical dividers always control height, regardless of alignment
                        delta = value.translation.height
                    case .grid:
                        // This should never happen for individual dividers
                        delta = 0
                    }
                    onResize(delta)
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDragging = false
                    }
                    onResizeEnd?()
                }
        )
    }
    
    @ViewBuilder
    private func grabberDots(isColumnDivider: Bool) -> some View {
        if isHovered || isDragging {
            if isColumnDivider {
                VStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 2, height: 2)
                    }
                }
                .padding(.horizontal, 2)
            } else {
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 2, height: 2)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    @ViewBuilder
    private func directionIndicator(isColumnDivider: Bool) -> some View {
        let iconName = isColumnDivider ? "fluent-ic_fluent_arrow_swap_20_regular" : "fluent-ic_fluent_arrow_sort_20_regular"
        let arrow = Image(iconName, bundle: .module)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: 10, height: 10)
            .foregroundColor(Color.white.opacity(0.9))
            .padding(4)
        if isColumnDivider {
            arrow
        } else {
            arrow
        }
    }
}

// MARK: - Previews

#Preview("Horizontal Divider") {
    HStack(spacing: 0) {
        Rectangle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 100)
        
        ResizableDivider(direction: .horizontal, onResize: { _ in })
        
        Rectangle()
            .fill(Color.green.opacity(0.2))
            .frame(width: 100)
    }
    .frame(height: 200)
    .padding()
}

#Preview("Vertical Divider") {
    VStack(spacing: 0) {
        Rectangle()
            .fill(Color.blue.opacity(0.2))
            .frame(height: 80)
        
        ResizableDivider(direction: .vertical, onResize: { _ in })
        
        Rectangle()
            .fill(Color.green.opacity(0.2))
            .frame(height: 80)
    }
    .frame(width: 200)
    .padding()
}
