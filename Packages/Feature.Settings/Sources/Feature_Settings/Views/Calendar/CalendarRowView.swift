import SwiftUI
import EventKit
import SharedUI

// MARK: - Calendar Row View with Color Picker

struct CalendarRowView: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    let onColorChange: (Color) -> Void
    let currentColor: Color
    
    @State private var showingColorPicker = false
    
    @ScaledMetric(relativeTo: .body) private var paddingMediumLarge = StyleGuide.Dimensions.paddingMediumLarge
    @ScaledMetric(relativeTo: .body) private var paddingSmall = StyleGuide.Dimensions.paddingSmall
    
    var body: some View {
        HStack(spacing: FormSectionTokens.sectionStackSpacing) {
            Button(action: {
                onToggle(!isSelected)
            }) {
                HStack(spacing: FormSectionTokens.sectionStackSpacing) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(StyleGuide.Typography.sectionTitle)
                        .foregroundStyle(isSelected ? .accentColor : .white.opacity(0.6))

                    Text(calendar.title)
                        .font(.subheadline)
                        .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(calendar.title), \(isSelected ? "visible" : "hidden")")
            .accessibilityHint("Shows or hides this calendar.")
            .accessibilityAddTraits(.isButton)
            
            // Color picker button
            Button(action: {
                showingColorPicker.toggle()
            }) {
                Circle()
                    .fill(currentColor)
                    .frame(width: StyleGuide.Dimensions.entityListIconWidth, height: StyleGuide.Dimensions.entityListIconWidth)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .contentShape(Circle())
            .buttonStyle(.plain)
            .popover(isPresented: $showingColorPicker) {
                VStack(spacing: FormSectionTokens.formGroupSpacing) {
                    Text("Calendar Color")
                        .font(.headline)
                        .padding(.top)
                    
                    ColorPicker("", selection: Binding(
                        get: { currentColor },
                        set: { onColorChange($0) }
                    ))
                    .labelsHidden()
                    .frame(width: StyleGuide.Dimensions.settingsCalendarColorPickerSize, height: StyleGuide.Dimensions.settingsCalendarColorPickerSize)
                    
                    Button("Reset to Default") {
                        onColorChange(Color(calendar.cgColor))
                        showingColorPicker = false
                    }
                    .buttonStyle(.glass)
                    
                    Spacer()
                }
                .frame(width: StyleGuide.Dimensions.settingsCalendarPopoverWidth, height: StyleGuide.Dimensions.settingsCalendarPopoverHeight)
                .padding()
            }
        }
        .padding(.horizontal, paddingMediumLarge)
        .padding(.vertical, paddingSmall)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }
}
