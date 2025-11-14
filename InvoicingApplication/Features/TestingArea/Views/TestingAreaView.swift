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
        .background(Color("Background", bundle: .sharedUI))
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
            GlassEffectContainer(spacing: 12) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach($sections) { $section in
                        HierarchySectionView(
                            section: $section,
                            namespace: hierarchyNamespace
                        )
                    }
                }
            }
        }
        .background(Color("Background", bundle: .sharedUI))
    }
}

private struct DemoSection: Identifiable {
    let id = UUID()
    var title: String
    var items: [DemoItem]
    var isExpanded: Bool = true
}

private struct DemoItem: Identifiable {
    let id = UUID()
    var text: String?
    var section: DemoSection?

    static func text(_ value: String) -> DemoItem { DemoItem(text: value) }
    static func section(_ section: DemoSection) -> DemoItem { DemoItem(section: section) }
}

private struct HierarchySectionView: View {
    @Binding var section: DemoSection
    let namespace: Namespace.ID

    var body: some View {
        //GlassEffectContainer(spacing: 12) {
        Group {
            headerButton
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                .glassEffectID("\(section.id.uuidString)-header", in: namespace)

            if section.isExpanded {
                Group {
                    ForEach($section.items) { $item in
                        if let text = item.text {
                            itemRow(for: text)
                        } else if hasSection(item) {
                            HierarchySectionView(
                                section: sectionBinding(for: $item),
                                namespace: namespace
                            )
                            .padding(.leading, 16)
                        }
                    }
                    addChildButton
                }
                //.transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var headerButton: some View {
        Button(action: {
            withAnimation {
                section.isExpanded.toggle()
            }
        }) {
            HStack {
                Text(section.title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(section.isExpanded ? 0 : -90))
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

    }

    private func itemRow(for item: String) -> some View {
        Text(item)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .rect(cornerRadius: 8))
            .glassEffectID("\(section.id.uuidString)-item-\(item)", in: namespace)
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
        .glassEffect(.regular.tint(.accentColor.opacity(0.5)), in: .rect(cornerRadius: 8))
        .glassEffectID("\(section.id.uuidString)-add-child", in: namespace)
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
}
