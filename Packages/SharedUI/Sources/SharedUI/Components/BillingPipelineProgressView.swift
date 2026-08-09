import PersistenceModels
import SwiftUI

/// Presentation-only stages shared by Calendar, Billing Hub, and Invoice Editor.
/// Keeps cross-feature workflow context consistent without coupling feature state.
public enum BillingPipelineStage: Int, CaseIterable, Identifiable, Sendable {
    case session
    case prepare
    case review
    case send
    case payment
    case paid

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .session: "Session"
        case .prepare: "Prepare"
        case .review: "Review"
        case .send: "Send"
        case .payment: "Payment"
        case .paid: "Paid"
        }
    }

    public var symbolName: String {
        switch self {
        case .session: "calendar"
        case .prepare: "rectangle.stack"
        case .review: "doc.text.magnifyingglass"
        case .send: "paperplane"
        case .payment: "clock"
        case .paid: "checkmark.seal.fill"
        }
    }
}

public struct BillingPipelineProgressView: View {
    private let currentStage: BillingPipelineStage
    private let accent: Color

    public init(
        currentStage: BillingPipelineStage,
        accent: Color = .accentColor
    ) {
        self.currentStage = currentStage
        self.accent = accent
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            progressContent(showsLabels: true)
            progressContent(showsLabels: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Billing progress, step \(currentStage.rawValue + 1) of \(BillingPipelineStage.allCases.count), \(currentStage.title)"
        )
    }

    private func progressContent(showsLabels: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(BillingPipelineStage.allCases.enumerated()), id: \.element.id) { index, stage in
                stageView(stage, showsLabel: showsLabels)

                if index < BillingPipelineStage.allCases.count - 1 {
                    connector(after: stage)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stageView(_ stage: BillingPipelineStage, showsLabel: Bool) -> some View {
        let isCurrent = stage == currentStage
        let isComplete = stage.rawValue < currentStage.rawValue
        let color = isComplete ? ColorSystem.Status.success : (isCurrent ? accent : StyleGuide.Colors.textSecondary)

        return VStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
            Image(systemName: isComplete ? "checkmark" : stage.symbolName)
                .font(.system(size: StyleGuide.Dimensions.fontSizeXSmall, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(
                    color.opacity(isCurrent || isComplete ? 0.14 : 0.06),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .strokeBorder(color.opacity(isCurrent ? 0.55 : 0.18), lineWidth: isCurrent ? 1.5 : 1)
                }

            if showsLabel {
                Text(stage.title)
                    .font(isCurrent ? StyleGuide.Typography.nano : StyleGuide.Typography.nanoMedium)
                    .foregroundStyle(isCurrent ? StyleGuide.Colors.text : StyleGuide.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: showsLabel ? 48 : 28)
    }

    private func connector(after stage: BillingPipelineStage) -> some View {
        let isComplete = stage.rawValue < currentStage.rawValue
        return Capsule()
            .fill(isComplete ? ColorSystem.Status.success.opacity(0.55) : StyleGuide.Colors.border.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: 2)
            .padding(.top, 11)
            .padding(.horizontal, 3)
    }
}
