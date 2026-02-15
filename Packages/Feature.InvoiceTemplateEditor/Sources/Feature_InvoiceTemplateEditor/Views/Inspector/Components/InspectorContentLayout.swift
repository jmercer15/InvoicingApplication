import SwiftUI
import SharedUI

// MARK: - Generic Section Descriptor

struct InspectorSectionDescriptor<Section: Hashable>: Identifiable {
    let section: Section
    let title: String
    let alwaysExpanded: Bool
    let isVisible: Bool
    let buildContent: () -> AnyView
    
    var id: Section { section }
}

// MARK: - Panel Max Height Environment

private struct PanelMaxHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var panelMaxHeight: CGFloat? {
        get { self[PanelMaxHeightKey.self] }
        set { self[PanelMaxHeightKey.self] = newValue }
    }
}

// MARK: - Generic Inspector Content Layout

struct InspectorContentLayout<Header: View, Section: Hashable>: View {
    let header: Header
    let descriptors: [InspectorSectionDescriptor<Section>]
    let side: Edge
    @Binding var expandedSections: Set<AnyHashable>
    
    init(
        header: Header,
        descriptors: [InspectorSectionDescriptor<Section>],
        side: Edge = .trailing,
        expandedSections: Binding<Set<AnyHashable>>
    ) {
        self.header = header
        self.descriptors = descriptors
        self.side = side
        self._expandedSections = expandedSections
    }
    
    @State private var contentHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 0
    @Environment(\.panelMaxHeight) private var maxHeight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sticky header
            header
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.14),
                                    Color.accentColor.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: HeaderHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                )
            
            // Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(descriptors.enumerated()), id: \.element.id) { index, descriptor in
                        sectionView(for: descriptor)
                        
                        // Add divider between sections (not after last one)
                        if index < descriptors.count - 1 {
                            Divider()
                                .foregroundColor(Color(NSColor.separatorColor))
                        }
                    }
                    .animation(.smooth(duration: 0.3), value: descriptors.map { $0.id })
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 14)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ContentHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                )
            }
        }
        .frame(height: min(headerHeight + contentHeight, maxHeight ?? .infinity))
        .onPreferenceChange(HeaderHeightKey.self) { height in
            withAnimation(.smooth(duration: 0.3)) {
                headerHeight = height
            }
        }
        .onPreferenceChange(ContentHeightKey.self) { height in
            withAnimation(.smooth(duration: 0.3)) {
                contentHeight = height
            }
        }
    }
    
    @ViewBuilder
    private func sectionView(for descriptor: InspectorSectionDescriptor<Section>) -> some View {
        let isExpanded = descriptor.alwaysExpanded || expandedSections.contains(descriptor.section as AnyHashable)
        let hasTitle = !descriptor.title.isEmpty
        
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible header - only show if there's a title
            if hasTitle {
                SectionHeaderButton(
                    title: descriptor.title,
                    isExpanded: isExpanded,
                    alwaysExpanded: descriptor.alwaysExpanded,
                    action: {
                        if !descriptor.alwaysExpanded {
                            updateExpansion(for: descriptor.section, isExpanded: !isExpanded)
                        }
                    }
                )
            }
            
            // Content (conditionally shown) - wrap in accordion context
            if isExpanded {
                SectionAccordionWrapper {
                    descriptor.buildContent()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, hasTitle ? 4 : 0)
    }
    
    private func updateExpansion(for section: Section, isExpanded: Bool) {
        withAnimation(.smooth(duration: 0.3)) {
            if isExpanded {
                expandedSections = Set([section as AnyHashable])
            } else {
                expandedSections.remove(section as AnyHashable)
            }
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Section Header Button with Hover Effect

private struct SectionHeaderButton: View {
    let title: String
    let isExpanded: Bool
    let alwaysExpanded: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(InspectorTypography.sectionHeader)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !alwaysExpanded {
                    Image("fluent-ic_fluent_chevron_right_20_regular", bundle: .module)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: InspectorTypography.sectionChevronSize, height: InspectorTypography.sectionChevronSize)
                        .foregroundColor(isHovered ? .primary : .secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

/// Wrapper that provides a fresh InspectorAccordionContext for each section's content.
/// This ensures the first InspectorGroupBox in the section auto-expands when the section opens.
struct SectionAccordionWrapper<Content: View>: View {
    @StateObject private var context = InspectorAccordionContext()
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .environment(\.inspectorAccordionContext, context)
    }
}

// MARK: - Preview

#Preview("InspectorContentLayout") {
    struct PreviewWrapper: View {
        @State private var expandedSections: Set<AnyHashable> = ["General"]
        
        var body: some View {
            InspectorContentLayout(
                header: header,
                descriptors: [
                    InspectorSectionDescriptor(
                        section: "General",
                        title: "General",
                        alwaysExpanded: false,
                        isVisible: true
                    ) {
                        AnyView(
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Label: Header Section")
                                    .font(.system(size: 11))
                                Text("Alignment: Center")
                                    .font(.system(size: 11))
                            }
                            .padding(.vertical, 4)
                        )
                    },
                    InspectorSectionDescriptor(
                        section: "Layout",
                        title: "Layout",
                        alwaysExpanded: false,
                        isVisible: true
                    ) {
                        AnyView(
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Padding: 8pt")
                                    .font(.system(size: 11))
                                Text("Spacing: 4pt")
                                    .font(.system(size: 11))
                            }
                            .padding(.vertical, 4)
                        )
                    }
                ],
                expandedSections: $expandedSections
            )
            .frame(width: 280)
            .environment(\.panelMaxHeight, 400)
        }
        
        var header: some View {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 28, height: 28)
                    
                    Image("fluent-ic_fluent_split_horizontal_20_regular", bundle: .module)
                        .scaleEffect(0.6)
                        .foregroundColor(Color.accentColor)
                }
                
                Text("Split")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                
                Text("· Header")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    return PreviewWrapper()
}
