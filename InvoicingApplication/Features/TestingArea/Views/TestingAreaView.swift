import SwiftUI
import SharedUI

struct TestingAreaView: View {
    var body: some View {
        TabView {
            DragDropDemoTab()
                .tabItem {
                    Label("Drag and Drop", systemImage: "hand.draw")
                }
            
            DemoSectionsTab()
                .tabItem {
                    Label("Demo Sections", systemImage: "square.stack")
                }

            HierarchyDemoTab()
                .tabItem {
                    Label("Hierarchy", systemImage: "list.bullet.rectangle")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
    }
}

// MARK: - Drag and Drop Tab
private struct DragDropDemoTab: View {
    var body: some View {
        VStack {
            Text("Testing Area")
                .font(.largeTitle)
                .foregroundColor(.primary)
            
            Text("Drag and Drop Demo")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            DragDropDemoView()
                .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TestingAreaView()
}

// MARK: - Hierarchy Demo Tab
private struct HierarchyDemoTab: View {
    @State private var sections: [DemoSection]
    @Namespace private var hierarchyNamespace

    init() {
        let data: [DemoSection] = [
            DemoSection(
                title: "Colors",
                items: [
                    .text("Primary"),
                    .text("Secondary"),
                    .text("Accent"),
                    .section(
                        DemoSection(
                            title: "Warm Palette",
                            items: [
                                .text("Sunset"),
                                .text("Coral"),
                                .section(
                                    DemoSection(
                                        title: "Highlights",
                                        items: [.text("Glow"), .text("Ember")]
                                    )
                                )
                            ]
                        )
                    ),
                    .section(
                        DemoSection(
                            title: "Cool Palette",
                            items: [.text("Ocean"), .text("Sky"), .text("Mint")]
                        )
                    )
                ]
            ),
            DemoSection(
                title: "Typography",
                items: [
                    .text("Headings"),
                    .section(
                        DemoSection(
                            title: "Body Styles",
                            items: [.text("Body"), .text("Callout"), .text("Caption")]
                        )
                    ),
                    .section(
                        DemoSection(
                            title: "Monospace",
                            items: [.text("Code"), .text("Console")]
                        )
                    )
                ]
            ),
            DemoSection(
                title: "Layout",
                items: [
                    .section(
                        DemoSection(
                            title: "Spacing",
                            items: [.text("Small"), .text("Medium"), .text("Large")]
                        )
                    ),
                    .section(
                        DemoSection(
                            title: "Grid",
                            items: [
                                .text("2-Column"),
                                .text("3-Column"),
                                .section(
                                    DemoSection(
                                        title: "Breakpoints",
                                        items: [.text("Compact"), .text("Regular")]
                                    )
                                )
                            ]
                        )
                    )
                ]
            )
        ]
        _sections = State(initialValue: data)
    }

    var body: some View {
        ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach($sections) { $section in
                        DemoHierarchySectionView(
                            section: $section,
                            namespace: hierarchyNamespace,
                            onExpand: { collapseMainSections(except: $0) }
                        )
                    }
                }
            }
        .background(.clear)
    }
}

private extension HierarchyDemoTab {
    func collapseMainSections(except id: UUID) {
        for index in sections.indices where sections[index].id != id {
            sections[index].isExpanded = false
            sections[index].collapseDescendants()
        }
    }
}

private struct DemoSection: Identifiable {
    let id = UUID()
    var title: String
    var items: [DemoItem]
    var isExpanded: Bool = true

    mutating func collapseDescendants() {
        for index in items.indices {
            guard var child = items[index].section else { continue }
            child.isExpanded = false
            child.collapseDescendants()
            items[index].section = child
        }
    }
}

private struct DemoItem: Identifiable {
    let id = UUID()
    var text: String?
    var section: DemoSection?

    static func text(_ value: String) -> DemoItem { DemoItem(text: value) }
    static func section(_ section: DemoSection) -> DemoItem { DemoItem(section: section) }
}

private struct DemoHierarchySectionView: View {
    @Binding var section: DemoSection
    let namespace: Namespace.ID
    var wrapInGlassEffect: Bool = true
    var onExpand: ((UUID) -> Void)? = nil

    @State private var hoveredItemID: UUID?
    @State private var isAddChildHovered = false
    private let hoverScale: CGFloat = 1.02
    private let hoverAnimation: Animation = .easeOut(duration: 0.12)
    private let childIndent: CGFloat = 20

    var body: some View {
        HierarchySectionCard(
            title: section.title,
            isExpanded: $section.isExpanded,
            appearance: wrapInGlassEffect ? .glass : .plain,
            childSpacing: childIndent,
            namespace: namespace,
            glassIDPrefix: section.id.uuidString,
            glassUnionID: section.id.uuidString,
            onExpand: { onExpand?(section.id) },
            onCollapse: { section.collapseDescendants() }
        ) {
            ForEach($section.items) { $item in
                let itemID = item.id
                if let text = item.text {
                    itemRow(text: text, id: itemID)
                } else if hasSection($item) {
                    DemoHierarchySectionView(
                        section: sectionBinding(for: $item),
                        namespace: namespace,
                        wrapInGlassEffect: false,
                        onExpand: { collapseChildSections(except: $0) }
                    )
                }
            }
            addChildButton
        }
    }

    private func itemRow(text: String, id: UUID) -> some View {
        Text(text)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .glassEffect(.regular, in: .rect(cornerRadius: 8))
            .scaleEffect(hoveredItemID == id ? hoverScale : 1.0)
            .glassEffectID("\(section.id.uuidString)-item-\(text)", in: namespace)
            .onHover { hovering in
                withAnimation(hoverAnimation) {
                    if hovering {
                        hoveredItemID = id
                    } else if hoveredItemID == id {
                        hoveredItemID = nil
                    }
                }
            }
    }

    private var addChildButton: some View {
        Button(action: addChildSection) {
            Label("Add Child Section", systemImage: "plus.circle")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .glassEffect(.regular.tint(.accentColor.opacity(0.5)), in: .rect(cornerRadius: 8))
        .scaleEffect(isAddChildHovered ? hoverScale : 1.0)
        .glassEffectID("\(section.id.uuidString)-add-child", in: namespace)
        .onHover { hovering in
            withAnimation(hoverAnimation) {
                isAddChildHovered = hovering
            }
        }
    }

    private func addChildSection() {
        let nextIndex = section.items.filter { $0.section != nil }.count + 1
        let newSection = DemoSection(
            title: "\(section.title) Child \(nextIndex)",
            items: [.text("Example \(nextIndex).1"), .text("Example \(nextIndex).2")]
        )
        withAnimation {
            section.items.append(.section(newSection))
        }
    }

    private func hasSection(_ item: Binding<DemoItem>) -> Bool {
        item.section.wrappedValue != nil
    }

    private func sectionBinding(for item: Binding<DemoItem>) -> Binding<DemoSection> {
        Binding(
            get: { item.section.wrappedValue ?? DemoSection(title: "Untitled", items: []) },
            set: { item.section.wrappedValue = $0 }
        )
    }

    private func collapseChildSections(except id: UUID) {
        for index in section.items.indices {
            guard var child = section.items[index].section else { continue }
            if child.id == id { continue }
            child.isExpanded = false
            child.collapseDescendants()
            section.items[index].section = child
        }
    }
}
