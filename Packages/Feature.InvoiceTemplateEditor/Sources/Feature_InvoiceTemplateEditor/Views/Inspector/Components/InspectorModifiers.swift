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

    private let cornerRadius: CGFloat = 8

    init(
        level: InspectorFontLevel = .controlLabel,
        @ViewBuilder content: () -> Content
    ) {
        self.level = level
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassEffect(
                .regular.tint(Color(NSColor.windowBackgroundColor)),
                in: .rect(cornerRadius: cornerRadius)
            )
            .glassEffectTransition(.materialize)
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
