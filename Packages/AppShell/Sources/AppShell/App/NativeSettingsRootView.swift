//
//  NativeSettingsRootView.swift
//  InvoicingApplication
//
//  Root view for the native Settings scene; hosts existing Feature.Settings columns.
//

import SwiftUI
import SwiftData
import SharedUI
import Feature_Settings

struct NativeSettingsRootView: View {
    @State private var settingsWorkspaceViewModel = SettingsWorkspaceViewModel()
    @SceneStorage("Settings.ColumnVisibility") private var columnVisibilityRaw = "automatic"


    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { NavigationSplitViewStateCodec.decodeColumnVisibility(columnVisibilityRaw) },
            set: { newValue in
                let encoded = NavigationSplitViewStateCodec.encodeColumnVisibility(newValue)
                guard columnVisibilityRaw != encoded else { return }
                columnVisibilityRaw = encoded
            }
        )
    }

    var body: some View {
        NavigationSplitView(
            columnVisibility: columnVisibility
        ) {
            SettingsContentColumn(viewModel: settingsWorkspaceViewModel)
                .standardPanelShell(role: .contentPanel)
                .navigationSplitViewColumnWidth(
                    min: StyleGuide.Dimensions.inspectorWidthMin,
                    ideal: StyleGuide.Dimensions.inspectorWidthIdeal,
                    max: StyleGuide.Dimensions.inspectorWidthMax
                )
        } detail: {
            SettingsDetailColumn(viewModel: settingsWorkspaceViewModel)
                .standardPanelShell(role: .detailPanel)
        }
        .navigationTitle("Settings")
        .frame(
            minWidth: StyleGuide.Dimensions.workspaceSettingsSceneMinWidth,
            minHeight: StyleGuide.Dimensions.workspaceSettingsSceneMinHeight
        )
    }
}
