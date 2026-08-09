import SwiftUI
import Core
import SharedUI

struct TravelChargeReviewContainer: View {
    let viewModel: TravelChargeReviewViewModel
    
    @State private var isLoaded = false
    
    var body: some View {
        Group {
            if isLoaded {
                TravelChargeReviewView(viewModel: viewModel)
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
                .frame(minWidth: StyleGuide.Dimensions.settingsSheetLargeMinWidth, minHeight: StyleGuide.Dimensions.settingsTravelReviewMinHeight)
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
