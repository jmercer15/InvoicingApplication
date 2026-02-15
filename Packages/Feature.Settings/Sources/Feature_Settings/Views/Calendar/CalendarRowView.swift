import SwiftUI
import EventKit
import Data
import Core
import SharedUI

// MARK: - Calendar Row View with Color Picker

struct CalendarRowView: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    let onColorChange: (Color) -> Void
    let currentColor: Color
    
    @State private var showingColorPicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: {
                onToggle(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .white.opacity(0.6))
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            
            // Calendar name
            Text(calendar.title)
                .font(.subheadline)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Color picker button
            Button(action: {
                showingColorPicker.toggle()
            }) {
                Circle()
                    .fill(currentColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .contentShape(Circle())
            .buttonStyle(.plain)
            .popover(isPresented: $showingColorPicker) {
                VStack(spacing: 16) {
                    Text("Calendar Color")
                        .font(.headline)
                        .padding(.top)
                    
                    ColorPicker("", selection: Binding(
                        get: { currentColor },
                        set: { onColorChange($0) }
                    ))
                    .labelsHidden()
                    .frame(width: 200, height: 200)
                    
                    Button("Reset to Default") {
                        onColorChange(Color(calendar.cgColor))
                        showingColorPicker = false
                    }
                    .buttonStyle(.glass)
                    
                    Spacer()
                }
                .frame(width: 250, height: 300)
                .padding()
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(!isSelected)
        }
    }
}
