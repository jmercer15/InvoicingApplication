import SwiftUI

struct RulerView: View {
    let orientation: RulerOrientation
    let edge: RulerEdge
    let length: CGFloat
    let unit: RulerUnit
    let cursorPosition: CGFloat?
    let showCursorIndicator: Bool
    let zeroOffset: CGFloat // Offset from the left/top edge to where "0" should be
    let selectionStart: CGFloat?
    let selectionEnd: CGFloat?
    // Optional margin indicators (positions in page coordinates)
    let marginStart: CGFloat?
    let marginEnd: CGFloat?
    // Ruler zoom is provided externally to match document zoom
    let zoom: CGFloat
    let scrollOffset: CGFloat
    
    private let rulerHeight: CGFloat = 30
    private let majorTickHeight: CGFloat = 8
    private let minorTickHeight: CGFloat = 3
    private let textOffset: CGFloat = 4
    
    var body: some View {
        ZStack {
            // Ruler background (darker than control background, lighter than black)
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                .overlay(
                    Rectangle()
                        .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
                )
            
            // Selection range indicator
            if let start = selectionStart, let end = selectionEnd {
                selectionIndicator(from: start, to: end)
            }

            // Margin indicators
            if let mStart = marginStart {
                marginIndicator(at: mStart)
            }
            if let mEnd = marginEnd {
                marginIndicator(at: mEnd)
            }
            
            // Ruler markings
            rulerMarkings
            
            // Cursor indicator
            if showCursorIndicator, let position = cursorPosition {
                cursorIndicator(at: position)
            }
        }
        .frame(
            width: orientation == .horizontal ? max(0, length) : rulerHeight,
            height: orientation == .horizontal ? rulerHeight : max(0, length)
        )
    }
    
