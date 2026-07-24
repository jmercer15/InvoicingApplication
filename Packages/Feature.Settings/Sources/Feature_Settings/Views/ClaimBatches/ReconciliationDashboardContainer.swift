import SwiftUI
import Core
import SharedUI

struct ReconciliationDashboardContainer: View {
    let batchId: UUID
    @Bindable var viewModel: ClaimBatchesViewModel
    var onOpenDraft: ((UUID) -> Void)?
    
    @State private var isLoaded = false
    
    var body: some View {
        Group {
            if isLoaded {
                ReconciliationDashboardView(batchId: batchId, viewModel: viewModel, onOpenDraft: onOpenDraft)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color("Background", bundle: .sharedUI),
                            Color("Background", bundle: .sharedUI).opacity(0.95),
                            Color("Background", bundle: .sharedUI).opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                .frame(minWidth: StyleGuide.Dimensions.settingsSheetStandardMinWidth, minHeight: StyleGuide.Dimensions.settingsSheetStandardMinHeight)
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
