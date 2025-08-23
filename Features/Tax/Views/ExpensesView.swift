import SwiftUI


struct ExpensesView: View {
    let expenses: [ExpenseEntity]
    let onEdit: (ExpenseEntity) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        List {
            if expenses.isEmpty {
                Text("No expenses recorded for this period.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(expenses) { expense in
                    ExpenseRowView(expense: expense)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onEdit(expense)
                        }
                        .appInteractiveCursor()
                }
                .onDelete(perform: onDelete)
            }
        }
        .listStyle(.plain)
    }
}

struct ExpenseRowView: View {
    let expense: ExpenseEntity

    var body: some View {
        HStack {
            Image(systemName: expense.receiptData == nil ? "doc.text" : "doc.text.image")
                .foregroundColor(expense.receiptData == nil ? .gray : .accentColor)
            Text(expense.name)
            Spacer()
            if let category = expense.category {
                Text(category.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
            Text(expense.date ?? .now, formatter: Self.dateFormatter)
                .foregroundColor(.secondary)
            Text(expense.amount + expense.gstAmount, format: .currency(code: "AUD"))
                .frame(width: 100, alignment: .trailing)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.vertical, 4)
    }

    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
} 