import SwiftUI
import Core
import PersistenceModels
import DataInterfaces
import SharedUI
import SwiftData

struct ServiceAssignmentSheetContainer: View {
    let client: Client
    let alreadySelectedItems: [NDISItem]
    let onProceed: ([NDISItem]) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.referenceDataFetching) private var referenceDataFetching
    @State private var isLoaded = false

    var body: some View {
        Group {
            if isLoaded, let referenceDataFetching {
                ServiceAssignmentSheetView(
                    viewModel: ServiceAssignmentViewModel(
                        client: client,
                        modelContext: modelContext,
                        referenceDataFetcher: referenceDataFetching
                    ),
                    alreadySelectedItems: alreadySelectedItems,
                    onProceed: onProceed
                )
            } else if isLoaded {
                ContentUnavailableView(
                    "Catalog Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Reference data services are unavailable right now.")
                )
            } else {
                LoadingView()
                    .frame(
                        minWidth: StyleGuide.Dimensions.sheetMinWidth,
                        idealWidth: StyleGuide.Dimensions.sheetIdealWidth,
                        minHeight: StyleGuide.Dimensions.sheetMinHeight,
                        idealHeight: StyleGuide.Dimensions.sheetIdealHeight
                    )
                    .task {
                        // Small delay to let the sheet presentation animation finish smoothly
                        guard await Task.waitUnlessCancelled(for: .milliseconds(150)) else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            isLoaded = true
                        }
                    }
            }
        }
    }
}
