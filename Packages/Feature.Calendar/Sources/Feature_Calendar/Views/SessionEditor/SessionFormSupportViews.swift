import SwiftUI
import PersistenceModels
import SharedUI

enum RepeatOption: String, CaseIterable, Identifiable {
    case never = "Never"
    case everyDay = "Every Day"
    case everyWeek = "Every Week"
    case every2Weeks = "Every 2 Weeks"
    case everyMonth = "Every Month"
    case everyYear = "Every Year"
    case custom = "Custom..."

    var id: String { rawValue }
}

struct SessionAddressDisplayView: View {
    let address: Address?

    var body: some View {
        Group {
            if let address = address {
                Text(address.fullFormattedAddress)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                    .font(StyleGuide.Typography.itemSubtitle)
            } else {
                Text("No address")
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                    .font(StyleGuide.Typography.itemSubtitle)
            }
        }
    }
}
