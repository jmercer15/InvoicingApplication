import SwiftUI
import SharedUI

/// Optional Int stepper for establishment-fee eligibility.
/// `nil` means do not emit an establishment fee; a set value is consecutive months.
struct ConsecutiveMonthsStepperField: View {
    @Binding var consecutiveMonths: Int?

    private static let monthRange = 1...24

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingSmall) {
            Toggle(
                "Consecutive months (establishment fee)",
                isOn: Binding(
                    get: { consecutiveMonths != nil },
                    set: { isEnabled in
                        consecutiveMonths = isEnabled ? max(consecutiveMonths ?? 1, 1) : nil
                    }
                )
            )

            if consecutiveMonths != nil {
                Stepper(value: monthsBinding, in: Self.monthRange) {
                    Text("\(monthsBinding.wrappedValue) month\(monthsBinding.wrappedValue == 1 ? "" : "s")")
                        .foregroundStyle(StyleGuide.Colors.text)
                }
                .accessibilityLabel("Consecutive months for establishment fee")
            } else {
                Text("Leave off when no establishment fee applies.")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
        }
    }

    private var monthsBinding: Binding<Int> {
        Binding(
            get: { consecutiveMonths ?? 1 },
            set: { consecutiveMonths = min(max($0, Self.monthRange.lowerBound), Self.monthRange.upperBound) }
        )
    }
}
