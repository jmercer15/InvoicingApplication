// DragDropDemoView.swift
// macOS 26 SDK (SwiftUI)
// Demonstrates BOTH:
//  1) List reordering via .onMove
//  2) Grid reordering via drag-container helpers + multi-selection drag
import SwiftUI
import UniformTypeIdentifiers

// Custom UTIs for drag and drop
extension UTType {
    static let fruitID = UTType(exportedAs: "com.example.fruit-id")
    static let fruitPropertyID = UTType(exportedAs: "com.example.fruit-property-id")
}

// MARK: - Model
struct FruitProperty: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct Fruit: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    var properties: [FruitProperty]

    init(id: UUID = UUID(), name: String, emoji: String, properties: [String] = []) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.properties = properties.map { FruitProperty(id: UUID(), name: $0) }
    }
}

// MARK: - Root
struct DragDropDemoView: View {
    @State private var listItems: [Fruit] = [
        .init(name: "Granny Smith", emoji: "🍏", properties: ["Sweet", "Crispy", "Fresh"]),
        .init(name: "Cavendish",    emoji: "🍌", properties: ["Yellow", "Potassium", "Energy"]),
        .init(name: "Camarosa",     emoji: "🍓", properties: ["Red", "Sweet", "Summer"]),
        .init(name: "Elberta",      emoji: "🍑", properties: ["Fuzzy", "Stone fruit", "Soft"]),
        .init(name: "Cayenne",      emoji: "🍍", properties: ["Tropical", "Spiky", "Sweet"]),
    ]

    @State private var list1Items: [Fruit] = [
        .init(name: "Honeycrisp",   emoji: "🍎", properties: ["Sweet", "Crispy", "Fresh"]),
        .init(name: "Bartlett",     emoji: "🍐", properties: ["Juicy", "Soft", "Fragrant"]),
        .init(name: "Navel",        emoji: "🍊", properties: ["Citrus", "Vitamin C", "Zesty"]),
        .init(name: "Kishu",        emoji: "🍊", properties: ["Citrus", "Small", "Sweet"]),
    ]
    
    @State private var list2Items: [Fruit] = [
        .init(name: "Sultana",      emoji: "🍇", properties: ["Small", "Sweet", "Seedless"]),
        .init(name: "Kensington",   emoji: "🥭", properties: ["Tropical", "Creamy", "Rich"]),
        .init(name: "Kumamoto",     emoji: "🍓", properties: ["Red", "Sweet", "Summer"]),
        .init(name: "Cavendish",    emoji: "🍌", properties: ["Yellow", "Potassium", "Energy"]),
    ]
    
    @State private var list3Items: [Fruit] = [
        .init(name: "Granny Smith", emoji: "🍏", properties: ["Sweet", "Crispy", "Fresh"]),
        .init(name: "Camarosa",     emoji: "🍓", properties: ["Red", "Sweet", "Summer"]),
        .init(name: "Elberta",      emoji: "🍑", properties: ["Fuzzy", "Stone fruit", "Soft"]),
        .init(name: "Cayenne",      emoji: "🍍", properties: ["Tropical", "Spiky", "Sweet"]),
    ]

    var body: some View {
        TabView {
            ListReorderView(items: $listItems)
                .tabItem { Label("List", systemImage: "list.bullet") }

            MultiListReorderView(
                list1Items: $list1Items,
                list2Items: $list2Items,
                list3Items: $list3Items
            )
            .tabItem { Label("Multi-List", systemImage: "square.grid.3x3") }
        }
        .frame(minWidth: 520, minHeight: 380)
    }
}

// MARK: - 1) List reordering (built-in)
struct ListReorderView: View {
    @Binding var items: [Fruit]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Drag rows to reorder (List)")
                .font(.headline)
                .padding(.top, 8)

