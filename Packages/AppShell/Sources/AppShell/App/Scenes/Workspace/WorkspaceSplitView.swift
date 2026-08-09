import SwiftUI
import Core
import SharedUI

private enum WorkspaceSplitShellIdentity {
    static let workspace = "workspace-split-shell"
}

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
        let usesContentColumn = activeFeature.splitStyle == .workspacePlusContentDetail
        let visibility = Binding(
            get: { nav.columnVisibility },
            set: { newValue in
                guard nav.columnVisibility != newValue else { return }
                nav.columnVisibility = newValue
            }
        )

        NavigationSplitView(columnVisibility: visibility) {
            sidebarColumn(with: widthProfile.sidebar)
        } content: {
            // Unified 3-column shell always declares a content column. Collapse it to
            // zero width for sidebar+detail tabs (Billing Hub, Template Editor, Calendar).
            if usesContentColumn {
                contentColumnThreeColumn(with: widthProfile)
            } else {
                collapsedContentColumn
            }
        } detail: {
            detailColumn(with: widthProfile)
        }
        .id(WorkspaceSplitShellIdentity.workspace)
    }

    /// Keeps the stable split shell while removing residual content-column chrome.
    private var collapsedContentColumn: some View {
        Color.clear
            .accessibilityHidden(true)
            .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
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
        let usesContentColumn = widthProfile.content.map { $0.ideal > 0 } ?? false
        let role: PanelShellRole = usesContentColumn ? .detailPanel : .singlePanel
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
