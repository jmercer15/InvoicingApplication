import SwiftUI
import SwiftData
import Core
import Data
import SharedUI

struct NativeSessionFormClientServiceSection: View {
    @Bindable var viewModel: NewSessionViewModel
    let clientPickerOptions: [Client]
    let servicePickerOptions: [ClientService]
    let clientPickerSelection: Binding<UUID?>
    let servicePickerSelection: Binding<UUID?>
    let missingSelectedClientID: UUID?
    let missingSelectedServiceID: UUID?

    var body: some View {
        GroupBox("Client & Service") {
            VStack(spacing: FormSectionTokens.fieldStackSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Client:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    Picker("", selection: clientPickerSelection) {
                        Text("Select a client").tag(nil as UUID?)
                        if let missingSelectedClientID {
                            Text("Loading selected client...").tag(missingSelectedClientID as UUID?)
                        }
                        ForEach(clientPickerOptions, id: \.id) { client in
                            Text(client.fullName).tag(client.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Service:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    if viewModel.formModel.selectedClientID != nil {
                        Picker("", selection: servicePickerSelection) {
                            Text("Select a service").tag(nil as UUID?)
                            if let missingSelectedServiceID {
                                Text("Loading selected service...").tag(missingSelectedServiceID as UUID?)
                            }
                            ForEach(servicePickerOptions, id: \.id) { service in
                                Text(service.serviceName).tag(service.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack {
                            Text("Select a client first")
                                .foregroundColor(StyleGuide.Colors.textSecondary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(StyleGuide.Colors.textSecondary)
                        }
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact))
                        .disabled(true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
}
