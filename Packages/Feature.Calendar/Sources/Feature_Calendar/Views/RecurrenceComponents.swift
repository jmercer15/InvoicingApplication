import SwiftUI
import SharedUI

// MARK: - Month Day Grid View
struct MonthDayGridView: View {
    @Binding var selectedDays: Set<Int>
    
    private let daysInMonth = Array(1...31)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(daysInMonth, id: \.self) { day in
                Button(action: {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }) {
                    Text("\(day)")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .frame(width: StyleGuide.Dimensions.entityListIconWidth, height: StyleGuide.Dimensions.entityListIconWidth)
                        .background(
                            Circle()
                                .fill(selectedDays.contains(day) ? Color.accentColor : Color.clear)
                        )
                        .foregroundStyle(selectedDays.contains(day) ? Color.white : Color.primary)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

            }
        }
        .padding(StyleGuide.Dimensions.paddingMedium)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
    }
}