            List {
                ForEach(items) { item in
                    HStack {
                        Text(item.emoji).font(.title3)
                        Text(item.name)
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: move)
            }
            .padding(.bottom, 8)

            HStack {
                Button("Shuffle") { items.shuffle() }
                Button("Reset")  { reset() }
                Spacer()
            }
        }
        .padding(12)
    }

    private func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    private func reset() {
        items = [
            .init(name: "Granny Smith", emoji: "🍏", properties: ["Sweet", "Crispy", "Fresh"]),
            .init(name: "Cavendish",    emoji: "🍌", properties: ["Yellow", "Potassium", "Energy"]),
            .init(name: "Camarosa",     emoji: "🍓", properties: ["Red", "Sweet", "Summer"]),
            .init(name: "Elberta",      emoji: "🍑", properties: ["Fuzzy", "Stone fruit", "Soft"]),
            .init(name: "Cayenne",      emoji: "🍍", properties: ["Tropical", "Spiky", "Sweet"]),
        ]
    }
}

// MARK: - 2) Multi-list reordering (cross-list drag & drop)
struct MultiListReorderView: View {
    @Binding var list1Items: [Fruit]
    @Binding var list2Items: [Fruit]
    @Binding var list3Items: [Fruit]
    
    @State private var draggingID: UUID?
    @State private var isPropertyBeingDragged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drag items between lists (cross-list drag & drop)")
                .font(.headline)
                .padding(.top, 8)

            Text("Tip: Drag items from one list to another, or reorder within the same list.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                // List 1
                VStack(alignment: .leading, spacing: 8) {
                    Text("List 1")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ReorderableList(
                        items: $list1Items,
                        draggingID: $draggingID,
                        isPropertyBeingDragged: $isPropertyBeingDragged,
                        listName: "List 1",
                        otherLists: [$list2Items, $list3Items]
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // List 2
                VStack(alignment: .leading, spacing: 8) {
                    Text("List 2")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ReorderableList(
                        items: $list2Items,
                        draggingID: $draggingID,
                        isPropertyBeingDragged: $isPropertyBeingDragged,
                        listName: "List 2",
                        otherLists: [$list1Items, $list3Items]
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // List 3
                VStack(alignment: .leading, spacing: 8) {
                    Text("List 3")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ReorderableList(
                        items: $list3Items,
                        draggingID: $draggingID,
                        isPropertyBeingDragged: $isPropertyBeingDragged,
                        listName: "List 3",
                        otherLists: [$list1Items, $list2Items]
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity)

            HStack {
                Button("Shuffle All") {
                    list1Items.shuffle()
                    list2Items.shuffle()
                    list3Items.shuffle()
                }
                Button("Reset All") { resetAll() }
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(12)
    }
    
    private func resetAll() {
        list1Items = [
            .init(name: "Honeycrisp",   emoji: "🍎", properties: ["Sweet", "Crispy", "Fresh"]),
            .init(name: "Bartlett",     emoji: "🍐", properties: ["Juicy", "Soft", "Fragrant"]),
            .init(name: "Navel",        emoji: "🍊", properties: ["Citrus", "Vitamin C", "Zesty"]),
            .init(name: "Kishu",        emoji: "🍊", properties: ["Citrus", "Small", "Sweet"]),
        ]
        
        list2Items = [
            .init(name: "Sultana",      emoji: "🍇", properties: ["Small", "Sweet", "Seedless"]),
            .init(name: "Kensington",   emoji: "🥭", properties: ["Tropical", "Creamy", "Rich"]),
            .init(name: "Kumamoto",     emoji: "🍓", properties: ["Red", "Sweet", "Summer"]),
            .init(name: "Cavendish",    emoji: "🍌", properties: ["Yellow", "Potassium", "Energy"]),
        ]
        
        list3Items = [
            .init(name: "Granny Smith", emoji: "🍏", properties: ["Sweet", "Crispy", "Fresh"]),
            .init(name: "Camarosa",     emoji: "🍓", properties: ["Red", "Sweet", "Summer"]),
            .init(name: "Elberta",      emoji: "🍑", properties: ["Fuzzy", "Stone fruit", "Soft"]),
            .init(name: "Cayenne",      emoji: "🍍", properties: ["Tropical", "Spiky", "Sweet"]),
        ]
    }
}

// MARK: - Helper Functions
private func loadFruitID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
    guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fruitID.identifier) }) else {
        return false
    }
    provider.loadDataRepresentation(forTypeIdentifier: UTType.fruitID.identifier) { data, _ in
        guard let data, let s = String(data: data, encoding: .utf8), let id = UUID(uuidString: s) else { return }
        DispatchQueue.main.async { handle(id) }
    }
    return true
}

private func moveFruit(id: UUID, to targetItem: Fruit, in list: inout [Fruit], from otherLists: [Binding<[Fruit]>]) {
    // Find the target position
    guard let targetIndex = list.firstIndex(of: targetItem) else { return }
    
    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
        // If it's from the same list, reorder
        if let sourceIndex = list.firstIndex(where: { $0.id == id }) {
            list.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetIndex)
            return
        }
        
        // If it's from another list, remove from source and insert here
        for otherList in otherLists {
            if let sourceIndex = otherList.wrappedValue.firstIndex(where: { $0.id == id }) {
                let fruit = otherList.wrappedValue.remove(at: sourceIndex)
                list.insert(fruit, at: targetIndex)
                return
            }
        }
    }
}