    private var rulerMarkings: some View {
        Canvas { context, size in
            let totalPoints = max(0, length)
            guard totalPoints > 0 else { return }
            
            let pixelsPerUnit = unit.pixelsPerUnit * zoom
            let step = calculateOptimalStep(pixelsPerUnit: pixelsPerUnit)
            
            let startValue = -(zeroOffset / pixelsPerUnit)
            let endValue = ((totalPoints - zeroOffset - scrollOffset) / pixelsPerUnit)
            
            // Align start value to the step
            var currentValue = floor(startValue / step) * step
            
            while currentValue <= endValue {
                let position = zeroOffset + scrollOffset + (currentValue * pixelsPerUnit)
                
                if position >= -20 && position <= totalPoints + 20 { // Draw slightly off-screen to avoid pop-in
                    let isMajor = isMajorTick(value: currentValue, step: step)
                    let tickHeight = isMajor ? majorTickHeight : minorTickHeight
                    
                    // Draw tick
                    let tickRect: CGRect
                    switch edge {
                    case .top:
                        tickRect = CGRect(x: position, y: rulerHeight - tickHeight, width: 0.5, height: tickHeight)
                    case .bottom:
                        tickRect = CGRect(x: position, y: 0, width: 0.5, height: tickHeight)
                    case .leading:
                        tickRect = CGRect(x: rulerHeight - tickHeight, y: position, width: tickHeight, height: 0.5)
                    case .trailing:
                        tickRect = CGRect(x: 0, y: position, width: tickHeight, height: 0.5)
                    }
                    context.fill(Path(tickRect), with: .color(Color.primaryText))
                    
                    // Draw label
                    if isMajor {
                        let text = Text(formatValue(currentValue))
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.secondaryText)
                        
                        let resolvedText = context.resolve(text)
                        
                        switch edge {
                        case .top:
                            context.draw(resolvedText, at: CGPoint(x: position + 2, y: 4), anchor: .topLeading)
                        case .bottom:
                            context.draw(resolvedText, at: CGPoint(x: position + 2, y: rulerHeight - 4), anchor: .bottomLeading)
                        case .leading:
                            context.draw(resolvedText, at: CGPoint(x: rulerHeight - majorTickHeight - 4, y: position), anchor: .trailing)
                        case .trailing:
                            context.draw(resolvedText, at: CGPoint(x: majorTickHeight + 4, y: position), anchor: .leading)
                        }
                    }
                }
                currentValue += step
            }
        }
    }
    
    private func calculateOptimalStep(pixelsPerUnit: CGFloat) -> CGFloat {
        let minPixelsBetweenTicks: CGFloat = 8
        
        // Standard steps for metric/points: 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000...
        // Standard steps for inches: 1/16, 1/8, 1/4, 1/2, 1, 2, 5, 10...
        
        if unit == .inches {
            let steps: [CGFloat] = [0.0625, 0.125, 0.25, 0.5, 1, 2, 5, 10]
            for step in steps {
                if step * pixelsPerUnit >= minPixelsBetweenTicks {
                    return step
                }
            }
            return 10
        } else {
            var step: CGFloat = 1
            while step * pixelsPerUnit < minPixelsBetweenTicks {
                if step * pixelsPerUnit >= minPixelsBetweenTicks { break }
                step *= 2
                if step * pixelsPerUnit >= minPixelsBetweenTicks { break }
                step *= 2.5 // 1 -> 2 -> 5
                if step * pixelsPerUnit >= minPixelsBetweenTicks { break }
                step *= 2 // 5 -> 10
            }
            return step
        }
    }
    
    private func isMajorTick(value: CGFloat, step: CGFloat) -> Bool {
        let epsilon: CGFloat = 0.0001
        
        switch unit {
        case .inches:
            // Major ticks at whole inches, or significant fractions if zoomed in
            if step >= 1 {
                return abs(value.truncatingRemainder(dividingBy: step * 5)) < epsilon // e.g. 0, 5, 10
            } else if step >= 0.5 {
                return abs(value.truncatingRemainder(dividingBy: 1)) < epsilon // Whole inches
            } else {
                return abs(value.truncatingRemainder(dividingBy: 0.5)) < epsilon // Half inches
            }
        case .points, .millimeters:
             // Major ticks logic:
             // If step is 1, major every 10
             // If step is 2, major every 10
             // If step is 5, major every 10? No, every 50?
             // If step is 10, major every 50 or 100
             
             if step <= 2 {
                 return abs(value.truncatingRemainder(dividingBy: 10)) < epsilon
             } else if step <= 5 {
                 return abs(value.truncatingRemainder(dividingBy: 50)) < epsilon
             } else if step <= 10 {
                 return abs(value.truncatingRemainder(dividingBy: 50)) < epsilon
             } else if step <= 20 {
                 return abs(value.truncatingRemainder(dividingBy: 100)) < epsilon
             } else {
                 return abs(value.truncatingRemainder(dividingBy: step * 5)) < epsilon
             }
        }
    }
    

    
    private func formatValue(_ value: CGFloat) -> String {
        switch unit {
        case .points:
            return "\(Int(value))"
        case .millimeters:
            return String(format: "%.0f", value)
        case .inches:
            return String(format: "%.1f", value)
        }
    }
    
    private func selectionIndicator(from start: CGFloat, to end: CGFloat) -> some View {
        let adjustedStart = zeroOffset + scrollOffset + start
        let adjustedEnd = zeroOffset + scrollOffset + end
        let origin = min(adjustedStart, adjustedEnd)
        let size = abs(adjustedEnd - adjustedStart)
        
        return Rectangle()
            .fill(Color.accentColor.opacity(0.2))
            .frame(
                width: orientation == .horizontal ? size : rulerHeight,
                height: orientation == .horizontal ? rulerHeight : size
            )
            .position(
                x: orientation == .horizontal ? origin + size / 2 : rulerHeight / 2,
                y: orientation == .horizontal ? rulerHeight / 2 : origin + size / 2
            )
    }
    
    private func cursorIndicator(at position: CGFloat) -> some View {
        let adjustedPosition = zeroOffset + scrollOffset + position
        
        return Group {
            // Only show if the adjusted position is within the ruler bounds
            if adjustedPosition >= 0 && adjustedPosition <= length {
                // Cursor line
                Rectangle()
                    .fill(Color.warningColor.opacity(0.8))
                    .frame(
                        width: orientation == .horizontal ? 1 : rulerHeight,
                        height: orientation == .horizontal ? rulerHeight : 1
                    )
                    .position(
                        x: orientation == .horizontal ? adjustedPosition : rulerHeight / 2,
                        y: orientation == .horizontal ? rulerHeight / 2 : adjustedPosition
                    )
                
                // Cursor triangle indicator
                Path { path in
                    switch orientation {
                    case .horizontal:
                        path.move(to: CGPoint(x: adjustedPosition - 4, y: 0))
                        path.addLine(to: CGPoint(x: adjustedPosition + 4, y: 0))
                        path.addLine(to: CGPoint(x: adjustedPosition, y: 6))
                        path.closeSubpath()
                    case .vertical:
                        path.move(to: CGPoint(x: 0, y: adjustedPosition - 4))
                        path.addLine(to: CGPoint(x: 0, y: adjustedPosition + 4))
                        path.addLine(to: CGPoint(x: 6, y: adjustedPosition))
                        path.closeSubpath()
                    }
                }
                .fill(Color.warningColor)
            }
        }
    }

    private func marginIndicator(at position: CGFloat) -> some View {
        let adjustedPosition = zeroOffset + scrollOffset + (position * zoom)

        return Group {
            let isClampedToStart = adjustedPosition < 0
            let isClampedToEnd = adjustedPosition > length
            let clampedPosition = min(length, max(0, adjustedPosition))

            // Draw the indicator line, slightly faded if it's clamped
            Path { path in
                path.move(to: CGPoint(x: orientation == .horizontal ? clampedPosition : rulerHeight - 5, y: orientation == .horizontal ? rulerHeight - 5 : clampedPosition))
                path.addLine(to: CGPoint(x: orientation == .horizontal ? clampedPosition : rulerHeight, y: orientation == .horizontal ? rulerHeight : clampedPosition))
            }
            .stroke(Color.accentColor.opacity(isClampedToStart || isClampedToEnd ? 0.5 : 1.0), lineWidth: 1)

            // Draw triangles for off-screen indicators pointing outwards
            if isClampedToStart {
                Path { path in
                    if orientation == .horizontal {
                        path.move(to: CGPoint(x: clampedPosition + 5, y: rulerHeight - 7.5))
                        path.addLine(to: CGPoint(x: clampedPosition, y: rulerHeight - 5))
                        path.addLine(to: CGPoint(x: clampedPosition + 5, y: rulerHeight - 2.5))
                    } else { // Vertical
                        path.move(to: CGPoint(x: rulerHeight - 7.5, y: clampedPosition + 5))
                        path.addLine(to: CGPoint(x: rulerHeight - 5, y: clampedPosition))
                        path.addLine(to: CGPoint(x: rulerHeight - 2.5, y: clampedPosition + 5))
                    }
                }
                .fill(Color.accentColor.opacity(0.5))
            }

            if isClampedToEnd {
                Path { path in
                    if orientation == .horizontal {
                        path.move(to: CGPoint(x: clampedPosition - 5, y: rulerHeight - 7.5))
                        path.addLine(to: CGPoint(x: clampedPosition, y: rulerHeight - 5))
                        path.addLine(to: CGPoint(x: clampedPosition - 5, y: rulerHeight - 2.5))
                    } else { // Vertical
                        path.move(to: CGPoint(x: rulerHeight - 7.5, y: clampedPosition - 5))
                        path.addLine(to: CGPoint(x: rulerHeight - 5, y: clampedPosition))
                        path.addLine(to: CGPoint(x: rulerHeight - 2.5, y: clampedPosition - 5))
                    }
                }
                .fill(Color.accentColor.opacity(0.5))
            }
        }
    }
}

