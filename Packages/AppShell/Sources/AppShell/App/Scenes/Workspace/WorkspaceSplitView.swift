import SwiftUI
import Core
import SharedUI

struct WorkspaceSplitView: View {
    let features: WorkspaceFeatureRegistries
    let navigationManager: AppNavigationManager
    let sidebarMinWidth: CGFloat

    private var nav: AppNavigationManager { navigationManager }

    var body: some View {
        splitView
    }

    @ViewBuilder
    private var splitView: some View {
        let activeFeature = nav.selectedTab
        let widthProfile = activeFeature.widthProfile
        let visibility = Binding(
            get: { nav.columnVisibility },
            set: { newValue in
                guard nav.columnVisibility != newValue else { return }
                nav.columnVisibility = newValue
            }
        )
        switch activeFeature.splitStyle {
        case .workspacePlusDetail:
            NavigationSplitView(columnVisibility: visibility) {
                sidebarColumn(with: widthProfile.sidebar)
            } detail: {
                detailColumn(with: widthProfile)
            }
            .id(SplitViewShellStyle.workspacePlusDetail)

        case .workspacePlusContentDetail:
            NavigationSplitView(columnVisibility: visibility) {
                sidebarColumn(with: widthProfile.sidebar)
            } content: {
                contentColumnThreeColumn(with: widthProfile)
            } detail: {
                detailColumn(with: widthProfile)
            }
            .id(SplitViewShellStyle.workspacePlusContentDetail)
        }
    }

    private func sidebarColumn(with width: SplitViewColumnWidthProfile) -> some View {
        WorkspaceSidebarView(
            selection: Binding(
                get: { nav.selectedTab },
                set: { nav.selectTab($0) }
            ),
            minWidth: sidebarMinWidth
        )
        .navigationSplitViewColumnWidth(
            min: width.min,
            ideal: width.ideal,
            max: width.max
        )
    }

    private func contentColumnThreeColumn(with widthProfile: SplitViewWidthProfile) -> some View {
        WorkspaceFeatureContentColumn(
            feature: nav.selectedTab,
            features: features,
            navigationManager: navigationManager
        )
        .id(nav.selectedTab)
        .standardPanelShell(role: .contentPanel)
        .overlay(
            HStack {
                Spacer()
                Rectangle()
                    .fill(StyleGuide.Colors.border)
                    .frame(width: StyleGuide.Dimensions.hairlineWidth)
            }
        )
        .navigationSplitViewColumnWidth(
            min: widthProfile.content?.min ?? StyleGuide.Dimensions.workspaceContentColumnMin,
            ideal: widthProfile.content?.ideal ?? StyleGuide.Dimensions.workspaceContentColumnIdeal,
            max: widthProfile.content?.max
        )
    }

    @ViewBuilder
    private func detailColumn(with widthProfile: SplitViewWidthProfile) -> some View {
        let role: PanelShellRole = widthProfile.content == nil ? .singlePanel : .detailPanel
        let detailColumn = WorkspaceFeatureDetailColumn(
            feature: nav.selectedTab,
            features: features,
            navigationManager: navigationManager
        )

        detailColumn
        .standardPanelShell(role: role)
        .navigationSplitViewColumnWidth(
            min: widthProfile.detail.min,
            ideal: widthProfile.detail.ideal,
            max: widthProfile.detail.max
        )
    }

}