private func appendFruit(id: UUID, to list: inout [Fruit], from otherLists: [Binding<[Fruit]>]) {
    // Find the fruit in other lists and move it
    for otherList in otherLists {
        if let sourceIndex = otherList.wrappedValue.firstIndex(where: { $0.id == id }) {
            let fruit = otherList.wrappedValue[sourceIndex]
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                otherList.wrappedValue.remove(at: sourceIndex)
                list.append(fruit)
            }
            return
        }
    }
}

// MARK: - Individual Reorderable List
struct ListItemWrapper: View {
    @Binding var item: Fruit
    @Binding var targetedItemID: UUID?
    @Binding var isPropertyBeingDragged: Bool
    @Binding var allItems: [Fruit]
    let otherLists: [Binding<[Fruit]>]
    let shouldHighlightSeparator: Bool
    @State private var isItemTargeted = false
    
    var body: some View {
        ListItemView(
            item: $item,
            isDropTargeted: .constant(targetedItemID == item.id),
            isPropertyBeingDragged: $isPropertyBeingDragged,
            allItems: $allItems,
            otherLists: otherLists
        )
        .onDrop(of: [UTType.fruitID.identifier], isTargeted: $isItemTargeted) { providers in
            loadFruitID(from: providers) { fruitID in
                moveFruit(id: fruitID, to: item, in: &allItems, from: otherLists)
            }
        }
        .onChange(of: isItemTargeted) { isTargeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                targetedItemID = isTargeted ? item.id : nil
            }
        }
        .listRowSeparator(.visible)
        .listRowSeparatorTint(shouldHighlightSeparator ? .blue : .gray.opacity(0.3))
    }
}

