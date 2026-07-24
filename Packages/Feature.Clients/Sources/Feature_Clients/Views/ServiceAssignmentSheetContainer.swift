import SwiftUI
import Core
import Data
import SharedUI

struct ServiceAssignmentSheetContainer: View {
    let client: Client
    let alreadySelectedItems: [NDISItem]
    let onProceed: ([NDISItem]) -> Void
    
    @State private var isLoaded = false
    
    var body: some View {
        Group {
            if isLoaded {
                ServiceAssignmentSheetView(
                    client: client,
                    alreadySelectedItems: alreadySelectedItems,
                    onProceed: onProceed
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
                        try? await Task.sleep(for: .milliseconds(150))
                        withAnimation(.easeOut(duration: 0.15)) {
                            isLoaded = true
                        }
                    }
            }
        }
    }
}
