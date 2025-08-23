//
//  CustomSplitView.swift
//  InvoicingApplication
//
//  Created by Gemini on 24/3/2025.
//
//  This code is adapted from the open-source SplitView project by Steven Harris.
//  Original source: https://github.com/stevengharris/SplitView
//  The code has been modified to fit the specific needs of this application.
//

import SwiftUI

// MARK: - Splitter View
struct Splitter: View {
    @State private var isHovering: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Main background for the splitter area
                Color.black
                    .allowsHitTesting(false)

                // Extending top line
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 0.5, height: isHovering ? ((geo.size.height / 2) - 50) : 0)
                    .offset(y: isHovering ? -(25 + geo.size.height / 4) : -50)
                    .animation(.easeInOut(duration: 0.3), value: isHovering)
                    .allowsHitTesting(false)

                // Extending bottom line
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 0.5, height: isHovering ? ((geo.size.height / 2) - 50) : 0)
                    .offset(y: isHovering ? (25 + geo.size.height / 4) : 50)
                    .animation(.easeInOut(duration: 0.3), value: isHovering)
                    .allowsHitTesting(false)

                // Center handle block
                Rectangle()
                    .fill(isHovering ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(height: 100)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isHovering ? Color.gray : Color.clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .appSplitterCursor()

                // Three dots indicator
                VStack(spacing: isHovering ? 20 : 6) {
                    Circle()
                        .fill(isHovering ? Color.white : Color.gray)
                        .frame(width: 4, height: 4)
                    Circle()
                        .fill(isHovering ? Color.white : Color.gray)
                        .frame(width: 4, height: 4)
                    Circle()
                        .fill(isHovering ? Color.white : Color.gray)
                        .frame(width: 4, height: 4)
                }
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.isHovering = hovering
                }
            }
        }
    }
}

// MARK: - Custom HSplitView
struct CustomHSplitView<Primary: View, Secondary: View, Splitter: View>: View {
    @State private var drag: DragGesture.Value?
    @State private var fraction: CGFloat
    @State private var lastNonCollapsedFraction: CGFloat
    @Binding private var isPrimaryVisible: Bool
    
    private let primary: Primary
    private let secondary: Secondary
    private let splitter: (GeometryProxy) -> Splitter
    private let minPFraction: CGFloat
    private let minSFraction: CGFloat
    private let maxPFraction: CGFloat?
    
    init(
        fraction: CGFloat = 0.5,
        minPFraction: CGFloat = 0.2,
        minSFraction: CGFloat = 0.2,
        maxPFraction: CGFloat? = nil,
        isPrimaryVisible: Binding<Bool> = .constant(true),
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary,
        @ViewBuilder splitter: @escaping (GeometryProxy) -> Splitter
    ) {
        _fraction = State(initialValue: fraction)
        _lastNonCollapsedFraction = State(initialValue: fraction)
        self.minPFraction = minPFraction
        self.minSFraction = minSFraction
        self.maxPFraction = maxPFraction
        self._isPrimaryVisible = isPrimaryVisible
        self.primary = primary()
        self.secondary = secondary()
        self.splitter = splitter
    }

    var body: some View {
        GeometryReader { geometry in
            let constrainedFraction = min(max(fraction, minPFraction), 1 - minSFraction)
            let clampedFraction = maxPFraction.map { min(constrainedFraction, $0) } ?? constrainedFraction
            let finalFraction = isPrimaryVisible ? clampedFraction : 0
            
            let splitterPosition = geometry.size.width * finalFraction
            
            HStack(spacing: 0) {
                primary
                    .frame(width: splitterPosition)
                    .clipped()
                    
                
                splitter(geometry)
                    .frame(width: isPrimaryVisible ? 8 : 0)
                    .opacity(isPrimaryVisible ? 1 : 0)
                    .contentShape(Rectangle())
                    .gesture(
                        isPrimaryVisible ?
                            DragGesture(minimumDistance: 0)
                                .onChanged {
                                    self.drag = $0
                                    let newFraction = ($0.location.x - $0.startLocation.x + splitterPosition) / geometry.size.width
                                    self.fraction = newFraction
                                    self.lastNonCollapsedFraction = min(max(newFraction, minPFraction), 1 - minSFraction)
                                }
                                .onEnded { _ in
                                    self.drag = nil
                                }
                        : nil
                    )
                
                secondary
                    .frame(maxWidth: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
            .onChange(of: isPrimaryVisible) { _, newValue in
                if newValue {
                    // Expanding: restore previous width fraction
                    let target = max(min(lastNonCollapsedFraction, 1 - minSFraction), minPFraction)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.fraction = maxPFraction.map { min(target, $0) } ?? target
                    }
                } else {
                    // Collapsing: remember the current fraction for later restore
                    self.lastNonCollapsedFraction = clampedFraction
                }
            }
        }
    }
} 