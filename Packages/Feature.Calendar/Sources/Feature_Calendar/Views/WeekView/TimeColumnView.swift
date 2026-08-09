import SwiftUI
import SharedUI
import Observation

// ─────────────────────────────────────────────────────────────
// MARK: - Time Labels Column View
// ─────────────────────────────────────────────────────────────

struct TimeColumnView: View {
    @Bindable var viewModel: CalendarViewModel
    let width: CGFloat
    let effectiveHourHeight: CGFloat

    @ScaledMetric(relativeTo: .body) private var textFontSize: CGFloat = StyleGuide.Dimensions.fontSizeXSmall + 1
    @ScaledMetric(relativeTo: .body) private var rightPadding: CGFloat = StyleGuide.Dimensions.paddingMedium

    private let hours = Array(0...23)

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = effectiveHourHeight
            
            for hour in 0..<24 {
                let isMajor = hour % 3 == 0
                let textStr = formattedTimeLabel(hour: hour)
                
                // Note: Canvas resolves SwiftUI Text
                let text = Text(textStr)
                    .font(CalendarTypography.timeLabel(size: textFontSize, isMajor: isMajor))
                    .foregroundStyle(isMajor ? StyleGuide.Colors.text : StyleGuide.Colors.textSecondary)
                
                let resolved = context.resolve(text)
                let textSize = resolved.measure(in: CGSize(width: w - rightPadding, height: h))
                
                let y = CGFloat(hour) * h
                let yOffset = hour == 0 ? -(h / 2) + 6 : -(h / 2)
                
                // Draw trailing aligned, vertically centered in the virtual hour block
                let drawX = w - rightPadding - textSize.width
                let drawY = y + yOffset + (h - textSize.height) / 2
                
                context.draw(resolved, at: CGPoint(x: drawX + textSize.width / 2, y: drawY + textSize.height / 2), anchor: .center)
            }
            
            // Draw trailing border line
            var borderPath = Path()
            borderPath.move(to: CGPoint(x: w - 0.5, y: 0))
            borderPath.addLine(to: CGPoint(x: w - 0.5, y: 24 * h))
            context.stroke(
                borderPath,
                with: .color(StyleGuide.Colors.border.opacity(0.2)),
                lineWidth: 0.5
            )
            
        }
        .frame(width: width, height: CGFloat(hours.count) * effectiveHourHeight)
        .clipped()
    }

    private static let timeLabels: [Int: String] = {
        var labels: [Int: String] = [:]
        for hour in 0...23 {
            labels[hour] = DateFormatting.hourMeridiemLabel(forHour: hour)
        }
        return labels
    }()

    private func formattedTimeLabel(hour: Int) -> String {
        Self.timeLabels[hour] ?? "\(hour)"
    }
} 
