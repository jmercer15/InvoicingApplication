#if DEBUG
import SwiftUI

#Preview("Empty State") {
    EmptyStateView(
        icon: "tray",
        title: "No Invoices",
        message: "Create an invoice or adjust filters to see results."
    )
    .frame(width: 360, height: 260)
    .padding()
}

#Preview("Loading") {
    LoadingView("Loading invoices...")
        .frame(width: 320, height: 220)
        .padding()
}

#Preview("Toolbar Controls") {
    HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
        AppToolbarPrimaryCreateButton("New Invoice", systemImage: "doc.badge.plus", help: "Create invoice") {}
        AppToolbarIconButton(systemName: "line.3.horizontal.decrease.circle", help: "Filter") {}
        AppToolbarToggleButton(systemName: "sidebar.left", isOn: true, help: "Toggle sidebar") {}
        AppToolbarHistoryNavigationControlGroup(
            canNavigateBack: true,
            canNavigateForward: false,
            navigateBack: {},
            navigateForward: {}
        )
    }
    .padding()
}

#Preview("Info Chips") {
    HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
        InfoChip(icon: "dollarsign.circle.fill", label: "Revenue", value: "$4,820", color: .green)
        InfoChip(icon: "clock.fill", label: "Outstanding", value: "6", color: .orange)
    }
    .padding()
}

#Preview("Sidebar Rows") {
    VStack(alignment: .leading, spacing: 4) {
        SidebarItemRow(icon: "person.2", title: "Clients", isSelected: true)
        SidebarItemRow(icon: "calendar", title: "Calendar")
        SidebarItemRow(icon: "doc.text", title: "Invoices")
    }
    .frame(width: 240)
    .padding()
}
#endif
