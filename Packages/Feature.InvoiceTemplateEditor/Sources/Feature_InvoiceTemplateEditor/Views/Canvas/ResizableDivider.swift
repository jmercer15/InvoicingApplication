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
    
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    @State private var initialOffset: CGFloat = 0.0
    
    var body: some View {
        // Visual divider with enhanced design
        let isColumnDivider = direction == .horizontal
        let thickness: CGFloat = (isHovered || isDragging) ? 6 : 1.5

        Rectangle()
            .fill(isHovered || isDragging ? Color.accentColor : Color.accentColor.opacity(0.35))
            .frame(
                width: isColumnDivider ? thickness : nil,
                height: isColumnDivider ? nil : thickness
            )
            .frame(
                maxWidth: isColumnDivider ? nil : .infinity,
                maxHeight: isColumnDivider ? .infinity : nil
            )
            .shadow(
                color: isHovered || isDragging ? Color.accentColor.opacity(0.3) : Color.clear,
                radius: isHovered || isDragging ? 2 : 0,
                x: 0,
                y: 0
            )
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: isDragging)
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
                        print("Divider drag started - direction: \(direction)")
                    }
                    
                    let delta: CGFloat
                    switch direction {
                    case .horizontal:
                        // Horizontal dividers always control width, regardless of alignment
                        delta = value.translation.width
                        print("Horizontal divider: using width translation = \(delta)")
                    case .vertical:
                        // Vertical dividers always control height, regardless of alignment
                        delta = value.translation.height
                        print("Vertical divider: using height translation = \(delta)")
                    case .grid:
                        // This should never happen for individual dividers
                        delta = 0
                    }
                    
                    print("Divider drag delta: \(delta) for direction: \(direction)")
                    onResize(delta)
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDragging = false
                    }
                    print("Divider drag ended")
                }
        )
    }
}

