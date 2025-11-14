import SwiftUI
import AppKit

// MARK: - Typography presets

enum InspectorFontLevel {
    case l1MainHeader
    case l2SectionHeader
    case l3Subsection
    case l4SubSubsection
    case controlLabel
    case controlValue
    case controlValueNumeric
}

extension InspectorFontLevel {
    var font: Font {
        switch self {
        case .l1MainHeader:
            return .system(size: 22, weight: .semibold)
        case .l2SectionHeader:
            return .system(size: 17, weight: .semibold)
        case .l3Subsection:
            return .system(size: 14.5, weight: .medium)
        case .l4SubSubsection:
            return .system(size: 12.5, weight: .medium)
        case .controlLabel, .controlValue:
            return .system(size: 13, weight: .regular)
        case .controlValueNumeric:
            return .system(size: 13, weight: .regular, design: .monospaced)
        }
    }

    var foregroundColor: Color {
        Color(NSColor.labelColor)
    }

    var textOpacity: Double {
        self == .l4SubSubsection ? 0.95 : 1
    }

    var headerPadding: EdgeInsets {
        switch self {
        case .l1MainHeader:
            return EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        case .l2SectionHeader:
            return EdgeInsets(top: 9, leading: 13, bottom: 9, trailing: 13)
        case .l3Subsection:
            return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        case .l4SubSubsection:
            return EdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        case .controlLabel, .controlValue, .controlValueNumeric:
            return EdgeInsets()
        }
    }

    var letterSpacing: CGFloat {
        switch self {
        case .l1MainHeader:
            return 0.8
        case .l2SectionHeader:
            return 0.4
        case .l3Subsection:
            return 0.2
        case .l4SubSubsection:
            return 0.1
        case .controlLabel:
            return 0.2
        default:
            return 0
        }
    }

    var baselineOffset: CGFloat {
        switch self {
        case .l1MainHeader:
            return 0.5
        case .l2SectionHeader:
            return 0.3
        case .l3Subsection:
            return 0.1
        default:
            return 0
        }
    }
}

// MARK: - Hierarchical Container Components

struct ControlRowContainer<Content: View>: View {
    let content: Content
    let level: InspectorFontLevel
    let unionBase: String?
    let uniqueID: String?

    @Environment(\.inspectorGlassNamespace) private var glassNamespace
    @Environment(\.inspectorGlassUnionBase) private var inheritedGlassUnionBase

    @State private var isHovered = false
    private let hoverScale: CGFloat = 1.02
    private let hoverAnimation: Animation = .easeOut(duration: 0.12)

    init(
        unionBase: String? = nil,
        uniqueID: String? = nil,
        level: InspectorFontLevel = .controlLabel,
        @ViewBuilder content: () -> Content
    ) {
        self.level = level
        self.unionBase = unionBase
        self.uniqueID = uniqueID
        self.content = content()
    }

    var body: some View {
        let unionID = unionBase ?? inheritedGlassUnionBase ?? "inspector.unified"
        let effectID = "\(unionID).control.\(uniqueID ?? "default")"
        let rowBase = content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, leadingInset(for: level))
            .padding(.vertical, 4)

        let glassedRow: AnyView
        let glassed = rowBase
            .glassEffect(
                glassStyle(for: level, interactive: false),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .glassEffectTransition(glassTransition(for: level))

        if let namespace = glassNamespace {
            glassedRow = AnyView(
                glassed
                    .glassEffectID(effectID, in: namespace)
                    .glassEffectUnion(id: unionID, namespace: namespace)
            )
        } else {
            glassedRow = AnyView(glassed)
        }

        return glassedRow
            .scaleEffect(isHovered ? hoverScale : 1.0)
            .onHover { hovering in
                withAnimation(hoverAnimation) {
                    isHovered = hovering
                }
            }
    }

    private func leadingInset(for level: InspectorFontLevel) -> CGFloat {
        switch level {
        case .l1MainHeader, .l2SectionHeader:
            return 0
        case .l3Subsection:
            return 14
        case .l4SubSubsection:
            return 28
        case .controlLabel, .controlValue, .controlValueNumeric:
            return 42
        }
    }
}

private struct InspectorGlassNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

private struct InspectorGlassUnionBaseKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var inspectorGlassNamespace: Namespace.ID? {
        get { self[InspectorGlassNamespaceKey.self] }
        set { self[InspectorGlassNamespaceKey.self] = newValue }
    }

    var inspectorGlassUnionBase: String? {
        get { self[InspectorGlassUnionBaseKey.self] }
        set { self[InspectorGlassUnionBaseKey.self] = newValue }
    }
}

// MARK: - Glass helpers

private func glassTint(for level: InspectorFontLevel, parentExpanded: Bool) -> Color? {
    let baseOpacity: CGFloat

    switch level {
    case .l2SectionHeader:
        baseOpacity = 0.35
    case .l3Subsection:
        baseOpacity = 0.25
    case .l4SubSubsection:
        baseOpacity = 0.2
    case .controlLabel, .controlValue, .controlValueNumeric:
        baseOpacity = 0.2
    case .l1MainHeader:
        return nil
    }

    let opacity = parentExpanded ? baseOpacity : 0

    switch level {
    case .l2SectionHeader, .l3Subsection:
        return Color(NSColor.controlAccentColor).opacity(opacity)
    case .l4SubSubsection:
        return Color(NSColor.secondaryLabelColor).opacity(opacity)
    case .controlLabel, .controlValue, .controlValueNumeric:
        return Color(NSColor.windowBackgroundColor).opacity(opacity)
    case .l1MainHeader:
        return nil
    }
}

private func glassStyle(for level: InspectorFontLevel, interactive: Bool, parentExpanded: Bool = true) -> Glass {
    var glass = Glass.regular

    if let tint = glassTint(for: level, parentExpanded: parentExpanded) {
        glass = glass.tint(tint)
    }

    if interactive {
        glass = glass.interactive()
    }

    return glass
}

private func glassTransition(for level: InspectorFontLevel) -> GlassEffectTransition {
    switch level {
    case .l1MainHeader, .l2SectionHeader:
        // Section headers sit farther apart, so use materialize to avoid
        // stretching artifacts when collapsing/expanding.
        return .materialize
    default:
        return .matchedGeometry
    }
}

// MARK: - Labeled Control Helpers

extension View {
    func controlLabelStyle() -> some View {
        let level = InspectorFontLevel.controlLabel

        return font(level.font)
            .foregroundColor(level.foregroundColor)
            .opacity(level.textOpacity)
            .tracking(level.letterSpacing)
    }

    func controlValueStyle(numeric: Bool = false) -> some View {
        let level: InspectorFontLevel = numeric ? .controlValueNumeric : .controlValue
        let color = numeric ? Color(NSColor.labelColor) : level.foregroundColor

        return font(level.font)
            .foregroundColor(color)
            .opacity(level.textOpacity)
            .tracking(level.letterSpacing)
    }
}
