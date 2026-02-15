//
//  RatioBasedLayout.swift
//  Feature.InvoiceTemplateEditor
//
//  Layout container that distributes space based on ratios
//

import SwiftUI

struct RatioBasedLayout<Content: View>: View {
    let ratios: [CGFloat]
    let sizingModes: [SectionSplit.SizingMode]
    let intrinsicSizes: [Int: CGFloat]
    let direction: SectionSplit.SplitDirection
    let containerSize: CGSize
    let spacing: CGFloat
    let padding: CGFloat
    let showDividers: Bool
    let content: (Int, CGSize) -> Content
    let onResize: (Int, CGFloat) -> Void
    var onResizeStart: (() -> Void)? = nil
    var onResizeEnd: (() -> Void)? = nil

    init(
        ratios: [CGFloat],
        sizingModes: [SectionSplit.SizingMode] = [],
        intrinsicSizes: [Int: CGFloat] = [:],
        direction: SectionSplit.SplitDirection,
        containerSize: CGSize,
        spacing: CGFloat = 0,
        padding: CGFloat = 0,
        showDividers: Bool = true,
        onResize: @escaping (Int, CGFloat) -> Void,
        onResizeStart: (() -> Void)? = nil,
        onResizeEnd: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Int, CGSize) -> Content
    ) {
        self.ratios = ratios
        self.sizingModes = sizingModes
        self.intrinsicSizes = intrinsicSizes
        self.direction = direction
        self.containerSize = containerSize
        self.spacing = spacing
        self.padding = padding
        self.showDividers = showDividers
        self.onResize = onResize
        self.onResizeStart = onResizeStart
        self.onResizeEnd = onResizeEnd
        self.content = content
    }

    var body: some View {
        let clampedSpacing = max(0, spacing)
        let clampedPadding = max(0, padding)
        let totalSpacing = clampedSpacing * CGFloat(max(0, ratios.count - 1))
        let availablePrimary = max(0,
            (direction == .horizontal ? containerSize.width : containerSize.height) -
            (clampedPadding * 2) -
            totalSpacing
        )
        let sizes = FlexibleSizeCalculator.calculateSizes(
            totalSize: availablePrimary,
            count: ratios.count,
            ratios: ratios,
            sizingModes: sizingModes,
            intrinsicSizes: intrinsicSizes
        )
        let secondarySize = direction == .horizontal
            ? max(0, containerSize.height - clampedPadding * 2)
            : max(0, containerSize.width - clampedPadding * 2)
        
        ZStack {
            // Main content layout
            if direction == .horizontal {
                HStack(spacing: clampedSpacing) {
                    ForEach(0..<ratios.count, id: \.self) { index in
                        let childWidth = sizes[index]
                        let childSize = CGSize(width: childWidth, height: secondarySize)
                        content(index, childSize)
                            .frame(width: childWidth, height: secondarySize)
                            .animation(.easeInOut(duration: 0.2), value: ratios[index])
                    }
                }
            } else {
                VStack(spacing: clampedSpacing) {
                    ForEach(0..<ratios.count, id: \.self) { index in
                        let childHeight = sizes[index]
                        let childSize = CGSize(width: secondarySize, height: childHeight)
                        content(index, childSize)
                            .frame(width: secondarySize, height: childHeight)
                            .animation(.easeInOut(duration: 0.2), value: ratios[index])
                    }
                }
            }
            
            // Overlay dividers
            if direction == .horizontal {
                HStack(spacing: clampedSpacing) {
                    ForEach(0..<ratios.count, id: \.self) { index in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: sizes[index], height: secondarySize)
                            .allowsHitTesting(false)
                            .overlay(alignment: .trailing) {
                                if index < ratios.count - 1 {
                                    ResizableDivider(
                                        direction: .horizontal,
                                        onResize: { delta in
                                            onResize(index, delta)
                                        },
                                        onResizeStart: onResizeStart,
                                        onResizeEnd: onResizeEnd,
                                        isVisible: showDividers
                                    )

                                }
                            }
                    }
                }
            } else {
                VStack(spacing: clampedSpacing) {
                    ForEach(0..<ratios.count, id: \.self) { index in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: secondarySize, height: sizes[index])
                            .allowsHitTesting(false)
                            .overlay(alignment: .bottom) {
                                if index < ratios.count - 1 {
                                    ResizableDivider(
                                        direction: .vertical,
                                        onResize: { delta in
                                            onResize(index, delta)
                                        },
                                        onResizeStart: onResizeStart,
                                        onResizeEnd: onResizeEnd,
                                        isVisible: showDividers
                                    )

                                }
                            }
                    }
                }
            }
        }
        .padding(clampedPadding)
        .frame(width: containerSize.width, height: containerSize.height, alignment: .center)
    }
}

// MARK: - Preview

#Preview("RatioBasedLayout - Horizontal") {
    RatioBasedLayout(
        ratios: [0.3, 0.4, 0.3],
        sizingModes: [.fixed, .fixed, .fixed],
        direction: .horizontal,
        containerSize: CGSize(width: 400, height: 200),
        spacing: 8,
        padding: 16,
        showDividers: true,
        onResize: { _, _ in }
    ) { index, size in
        RoundedRectangle(cornerRadius: 8)
            .fill([Color.blue, Color.green, Color.orange][index].opacity(0.3))
            .overlay(Text("Panel \(index + 1)"))
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("RatioBasedLayout - Vertical") {
    RatioBasedLayout(
        ratios: [0.25, 0.5, 0.25],
        sizingModes: [.fixed, .fixed, .fixed],
        direction: .vertical,
        containerSize: CGSize(width: 300, height: 400),
        spacing: 8,
        padding: 16,
        showDividers: true,
        onResize: { _, _ in }
    ) { index, size in
        RoundedRectangle(cornerRadius: 8)
            .fill([Color.purple, Color.teal, Color.pink][index].opacity(0.3))
            .overlay(Text("Row \(index + 1)"))
    }
    .background(Color.gray.opacity(0.1))
}
