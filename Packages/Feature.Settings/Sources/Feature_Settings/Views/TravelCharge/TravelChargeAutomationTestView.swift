import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import DataInterfaces
import Core
import SharedUI
import WorkspaceUI

struct TravelChargeAutomationTestView: View {
    @Environment(\.referenceDataFetching) private var referenceDataFetching
    @State var viewModel: TravelChargeAutomationViewModel
    @State var reviewViewModel: TravelChargeReviewViewModel

    @State var unitNumber: String = ""
    @State var streetNumber: String = ""
    @State var streetName: String = ""
    @State var suburb: String = ""
    @State var postcode: String = ""
    @State var state: String = ""
    @State var country: String = ""
    @State var poBox: String = ""

    // New state for review sheet
    @State var showingReviewSheet = false
    @State var showingIntegratedReviewView = false

    struct RefreshTaskID: Equatable {
        let isRunning: Bool
    }
    var refreshTaskID: RefreshTaskID {
        RefreshTaskID(isRunning: viewModel.isRunning)
    }
    
    var maxLabelWidth: CGFloat {
        let labels = ["Address Search:"]
        return labels.map { $0.width() }.max() ?? 120
    }

    @ScaledMetric(relativeTo: .body) var paddingXXLarge = StyleGuide.Dimensions.paddingXXLarge
    @ScaledMetric(relativeTo: .body) var paddingXLarge = StyleGuide.Dimensions.paddingXLarge
    @ScaledMetric(relativeTo: .body) var paddingMedium = StyleGuide.Dimensions.paddingMedium
    @ScaledMetric(relativeTo: .body) var paddingSmall = StyleGuide.Dimensions.paddingSmall
    @ScaledMetric(relativeTo: .body) var cornerRadiusXSmall = StyleGuide.Dimensions.cornerRadiusXSmall
    @ScaledMetric(relativeTo: .body) var cornerRadiusSmall = StyleGuide.Dimensions.cornerRadiusSmall

    public init(
        viewModel: @autoclosure @escaping () -> TravelChargeAutomationViewModel,
        reviewViewModel: @autoclosure @escaping () -> TravelChargeReviewViewModel
    ) {
        _viewModel = State(initialValue: viewModel())
        _reviewViewModel = State(initialValue: reviewViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    headerSection
                    instructionsSection
                }
                .standardSectionStyle()

                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    businessAddressSection
                    addressSearchSection
                }
                .standardSectionStyle()

                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    sessionListSection
                    actionButtonsSection
                }
                .standardSectionStyle()

                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    resultsSection
                }
                .standardSectionStyle()
            }
            .padding(.vertical, paddingXXLarge)
            .padding(.horizontal, paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .scrollIndicators(.visible)
        #endif
        .task(id: refreshTaskID) { @MainActor in
            guard let fetcher = referenceDataFetching else { return }
            await viewModel.loadBootstrapData(using: fetcher)
        }
        .sheet(isPresented: $showingReviewSheet) {
            TravelChargeReviewSheet(
                chargeSummaries: viewModel.testChargeSummaries,
                reviewSummaries: viewModel.testReviewSummaries,
                detailedReviewItems: viewModel.testDetailedReviewItems
            )
        }
        .sheet(isPresented: $showingIntegratedReviewView) {
            TravelChargeReviewContainer(viewModel: reviewViewModel)
        }
    }



    static let cellDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}
