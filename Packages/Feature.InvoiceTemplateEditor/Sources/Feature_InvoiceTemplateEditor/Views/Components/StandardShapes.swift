import SwiftUI

struct Triangle: Shape {
    var direction: TriangleDirection = .up

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}

struct Line: Shape {
    var startDecorator: LineDecorator = .none
    var endDecorator: LineDecorator = .none
    var thickness: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let isHorizontal = rect.width >= rect.height
        let start = isHorizontal ? CGPoint(x: rect.minX, y: rect.midY) : CGPoint(x: rect.midX, y: rect.minY)
        let end = isHorizontal ? CGPoint(x: rect.maxX, y: rect.midY) : CGPoint(x: rect.midX, y: rect.maxY)
        
        // Main line
        path.move(to: start)
        path.addLine(to: end)
        
        // Add decorators
        if startDecorator != .none {
            path.addPath(decoratorPath(at: start, from: end, type: startDecorator))
        }
        if endDecorator != .none {
            path.addPath(decoratorPath(at: end, from: start, type: endDecorator))
        }
        
        return path
    }
    
    private func decoratorPath(at point: CGPoint, from otherPoint: CGPoint, type: LineDecorator) -> Path {
        let angle = atan2(point.y - otherPoint.y, point.x - otherPoint.x)
        let size = thickness * 4 // Decorator size relative to line thickness
        var decoratorPath = Path()

        switch type {
        case .arrow:
            let angle1 = angle - .pi / 6
            let angle2 = angle + .pi / 6
            let p1 = CGPoint(x: point.x - size * cos(angle1), y: point.y - size * sin(angle1))
            let p2 = CGPoint(x: point.x - size * cos(angle2), y: point.y - size * sin(angle2))
            decoratorPath.move(to: p1)
            decoratorPath.addLine(to: point)
            decoratorPath.addLine(to: p2)
        case .circle:
            let radius = size / 2
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: size, height: size)
            decoratorPath.addEllipse(in: rect)
        case .square:
            let halfSize = size / 2
            let rect = CGRect(x: point.x - halfSize, y: point.y - halfSize, width: size, height: size)
            decoratorPath.addRect(rect)
        case .none:
            break
        }
        return decoratorPath
    }
}

struct Star: Shape {
    let points: Int
    let smoothness: CGFloat

    func path(in rect: CGRect) -> Path {
        guard points >= 2 else { return Path() }

        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * smoothness

        let angleIncrement = .pi * 2 / CGFloat(points)
        let rotationOffset = -CGFloat.pi / 2 // Start at the top

        var path = Path()

        for i in 0..<points {
            let angle = CGFloat(i) * angleIncrement * 2 + rotationOffset
            let outerPoint = CGPoint(
                x: center.x + cos(angle) * outerRadius,
                y: center.y + sin(angle) * outerRadius
            )
            let innerAngle = angle + angleIncrement
            let innerPoint = CGPoint(
                x: center.x + cos(innerAngle) * innerRadius,
                y: center.y + sin(innerAngle) * innerRadius
            )

            if i == 0 {
                path.move(to: outerPoint)
            } else {
                path.addLine(to: outerPoint)
            }
            path.addLine(to: innerPoint)
        }
        path.closeSubpath()
        return path
    }
}


struct ImagePlaceholder: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

// MARK: - Previews

#Preview("Triangle - Directions") {
    HStack(spacing: 20) {
        ForEach([TriangleDirection.up, .down, .left, .right], id: \.self) { direction in
            Triangle(direction: direction)
                .fill(Color.accentColor)
                .frame(width: 60, height: 60)
        }
    }
    .padding()
}

#Preview("Line - Decorators") {
    VStack(spacing: 20) {
        HStack(spacing: 30) {
            VStack {
                Line(startDecorator: .none, endDecorator: .arrow, thickness: 2)
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: 80, height: 20)
                Text("Arrow").font(.caption)
            }
            
            VStack {
                Line(startDecorator: .circle, endDecorator: .circle, thickness: 2)
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: 80, height: 20)
                Text("Circle").font(.caption)
            }
            
            VStack {
                Line(startDecorator: .square, endDecorator: .arrow, thickness: 2)
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: 80, height: 20)
                Text("Mixed").font(.caption)
            }
        }
    }
    .padding()
}

#Preview("Star - Variations") {
    HStack(spacing: 20) {
        Star(points: 5, smoothness: 0.5)
            .fill(Color.yellow)
            .frame(width: 60, height: 60)
        
        Star(points: 6, smoothness: 0.4)
            .fill(Color.orange)
            .frame(width: 60, height: 60)
        
        Star(points: 8, smoothness: 0.6)
            .fill(Color.red)
            .frame(width: 60, height: 60)
    }
    .padding()
}

#Preview("ImagePlaceholder") {
    ImagePlaceholder()
        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        .frame(width: 100, height: 80)
        .padding()
}
