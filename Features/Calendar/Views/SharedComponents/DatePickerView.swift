import SwiftUI

struct DatePickerView: View {
    @Binding var selectedDate: Date
    let onDateSelected: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Go to Date")
                .font(.headline)
                .fontWeight(.semibold)
            
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    // Popover will be dismissed by parent
                }
                .buttonStyle(.glass)
                
                Button("Go") {
                    onDateSelected()
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding()
    }
}

#Preview {
    DatePickerView(
        selectedDate: .constant(Date()),
        onDateSelected: {}
    )
} 