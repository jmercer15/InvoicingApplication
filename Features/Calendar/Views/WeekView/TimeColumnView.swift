import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - Time Labels Column View
// ─────────────────────────────────────────────────────────────

struct TimeColumnView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let width: CGFloat
    let effectiveHourHeight: CGFloat

    private let hours = Array(0...23)

    var body: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hr in
                hourTimeLabel(hour: hr)
            }
        }
        .frame(width: width)
        .frame(height: CGFloat(hours.count) * effectiveHourHeight)
        .glassEffect(.regular, in: .rect())
    }

    @ViewBuilder
    private func hourTimeLabel(hour: Int) -> some View {
        HStack(spacing: 0) {
            Text(formattedTimeLabel(hour: hour))
                .font(.system(size: 11))
                .foregroundColor(hour % 3 == 0 ? .primary : .secondary)
                .fontWeight(hour % 3 == 0 ? .medium : .regular)
                .frame(width: width - 8, alignment: .trailing)
            Spacer()
        }
        .frame(height: effectiveHourHeight)
        .offset(y: hour == 0 ? -(effectiveHourHeight / 2) + 9 : -(effectiveHourHeight / 2))
    }

    private func formattedTimeLabel(hour: Int) -> String {
        var comp = DateComponents(); comp.hour = hour
        let f = DateFormatter(); f.dateFormat = "h a"
        return f.string(from: Calendar.current.date(from: comp) ?? Date())
    }
} 