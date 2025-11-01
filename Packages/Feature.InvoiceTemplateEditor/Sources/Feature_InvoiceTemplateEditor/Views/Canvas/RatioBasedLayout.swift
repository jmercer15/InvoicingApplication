//
//  RatioBasedLayout.swift
//  Feature.InvoiceTemplateEditor
//
//  Layout container that distributes space based on ratios
//

import SwiftUI

struct RatioBasedLayout<Content: View>: View {
    let ratios: [CGFloat]
    let direction: SectionSplit.SplitDirection
    let containerSize: CGSize
    let content: (Int, CGSize) -> Content
    let onResize: (Int, CGFloat) -> Void

    init(ratios: [CGFloat], direction: SectionSplit.SplitDirection, containerSize: CGSize, onResize: @escaping (Int, CGFloat) -> Void, @ViewBuilder content: @escaping (Int, CGSize) -> Content) {
        self.ratios = ratios
        self.direction = direction
        self.containerSize = containerSize
        self.onResize = onResize
        self.content = content
    }

    var body: some View {
        ZStack {
            // Main content layout
            if direction == .horizontal {
                HStack(spacing: 0) {
                    ForEach(0..<ratios.count, id: \.self) { index in
                        content(index, containerSize)
                            .frame(width: containerSize.width * ratios[index])
                            .animation(.easeInOut(duration: 0.2), value: ratios[index])
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(0..<ratios.count, id: \.self) { index in
                        content(index, containerSize)
                            .frame(height: containerSize.height * ratios[index])
                            .animation(.easeInOut(duration: 0.2), value: ratios[index])
                    }
                }
            }
            
            // Overlay dividers using alignment
            if direction == .horizontal {
                HStack(spacing: 0) {
                    ForEach(0..<ratios.count, id: \.self) { index in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: containerSize.width * ratios[index])
                            .overlay(alignment: .trailing) {
                                if index < ratios.count - 1 {
                                    ResizableDivider(
                                        direction: .horizontal,
                                        onResize: { delta in
                                            onResize(index, delta)
                                        }
                                    )
                                }
                            }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(0..<ratios.count, id: \.self) { index in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: containerSize.height * ratios[index])
                            .overlay(alignment: .bottom) {
                                if index < ratios.count - 1 {
                                    ResizableDivider(
                                        direction: .vertical,
                                        onResize: { delta in
                                            onResize(index, delta)
                                        }
                                    )
                                }
                            }
                    }
                }
            }
        }
    }
}

