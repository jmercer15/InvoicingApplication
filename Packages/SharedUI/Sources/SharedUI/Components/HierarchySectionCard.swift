import SwiftUI

public struct HierarchyHeaderStyle {
    public var font: Font
    public var color: Color
    public var opacity: Double
    public var letterSpacing: CGFloat
    public var baselineOffset: CGFloat
    public var padding: EdgeInsets

    public init(
        font: Font,
        color: Color,
        opacity: Double,
        letterSpacing: CGFloat,
        baselineOffset: CGFloat,
        padding: EdgeInsets
    ) {
        self.font = font
        self.color = color
        self.opacity = opacity
        self.letterSpacing = letterSpacing
        self.baselineOffset = baselineOffset
        self.padding = padding
    }
}

public struct HierarchySectionCard<Content: View>: View {
    public enum Appearance {
        case glass
        case plain
    }

    private let title: String
    @Binding private var isExpanded: Bool
    private let appearance: Appearance
    private let childSpacing: CGFloat
    private let namespace: Namespace.ID?
    private let glassIDPrefix: String?
    private let glassUnionID: String?
    private let isCollapsible: Bool
    private let expandedCornerRadius: CGFloat
    private let collapsedCornerRadius: CGFloat
    private let onExpand: (() -> Void)?
    private let onCollapse: (() -> Void)?
    private let headerStyle: HierarchyHeaderStyle?
    private let headerGlassStyle: Glass
    private let content: () -> Content

    @State private var isHeaderHovered = false
    private let hoverScale: CGFloat = 1.02
    private let hoverAnimation: Animation = .easeOut(duration: 0.12)

    public init(
        title: String,
        isExpanded: Binding<Bool>,
        appearance: Appearance = .glass,
        childSpacing: CGFloat = 10,
        namespace: Namespace.ID? = nil,
        glassIDPrefix: String? = nil,
        glassUnionID: String? = nil,
        isCollapsible: Bool = true,
        expandedCornerRadius: CGFloat = 10,
        collapsedCornerRadius: CGFloat = 10,
        onExpand: (() -> Void)? = nil,
        onCollapse: (() -> Void)? = nil,
        headerStyle: HierarchyHeaderStyle? = nil,
        headerGlassStyle: Glass = .regular.interactive(),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.appearance = appearance
        self.childSpacing = childSpacing
        self.namespace = namespace
        self.glassIDPrefix = glassIDPrefix
        self.glassUnionID = glassUnionID
        self.isCollapsible = isCollapsible
        self.expandedCornerRadius = expandedCornerRadius
        self.collapsedCornerRadius = collapsedCornerRadius
        self.onExpand = onExpand
        self.onCollapse = onCollapse
        self.headerStyle = headerStyle
        self.headerGlassStyle = headerGlassStyle
        self.content = content
    }

    public var body: some View {
        container {
            VStack(alignment: .leading, spacing: childSpacing) {
                header

                if isExpanded {
                    VStack(alignment: .leading, spacing: childSpacing) {
                        content()
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }

    private func container<Inner: View>(@ViewBuilder inner: () -> Inner) -> some View {
        Group {
            switch appearance {
            case .glass:
                GlassEffectContainer(spacing: childSpacing) {
                    inner()
                }
            case .plain:
                VStack(alignment: .leading, spacing: childSpacing) {
                    inner()
                }
            }
        }
    }

    private var header: some View {
        let baseLabel = HStack {
            Text(title)
            Spacer()
            if isCollapsible {
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .font(.subheadline.weight(.semibold))
            }
        }
        return styledHeader(baseLabel)
    }

    private func styledHeader(_ label: some View) -> some View {
        let padding = headerStyle?.padding ?? EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        let styled = label
            .padding(padding)
            .contentShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
            )
            .glassEffect(headerGlassStyle, in: .rect(cornerRadius: currentCornerRadius))
            .glassEffectTransition(.materialize)

            .applyGlassID(namespace: namespace, id: headerGlassID)
            .applyGlassUnion(namespace: namespace, id: glassUnionID)

            .contentShape(Rectangle())
            .onTapGesture {
                guard isCollapsible else { return }
                toggle()
            }
            .pointerStyle(.link)

        let finalView: AnyView
        if let style = headerStyle {
            finalView = AnyView(
                styled
                    .font(style.font)
                    .foregroundColor(style.color)
                    .opacity(style.opacity)
                    .tracking(style.letterSpacing)
                    .baselineOffset(style.baselineOffset)
            )
        } else {
            finalView = AnyView(
                styled
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.primary)
            )
        }

        return finalView
    }

    private var currentCornerRadius: CGFloat {
        isExpanded ? expandedCornerRadius : collapsedCornerRadius
    }

    private func toggle() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let expanding = !isExpanded
            isExpanded.toggle()
            if expanding {
                onExpand?()
            } else {
                onCollapse?()
            }
        }
    }

    private var headerGlassID: String {
        let safeTitle = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(glassIDPrefix ?? safeTitle)-header"
    }
}

private extension View {
    @ViewBuilder
    func applyGlassID(namespace: Namespace.ID?, id: String) -> some View {
        if let namespace {
            self
                .glassEffectID(id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyGlassUnion(namespace: Namespace.ID?, id: String?) -> some View {
        if let namespace, let id {
            self
                .glassEffectUnion(id: id, namespace: namespace)
        } else {
            self
        }
    }
}
