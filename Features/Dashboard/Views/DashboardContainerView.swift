// /Users/user/Developer/InvoicingApplication/InvoicingApplication/InvoicingApplication/Views/Dashboard/DashboardContainerView.swift
import SwiftUI
import SwiftData

struct DashboardContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var columnVisibility: NavigationSplitViewVisibility

    // Use StateObject for the container ViewModel lifecycle tied to this container
    @StateObject private var containerViewModel: DashboardContainerViewModel

    // Initialize the container ViewModel and columnVisibility
    init(columnVisibility: Binding<NavigationSplitViewVisibility>, modelContext: ModelContext) {
        self._columnVisibility = columnVisibility
        _containerViewModel = StateObject(wrappedValue: DashboardContainerViewModel(context: modelContext, navigationManager: .shared))
    }

    var body: some View {
        DashboardView(containerViewModel: containerViewModel)
            .background(Color.black) // Match Calendar's black background
    }
}
