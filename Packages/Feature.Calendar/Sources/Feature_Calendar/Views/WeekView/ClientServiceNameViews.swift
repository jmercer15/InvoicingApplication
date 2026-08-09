import SwiftUI
import SharedUI
import Observation

// MARK: - Helper Views for Client/Service Labels

struct ClientNameView: View {
    let clientId: UUID
    @Bindable var viewModel: CalendarViewModel
    var fontSize: CGFloat = StyleGuide.Dimensions.fontSizeXSmall
    var textColor: Color = StyleGuide.Colors.textSecondary
    var body: some View {
        Group {
            if let name = viewModel.clientName(for: clientId), !name.isEmpty {
                HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                    Image(systemName: "person.fill")
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

struct ServiceNameView: View {
    let serviceId: UUID
    @Bindable var viewModel: CalendarViewModel
    var fontSize: CGFloat = StyleGuide.Dimensions.fontSizeXSmall
    var textColor: Color = StyleGuide.Colors.textSecondary
    var body: some View {
        Group {
            if let name = viewModel.serviceName(for: serviceId), !name.isEmpty {
                HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                    Image(systemName: "tag.fill")
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
