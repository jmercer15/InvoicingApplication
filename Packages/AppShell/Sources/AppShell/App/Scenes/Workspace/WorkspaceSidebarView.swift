import SwiftUI
import AppKit
import Core
import SharedUI

struct WorkspaceSidebarView: View {
    @Binding var selection: AppTab

    let minWidth: CGFloat

    static func preferredMinimumWidth() -> CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let maxTextWidth = AppTab.allCases
            .map { ($0.title as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return 20 + 8 + maxTextWidth + 24 + 16
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(AppTab.allCases) { feature in
                    SidebarItemRow(
                        icon: feature.iconName,
                        title: feature.title,
                        isSelected: selection == feature
                    )
                    .tag(feature)
                }
            } header: {
                featuresHeader
            }
        }
        .listStyle(.sidebar)
        .applyDefaultSidebarRowSize()
        .navigationTitle("Workspace")
        .frame(minWidth: minWidth)
    }

    private var featuresHeader: some View {
        Text("Features")
            .font(.caption)
            .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
    }
}

private extension View {
    @ViewBuilder
    func applyDefaultSidebarRowSize() -> some View {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            self.environment(\.sidebarRowSize, .medium)
        } else {
            self
        }
        #elseif os(iOS)
        if #available(iOS 17.0, *) {
            self.environment(\.sidebarRowSize, .medium)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