struct ReorderableList: View {
    @Binding var items: [Fruit]
    @Binding var draggingID: UUID?
    @Binding var isPropertyBeingDragged: Bool
    let listName: String
    let otherLists: [Binding<[Fruit]>]
    @State private var targetedItemID: UUID?
    @State private var isBottomTargeted = false
    
    
    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                listItemView(for: item, at: index)
            }
            
            bottomDropZone
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.2))
        )
    }
    
    private func listItemView(for item: Fruit, at index: Int) -> some View {
        ListItemWrapper(
            item: $items[index],
            targetedItemID: $targetedItemID,
            isPropertyBeingDragged: $isPropertyBeingDragged,
            allItems: $items,
            otherLists: otherLists,
            shouldHighlightSeparator: shouldHighlightSeparator(for: item, at: index)
        )
    }
    
    private var bottomDropZone: some View {
        BottomDropZone(isTargeted: .constant(targetedItemID == nil && isBottomTargeted))
            .onDrop(of: [UTType.fruitID.identifier], isTargeted: $isBottomTargeted) { providers in
                loadFruitID(from: providers) { fruitID in
                    appendFruit(id: fruitID, to: &items, from: otherLists)
                }
            }
            .onChange(of: isBottomTargeted) { isTargeted in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isTargeted {
                        targetedItemID = nil // Clear item targeting when targeting bottom
                    }
                }
            }
    }
    
    private func shouldHighlightSeparator(for item: Fruit, at index: Int) -> Bool {
        guard let targetedID = targetedItemID else { return false }
        
        // Highlight this item's separator (which appears below this item) 
        // only if the NEXT item is the one being targeted for insertion
        if index < items.count - 1 {
            let nextItem = items[index + 1]
            if nextItem.id == targetedID {
                return true
            }
        }
        
        return false
    }
    
    private func handleItemInsert(droppedFruits: [Fruit], targetItem: Fruit) -> Bool {
        guard let droppedFruit = droppedFruits.first else { return false }
        
        // Find the target position
        guard let targetIndex = items.firstIndex(of: targetItem) else { return false }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
            // If it's from the same list, reorder
            if let sourceIndex = items.firstIndex(of: droppedFruit) {
                items.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetIndex)
                return
            }
            
            // If it's from another list, remove from source and insert here
            for otherList in otherLists {
                if let sourceIndex = otherList.wrappedValue.firstIndex(of: droppedFruit) {
                    otherList.wrappedValue.remove(at: sourceIndex)
                    items.insert(droppedFruit, at: targetIndex)
                    return
                }
            }
        }
        
        return true
    }
    
    private func handleCrossListDrop(droppedFruits: [Fruit], location: CGPoint) -> Bool {
        guard let droppedFruit = droppedFruits.first else { return false }
        
        // Only add if not already in current list
        if items.firstIndex(of: droppedFruit) == nil {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                // Find and remove from source list
                for otherList in otherLists {
                    if let itemIndex = otherList.wrappedValue.firstIndex(of: droppedFruit) {
                        otherList.wrappedValue.remove(at: itemIndex)
                        break
                    }
                }
                
                // Add to current list
                items.append(droppedFruit)
            }
            return true
        }
        
        return false
    }
    
}



// MARK: - Bottom Drop Zone
struct BottomDropZone: View {
    @Binding var isTargeted: Bool
    
    var body: some View {
        Rectangle()
            .fill(isTargeted ? Color.blue.opacity(0.2) : Color.clear)
            .frame(height: isTargeted ? 40 : 20)
            .overlay(
                Text(isTargeted ? "Drop to add" : "")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            )
            .padding(.horizontal, 12)
    }
}


