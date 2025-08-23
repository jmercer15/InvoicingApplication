import SwiftUI
import SwiftData // Import SwiftData

struct ExpenseCategoryManagerView: View {
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaxContainerViewModel
    @State private var newCategoryName: String = ""
    @State private var newCategoryIcon: String = "tag.fill"
    
    // A simple list of SFSymbols for the user to choose from.
    let iconOptions = ["tag.fill", "cart.fill", "car.fill", "house.fill", "laptopcomputer", "fuelpump.fill", "phone.fill", "bus.fill", "tram.fill", "airplane", "gift.fill", "cross.case.fill", "heart.text.square.fill"]

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Section(header: Text("Add New Category")) {
                        HStack {
                            TextField("Category Name", text: $newCategoryName)
                            Button(action: addCategory) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(newCategoryName.isEmpty)
                        }
                        
                        Picker("Icon", selection: $newCategoryIcon) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Image(systemName: icon).tag(icon)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Section(header: Text("Existing Categories")) {
                        ForEach(viewModel.categories) { category in
                            HStack {
                                Image(systemName: category.iconName ?? "tag.fill")
                                Text(category.name)
                            }
                        }
                        .onDelete(perform: viewModel.deleteCategory)
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glass)
                        .appInteractiveCursor()
                }
            }
            
        }
    }
    
    private func addCategory() {
        viewModel.addCategory(name: newCategoryName, iconName: newCategoryIcon)
        newCategoryName = ""
    }
} 