// MARK: - Supporting Types

enum RulerOrientation {
    case horizontal
    case vertical
}

enum RulerEdge {
    case top
    case bottom
    case leading
    case trailing
}

enum RulerUnit {
    case points
    case millimeters
    case inches
    
    var pixelsPerUnit: CGFloat {
        switch self {
        case .points:
            return 1.0 // 1 point = 1 pixel at 72 DPI
        case .millimeters:
            return 2.83465 // 1 mm = ~2.83 points at 72 DPI
        case .inches:
            return 72.0 // 1 inch = 72 points
        }
    }
    
    var baseStep: CGFloat {
        switch self {
        case .points:
            return 10 // 10 point increments
        case .millimeters:
            return 10 // 10 mm increments
        case .inches:
            return 0.25 // 1/4 inch increments
        }
    }
}



// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Horizontal ruler
        RulerView(
            orientation: .horizontal,
            edge: .top,
            length: 400,
            unit: .points,
            cursorPosition: 150,
            showCursorIndicator: true,
            zeroOffset: 100,
            selectionStart: 50,
            selectionEnd: 250,
            marginStart: nil,
            marginEnd: nil,
            zoom: 1.0,
            scrollOffset: 0
        )
        
        // Vertical ruler
        HStack(spacing: 20) {
            RulerView(
                orientation: .vertical,
                edge: .leading,
                length: 300,
                unit: .points,
                cursorPosition: 100,
                showCursorIndicator: true,
                zeroOffset: 50,
                selectionStart: 20,
                selectionEnd: 180,
                marginStart: nil,
                marginEnd: nil,
                zoom: 1.0,
                scrollOffset: 0
            )
            
            Rectangle()
                .fill(Color.elevatedSurface)
                .frame(width: 200, height: 300)
        }
    }
    .padding()
}
