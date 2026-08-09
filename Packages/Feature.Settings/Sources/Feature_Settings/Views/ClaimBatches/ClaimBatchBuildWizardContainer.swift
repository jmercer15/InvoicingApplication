import SwiftUI
import Core
import SharedUI

struct ClaimBatchBuildWizardContainer: View {
    @Bindable var viewModel: ClaimBatchesViewModel
    let initialDraftIds: Set<UUID>?
    
    @State private var isLoaded = false
    
    init(viewModel: ClaimBatchesViewModel, initialDraftIds: Set<UUID>? = nil) {
        self.viewModel = viewModel
        self.initialDraftIds = initialDraftIds
    }
    
    var body: some View {
        Group {
            if isLoaded {
                ClaimBatchBuildWizardView(viewModel: viewModel, initialDraftIds: initialDraftIds)
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
                .frame(minWidth: StyleGuide.Dimensions.settingsSheetMinWidth, minHeight: StyleGuide.Dimensions.settingsSheetMinHeight)
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
