import SwiftUI
import SwiftData // Import SwiftData
import PhotosUI

struct ExpenseEditorView: View {
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: TaxContainerViewModel
    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var date: Date = .now
    @State private var paidDate: Date = .now
    @State private var selectedCategory: ExpenseCategoryEntity?
    @State private var notes: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var image: NSImage?
    @State private var includesGST: Bool = true
    @State private var isCapitalExpense: Bool = false
    @State private var assetUsefulLifeString: String = "5"
    
    // For editing
    var expenseToEdit: ExpenseEntity?

    // For category creation sheet
    @State private var showAddCategorySheet = false

    init(viewModel: TaxContainerViewModel, expenseToEdit: ExpenseEntity? = nil) {
        self.viewModel = viewModel
        self.expenseToEdit = expenseToEdit
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Expense Name", text: $name)
                    FormNumberField(label: "Total Amount", value: $amountString, placeholder: "0.00", prefix: "$")
                    Toggle("Includes GST?", isOn: $includesGST)
                    Toggle("Capital Expense?", isOn: $isCapitalExpense)
                    if isCapitalExpense {
                        FormNumberField(label: "Asset's Useful Life (Years)", value: $assetUsefulLifeString, placeholder: "5")
                    }
                    DatePicker("Date Recorded", selection: $date, displayedComponents: .date)
                    DatePicker("Date Paid", selection: $paidDate, displayedComponents: .date)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(nil as ExpenseCategoryEntity?)
                        ForEach(viewModel.categories) { category in
                            Text(category.name).tag(category as ExpenseCategoryEntity?)
                        }
                    }
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section(header: Text("Receipt")) {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(image == nil ? "Add Receipt" : "Change Receipt", systemImage: "photo.on.rectangle")
                    }
                }
            }

            Spacer()

            Button("Add Category") {
                showAddCategorySheet = true
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    image = NSImage(data: data)
                }
            }
        }
        .onAppear(perform: setupForEditing)
        .navigationTitle(expenseToEdit == nil ? "New Expense" : "Edit Expense")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.glass)
                    .appInteractiveCursor()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveExpense)
                    .buttonStyle(.glassProminent)
                    .appInteractiveCursor()
            }
        }
        
        .padding()
        .sheet(isPresented: $showAddCategorySheet) {
            ExpenseCategoryManagerView(viewModel: viewModel)
        }
    }
    
    private func setupForEditing() {
        if let expense = expenseToEdit {
            name = expense.name
            amountString = String(format: "%.2f", expense.amount + expense.gstAmount)
            includesGST = expense.gstAmount > 0
            isCapitalExpense = expense.isCapitalExpense
            assetUsefulLifeString = String(expense.assetUsefulLife)
            date = expense.date ?? .now
            paidDate = expense.paidDate ?? .now
            selectedCategory = expense.category
            notes = expense.notes ?? ""
            if let data = expense.receiptData, let nsImage = NSImage(data: data) {
                image = nsImage
            }
        }
    }

    private func saveExpense() {
        let expense = expenseToEdit ?? ExpenseEntity(id: UUID(), name: name)
        expense.name = name

        let totalAmount = Double(amountString) ?? 0.0
        if includesGST {
            expense.gstAmount = totalAmount / 11.0
            expense.amount = totalAmount - expense.gstAmount
        } else {
            expense.gstAmount = 0.0
            expense.amount = totalAmount
        }

        expense.isCapitalExpense = isCapitalExpense
        if expense.isCapitalExpense {
            expense.assetUsefulLife = Int16(assetUsefulLifeString) ?? 5
        }
        expense.date = date
        expense.paidDate = paidDate
        expense.category = selectedCategory
        expense.notes = notes
        expense.receiptData = image?.tiffRepresentation

        if expenseToEdit == nil {
            modelContext.insert(expense)
        }

        do {
            try modelContext.save() // Save using modelContext
            viewModel.fetchData() // Refresh data in container
            dismiss()
        } catch {
            print("Failed to save expense: \(error)")
        }
    }
} 