// MARK: - Individual List Item
struct ListItemView: View {
    @Binding var item: Fruit
    @Binding var isDropTargeted: Bool
    @Binding var isPropertyBeingDragged: Bool
    @Binding var allItems: [Fruit]
    let otherLists: [Binding<[Fruit]>]
    @State private var targetedPropertyID: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Text(item.emoji)
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.quaternary.opacity(0.3))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Fruit • \(item.properties.count) properties")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Embedded properties list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(item.properties.indices, id: \.self) { index in
                    let property = item.properties[index]
                    PropertyItemView(
                        property: property,
                        isDropTargeted: .constant(targetedPropertyID == property.id),
                        isPropertyBeingDragged: $isPropertyBeingDragged,
                        onInsert: { newProperty, insertIndex in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                handlePropertyInsert(newProperty: newProperty, insertIndex: insertIndex)
                            }
                            // Reset drag state
                            isPropertyBeingDragged = false
                        },
                        currentIndex: index,
                        onTargetingChanged: { isTargeted in
                            targetedPropertyID = isTargeted ? property.id : nil
                        },
                        allItems: $allItems,
                        otherLists: otherLists
                    )
                }
                
                // Drop zone for adding new properties at the end (only show when dragging a property)
                if isPropertyBeingDragged {
                    PropertyDropZone(
                        onAdd: { newProperty in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                // Remove from all other fruits first
                                removePropertyFromOtherFruits(property: newProperty)
                                // Then add to this fruit
                                item.properties.append(newProperty)
                            }
                        },
                        allItems: $allItems,
                        otherLists: otherLists,
                        isPropertyBeingDragged: $isPropertyBeingDragged
                    )
                }
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(
                    color: isDropTargeted ? .blue.opacity(0.3) : .black.opacity(0.1),
                    radius: isDropTargeted ? 8 : 2,
                    x: 0,
                    y: isDropTargeted ? 2 : 1
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDropTargeted ? .blue : Color.clear, lineWidth: isDropTargeted ? 2 : 0)
                )
        )
        .scaleEffect(isDropTargeted ? 1.02 : 1.0)
        .onDrag {
            let idString = item.id.uuidString
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: UTType.fruitID.identifier, visibility: .all) { completion in
                completion(idString.data(using: .utf8), nil)
                return nil
            }
            return provider
        }
    }
    
    private func handlePropertyInsert(newProperty: FruitProperty, insertIndex: Int) {
        // Check if it's from the same fruit (reordering within same fruit)
        if let sourceIndex = item.properties.firstIndex(where: { $0.id == newProperty.id }) {
            // Within-fruit reordering
            item.properties.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: insertIndex)
        } else {
            // Cross-fruit transfer
            // Remove from all other fruits first
            removePropertyFromOtherFruits(property: newProperty)
            // Then insert at specific position
            item.properties.insert(newProperty, at: insertIndex)
        }
    }
    
    private func removePropertyFromOtherFruits(property: FruitProperty) {
        // Remove from current list (excluding current item)
        for i in allItems.indices {
            if allItems[i].id != item.id { // Don't remove from current fruit
                allItems[i].properties.removeAll { $0.id == property.id }
            }
        }
        
        // Remove from all other main lists
        for otherList in otherLists {
            for i in otherList.wrappedValue.indices {
                otherList.wrappedValue[i].properties.removeAll { $0.id == property.id }
            }
        }
    }
    
    // Helper function for loading FruitProperty IDs
    private func loadFruitPropertyID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fruitPropertyID.identifier) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.fruitPropertyID.identifier) { data, _ in
            guard let data, let s = String(data: data, encoding: .utf8), let id = UUID(uuidString: s) else { return }
            DispatchQueue.main.async { handle(id) }
        }
        return true
    }
}

// MARK: - Property Item View
struct PropertyItemView: View {
    let property: FruitProperty
    @Binding var isDropTargeted: Bool
    @Binding var isPropertyBeingDragged: Bool
    let onInsert: (FruitProperty, Int) -> Void
    let currentIndex: Int
    let onTargetingChanged: (Bool) -> Void
    @Binding var allItems: [Fruit]
    let otherLists: [Binding<[Fruit]>]
    @State private var isDragTargeted = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini icon/indicator
            RoundedRectangle(cornerRadius: 3)
                .fill((isDropTargeted || isDragTargeted) ? .blue : .blue.opacity(0.6))
                .frame(width: 6, height: 6)
            
