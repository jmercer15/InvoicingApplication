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
    private let isCollapsible: Bool
    private let onExpand: (() -> Void)?
    private let onCollapse: (() -> Void)?
    private let headerStyle: HierarchyHeaderStyle?
    private let headerGlassStyle: Glass
    private let content: () -> Content

    public init(
        title: String,
        isExpanded: Binding<Bool>,
        appearance: Appearance = .glass,
        childSpacing: CGFloat = 0,
        isCollapsible: Bool = true,
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
        self.isCollapsible = isCollapsible
        self.onExpand = onExpand
        self.onCollapse = onCollapse
        self.headerStyle = headerStyle
        self.headerGlassStyle = headerGlassStyle
        self.content = content
    }

    public var body: some View {
        let bodyContent = //VStack(alignment: .leading, spacing: childSpacing) {
        Group {
            header

            if isExpanded {
                content()
                    //.padding(.leading, 16)
            }
        }

        switch appearance {
        case .glass:
            GlassEffectContainer(spacing: childSpacing) { bodyContent }
        case .plain:
            bodyContent
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

    @ViewBuilder
    private func styledHeader(_ label: some View) -> some View {
        let padding = headerStyle?.padding ?? defaultHeaderPadding
        let cornerRadius = defaultCornerRadius

        let headerBase = label
            .padding(padding)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
            )
            .glassEffect(headerGlassStyle, in: .rect(cornerRadius: cornerRadius))
            .glassEffectTransition(.materialize)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isCollapsible else { return }
                toggle()
            }
            .pointerStyle(.link)

        if let style = headerStyle {
            headerBase
                .font(style.font)
                .foregroundColor(style.color)
                .opacity(style.opacity)
                .tracking(style.letterSpacing)
                .baselineOffset(style.baselineOffset)
        } else {
            headerBase
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Color.primary)
        }
    }

    private var defaultCornerRadius: CGFloat { 10 }
    private var defaultHeaderPadding: EdgeInsets {
        EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
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
}
