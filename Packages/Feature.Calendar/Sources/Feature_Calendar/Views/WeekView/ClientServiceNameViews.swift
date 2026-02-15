import SwiftUI
import Core
import SharedUI

// MARK: - Helper Views for Async Client/Service Name Fetching

struct ClientNameView: View {
    let clientId: UUID
    @ObservedObject var viewModel: CalendarViewModel
    var fontSize: CGFloat = 11
    var textColor: Color = Color("TextSecondary", bundle: .sharedUI)
    @State private var clientName: String?
    
    var body: some View {
        Group {
            if let name = clientName, !name.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: max(8, fontSize - 1)))
                        .foregroundColor(textColor)
                    Text(name)
                        .font(.system(size: fontSize))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                }
            }
        }
        .task {
            clientName = await viewModel.fetchClientName(for: clientId)
        }
    }
}

struct ServiceNameView: View {
    let serviceId: UUID
    @ObservedObject var viewModel: CalendarViewModel
    var fontSize: CGFloat = 11
    var textColor: Color = Color("TextSecondary", bundle: .sharedUI)
    @State private var serviceName: String?
    
    var body: some View {
        Group {
            if let name = serviceName, !name.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: max(8, fontSize - 1)))
                        .foregroundColor(textColor)
                    Text(name)
                        .font(.system(size: fontSize))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                }
            }
        }
        .task {
            if let service = await viewModel.fetchClientService(for: serviceId) {
                serviceName = service.serviceName
            }
        }
    }
}
