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
                        .font(.caption)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(selectedDays.contains(day) ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

            }
        }
        .padding(8)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Ordinal Picker View
struct OrdinalPickerView: View {
    @Binding var ordinalSelection: OrdinalSelection?
    @Binding var dayOfWeekSelection: DayOfWeekOption?
    
    var body: some View {
        HStack(spacing: 8) {
            Picker("Ordinal", selection: $ordinalSelection) {
                Text("Select...").tag(nil as OrdinalSelection?)
                ForEach(OrdinalSelection.allCases, id: \.self) { ordinal in
                    Text(ordinal.displayName).tag(ordinal as OrdinalSelection?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 100)
            
            Text("of")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            
            Picker("Day of Week", selection: $dayOfWeekSelection) {
                Text("Select...").tag(nil as DayOfWeekOption?)
                ForEach(
                    DayOfWeekOption.allCases.filter { $0.rawValue >= DayOfWeekOption.sunday.rawValue },
                    id: \.self
                ) { dayOption in
                    Text(dayOption.displayName).tag(dayOption as DayOfWeekOption?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 120)
        }
    }
}
