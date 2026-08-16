import SwiftUI
import SharedUI
import Observation

// MARK: - Helper Views for Client/Service Labels

struct CalendarLookupLabelView: View {
    let systemImage: String
    let name: String?
    var fontSize: CGFloat = StyleGuide.Dimensions.fontSizeXSmall
    var textColor: Color = StyleGuide.Colors.textSecondary

    var body: some View {
        Group {
            if let name, !name.isEmpty {
                HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                    Image(systemName: systemImage)
                        .font(CalendarTypography.inlineIcon(size: fontSize))
                        .foregroundStyle(textColor)
                    Text(name)
                        .font(CalendarTypography.gridScaled(fontSize))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct ClientNameView: View {
    let clientId: UUID
    @Bindable var viewModel: CalendarViewModel
    var fontSize: CGFloat = StyleGuide.Dimensions.fontSizeXSmall
    var textColor: Color = StyleGuide.Colors.textSecondary

    var body: some View {
        CalendarLookupLabelView(
            systemImage: "person.fill",
            name: viewModel.clientName(for: clientId),
            fontSize: fontSize,
            textColor: textColor
        )
    }
}

struct ServiceNameView: View {
    let serviceId: UUID
    @Bindable var viewModel: CalendarViewModel
    var fontSize: CGFloat = StyleGuide.Dimensions.fontSizeXSmall
    var textColor: Color = StyleGuide.Colors.textSecondary

    var body: some View {
        CalendarLookupLabelView(
            systemImage: "tag.fill",
            name: viewModel.serviceName(for: serviceId),
            fontSize: fontSize,
            textColor: textColor
        )
    }
}
