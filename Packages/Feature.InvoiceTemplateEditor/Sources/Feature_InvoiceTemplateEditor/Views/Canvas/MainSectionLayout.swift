//
//  MainSectionLayout.swift
//  Feature.InvoiceTemplateEditor
//
//  Layout for the main 5 canvas sections with resizable dividers
//

import SwiftUI

struct MainSectionLayout<Content: View>: View {
    let heightRatios: [CGFloat]
    let containerHeight: CGFloat
    let onResize: (Int, CGFloat) -> Void
    let content: (Int) -> Content

    init(heightRatios: [CGFloat], containerHeight: CGFloat, onResize: @escaping (Int, CGFloat) -> Void, @ViewBuilder content: @escaping (Int) -> Content) {
        self.heightRatios = heightRatios
        self.containerHeight = containerHeight
        self.onResize = onResize
        self.content = content
    }

    var body: some View {
        ZStack {
            // Main content layout
            VStack(spacing: 0) {
                ForEach(0..<heightRatios.count, id: \.self) { index in
                    content(index)
                        .frame(height: containerHeight * heightRatios[index])
                        .animation(.easeInOut(duration: 0.2), value: heightRatios[index])
                }
            }
            
            // Overlay dividers using alignment
            VStack(spacing: 0) {
                ForEach(0..<heightRatios.count, id: \.self) { index in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: containerHeight * heightRatios[index])
                        .overlay(alignment: .bottom) {
                            if index < heightRatios.count - 1 {
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

