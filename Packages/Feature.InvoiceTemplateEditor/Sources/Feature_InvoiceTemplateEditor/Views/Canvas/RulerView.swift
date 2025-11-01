import SwiftUI

struct RulerView: View {
    let orientation: RulerOrientation
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
    
    private let rulerHeight: CGFloat = 20
    private let majorTickHeight: CGFloat = 12
    private let minorTickHeight: CGFloat = 6
    private let textOffset: CGFloat = 2
    
    var body: some View {
        ZStack {
            // Ruler background (darker than control background, lighter than black)
            Rectangle()
                .fill(Color.elevatedSurface)
                .overlay(
                    Rectangle()
                        .stroke(Color.primaryOutline, lineWidth: 0.5)
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
        ZStack {
            ForEach(tickMarks, id: \.position) { tick in
                Group {
                    // Tick line
                    Rectangle()
                        .fill(Color.primaryText)
                        .frame(
                            width: orientation == .horizontal ? 0.5 : tick.height,
                            height: orientation == .horizontal ? tick.height : 0.5
                        )
                        .position(tickPosition(for: tick))
                    
                    // Tick label
                    if tick.showLabel {
                        Text(tick.label)
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundColor(Color.secondaryText)
                            .position(labelPosition(for: tick))
                    }
                }
            }
        }
    }
    
    private var tickMarks: [TickMark] {
        var marks: [TickMark] = []
        let totalPoints = max(0, length) // Ensure positive length
        
        // Early return if length is too small to show meaningful rulers
        guard totalPoints > 0 else { return marks }
        
        let pixelsPerUnit = unit.pixelsPerUnit * zoom
        
        // Calculate the step size based on zoom level
        let baseStep = unit.baseStep
        let step = calculateOptimalStep(baseStep: baseStep, pixelsPerUnit: pixelsPerUnit)
        
        // Calculate the starting value based on zero offset
        // We want to show negative values before the zero point
        let startValue = -(zeroOffset / pixelsPerUnit)
        let endValue = ((totalPoints - zeroOffset - scrollOffset) / pixelsPerUnit)
        
        // Start from a nice round number before startValue
        var currentValue = floor(startValue / step) * step
        
        while currentValue <= endValue {
            let position = zeroOffset + scrollOffset + (currentValue * pixelsPerUnit)
            
            // Only draw ticks that are within the ruler bounds
            if position >= 0 && position <= totalPoints {
                let isMajor = currentValue.truncatingRemainder(dividingBy: step * 5) == 0
                let showLabel = isMajor
                
                marks.append(TickMark(
                    position: position,
                    value: currentValue,
                    height: isMajor ? majorTickHeight : minorTickHeight,
                    showLabel: showLabel,
                    label: formatValue(currentValue),
                    isMajor: isMajor
                ))
            }
            
            currentValue += step
        }
        
        return marks
    }
    
    private func calculateOptimalStep(baseStep: CGFloat, pixelsPerUnit: CGFloat) -> CGFloat {
        let minPixelsBetweenTicks: CGFloat = 8
        var step = baseStep
        
        while step * pixelsPerUnit < minPixelsBetweenTicks {
            step *= 2
        }
        
        while step * pixelsPerUnit > minPixelsBetweenTicks * 4 {
            step /= 2
        }
        
        return max(step, baseStep)
    }
    
    private func tickPosition(for tick: TickMark) -> CGPoint {
        switch orientation {
        case .horizontal:
            return CGPoint(
                x: tick.position,
                y: rulerHeight - tick.height / 2
            )
        case .vertical:
            return CGPoint(
                x: rulerHeight - tick.height / 2,
                y: tick.position
            )
        }
    }
    
    private func labelPosition(for tick: TickMark) -> CGPoint {
        switch orientation {
        case .horizontal:
            return CGPoint(
                x: tick.position,
                y: textOffset + 4
            )
        case .vertical:
            return CGPoint(
                x: textOffset + 6,
                y: tick.position
            )
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

private struct TickMark {
    let position: CGFloat
    let value: CGFloat
    let height: CGFloat
    let showLabel: Bool
    let label: String
    let isMajor: Bool
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Horizontal ruler
        RulerView(
            orientation: .horizontal,
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