            Text(property.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.quaternaryLabelColor).opacity(0.1))
                .shadow(
                    color: (isDropTargeted || isDragTargeted) ? .blue.opacity(0.3) : .black.opacity(0.05),
                    radius: (isDropTargeted || isDragTargeted) ? 4 : 1,
                    x: 0,
                    y: (isDropTargeted || isDragTargeted) ? 1 : 0.5
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((isDropTargeted || isDragTargeted) ? .blue : Color.clear, lineWidth: (isDropTargeted || isDragTargeted) ? 1.5 : 0)
                )
        )
        .scaleEffect((isDropTargeted || isDragTargeted) ? 1.02 : 1.0)
        .onDrag {
            isPropertyBeingDragged = true
            let idString = property.id.uuidString
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: UTType.fruitPropertyID.identifier, visibility: .all) { completion in
                completion(idString.data(using: .utf8), nil)
                return nil
            }
            return provider
        }
        .onDrop(of: [UTType.fruitPropertyID.identifier], isTargeted: $isDragTargeted) { providers in
            loadFruitPropertyID(from: providers) { propertyID in
                // Find the original property and move it
                if let originalProperty = findProperty(by: propertyID) {
                    onInsert(originalProperty, currentIndex)
                }
            }
            // Reset drag state
            isPropertyBeingDragged = false
            return true
        }
    }
    
    // Helper function for loading FruitProperty IDs
    private func loadFruitPropertyID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fruitPropertyID.identifier) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.fruitPropertyID.identifier) { data, _ in
            guard let data, let s = String(data: data, encoding: .utf8), let id = UUID(uuidString: s) else { return }
            DispatchQueue.main.async { handle(id) }
        }
        return true
    }
    
    // Helper function to find a property by ID across all fruits
    private func findProperty(by id: UUID) -> FruitProperty? {
        // Search in all items in the current list
        for fruit in allItems {
            if let property = fruit.properties.first(where: { $0.id == id }) {
                return property
            }
        }
        
        // Search in all other lists
        for otherList in otherLists {
            for fruit in otherList.wrappedValue {
                if let property = fruit.properties.first(where: { $0.id == id }) {
                    return property
                }
            }
        }
        
        return nil
    }
}

// MARK: - Property Drop Zone
struct PropertyDropZone: View {
    let onAdd: (FruitProperty) -> Void
    @Binding var allItems: [Fruit]
    let otherLists: [Binding<[Fruit]>]
    @Binding var isPropertyBeingDragged: Bool
    @State private var isTargeted = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Plus icon indicator
            Image(systemName: "plus")
                .font(.caption2)
                .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.6))
            
            Text(isTargeted ? "Drop property here" : "Add property...")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isTargeted ? .blue : .secondary.opacity(0.7))
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.blue.opacity(0.1) : Color(.quaternaryLabelColor).opacity(0.05))
                .shadow(
                    color: isTargeted ? .blue.opacity(0.2) : .black.opacity(0.03),
                    radius: isTargeted ? 3 : 0.5,
                    x: 0,
                    y: isTargeted ? 1 : 0.5
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isTargeted ? .blue : .secondary.opacity(0.2), 
                            style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 1, dash: isTargeted ? [] : [3, 2])
                        )
                )
        )
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .onDrop(of: [UTType.fruitPropertyID.identifier], isTargeted: $isTargeted) { providers in
            loadFruitPropertyID(from: providers) { propertyID in
                // Find the original property and add it
                if let originalProperty = findProperty(by: propertyID) {
                    onAdd(originalProperty)
                }
            }
            // Reset drag state
            isPropertyBeingDragged = false
            return true
        }
    }
    
    // Helper function for loading FruitProperty IDs
    private func loadFruitPropertyID(from providers: [NSItemProvider], handle: @escaping (UUID) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fruitPropertyID.identifier) }) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.fruitPropertyID.identifier) { data, _ in
            guard let data, let s = String(data: data, encoding: .utf8), let id = UUID(uuidString: s) else { return }
            DispatchQueue.main.async { handle(id) }
        }
        return true
    }
    
    // Helper function to find a property by ID across all fruits
    private func findProperty(by id: UUID) -> FruitProperty? {
        // Search in all items in the current list
        for fruit in allItems {
            if let property = fruit.properties.first(where: { $0.id == id }) {
                return property
            }
        }
        
        // Search in all other lists
        for otherList in otherLists {
            for fruit in otherList.wrappedValue {
                if let property = fruit.properties.first(where: { $0.id == id }) {
                    return property
                }
            }
        }
        
        return nil
    }
}


#Preview {
    DragDropDemoView()
}

