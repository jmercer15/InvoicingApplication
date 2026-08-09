#if DEBUG
import SwiftUI
import SharedUI

#Preview("Settings Row") {
    SettingsRow(label: "Preview") {
        Text("Value")
    }
    .padding()
}

#Preview("Settings Sidebar") {
    @Previewable @State var selectedSection: SettingsView.SettingsSection? = .profile

    SettingsView(selectedSection: $selectedSection)
        .frame(width: 300, height: 420)
}

#Preview("Settings Columns") {
    let viewModel = SettingsWorkspaceViewModel()

    NavigationSplitView {
        SettingsContentColumn(viewModel: viewModel)
            .frame(minWidth: 240)
    } detail: {
        SettingsDetailColumn(viewModel: viewModel)
            .frame(minWidth: 520)
    }
    .frame(width: 900, height: 560)
}

#Preview("NDIS Billing Settings") {
    NDISBillingSettingsView()
        .frame(width: 720, height: 520)
}
#endif
