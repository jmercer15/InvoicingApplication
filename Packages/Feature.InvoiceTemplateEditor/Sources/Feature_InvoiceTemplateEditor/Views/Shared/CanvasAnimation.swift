//
//  CanvasAnimation.swift
//  Feature.InvoiceTemplateEditor
//
//  Centralized animation constants for Canvas UI interactions
//

import SwiftUI

enum CanvasAnimation {
    // Durations
    static let quick = Animation.easeOut(duration: 0.12)
    static let standard = Animation.easeInOut(duration: 0.20)
    static let deliberate = Animation.easeInOut(duration: 0.30)
    
    // Springs
    static let hoverSpring = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let selectionSpring = Animation.spring(response: 0.30, dampingFraction: 0.7)
    static let bouncy = Animation.spring(response: 0.50, dampingFraction: 0.6)
}

// MARK: - Preview

#Preview("CanvasAnimation - Presets") {
    struct AnimationDemo: View {
        @State private var quickOffset: CGFloat = 0
        @State private var standardOffset: CGFloat = 0
        @State private var deliberateOffset: CGFloat = 0
        @State private var hoverOffset: CGFloat = 0
        @State private var selectionOffset: CGFloat = 0
        @State private var bouncyOffset: CGFloat = 0
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Tap to animate").font(.headline)
                
                // Quick
                HStack {
                    Text("Quick")
                        .frame(width: 80, alignment: .leading)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                        .offset(x: quickOffset)
                }
                
                // Standard
                HStack {
                    Text("Standard")
                        .frame(width: 80, alignment: .leading)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: 30, height: 30)
                        .offset(x: standardOffset)
                }
                
                // Deliberate
                HStack {
                    Text("Deliberate")
                        .frame(width: 80, alignment: .leading)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: 30, height: 30)
                        .offset(x: deliberateOffset)
                }
                
                // Springs
                Divider()
                Text("Springs").font(.subheadline)
                
                HStack {
                    Text("Hover")
                        .frame(width: 80, alignment: .leading)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple)
                        .frame(width: 30, height: 30)
                        .offset(x: hoverOffset)
                }
                
                HStack {
                    Text("Selection")
                        .frame(width: 80, alignment: .leading)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.pink)
                        .frame(width: 30, height: 30)
                        .offset(x: selectionOffset)
                }
                
                HStack {
                    Text("Bouncy")
                        .frame(width: 80, alignment: .leading)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 30, height: 30)
                        .offset(x: bouncyOffset)
                }
                
                Button("Animate All") {
                    withAnimation(CanvasAnimation.quick) { quickOffset = quickOffset == 0 ? 100 : 0 }
                    withAnimation(CanvasAnimation.standard) { standardOffset = standardOffset == 0 ? 100 : 0 }
                    withAnimation(CanvasAnimation.deliberate) { deliberateOffset = deliberateOffset == 0 ? 100 : 0 }
                    withAnimation(CanvasAnimation.hoverSpring) { hoverOffset = hoverOffset == 0 ? 100 : 0 }
                    withAnimation(CanvasAnimation.selectionSpring) { selectionOffset = selectionOffset == 0 ? 100 : 0 }
                    withAnimation(CanvasAnimation.bouncy) { bouncyOffset = bouncyOffset == 0 ? 100 : 0 }
                }
            }
            .padding()
            .frame(width: 250)
        }
    }
    return AnimationDemo()
}
