import SwiftUI
import SwiftData
import Core
import MapKit
import Data
import SharedUI
import Observation

struct TravelChargeView: View {

    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: TravelChargeViewModel

    init(viewModel: TravelChargeViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Form {
                Section {
                    Picker("", selection: $viewModel.form.chargeType) {
                        ForEach(TravelChargeSheetChargeType.allCases, id: \.self) { type in
                            Text(String(describing: type)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                switch viewModel.form.chargeType {
                case .standard:
                    standardTravelForm
                case .activityBased:
                    activityBasedForm
                }

                multiParticipantSection
                travelServiceSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(StyleGuide.Colors.background)
        }
        .frame(minWidth: StyleGuide.Dimensions.travelChargeSheetMinWidth, idealWidth: StyleGuide.Dimensions.travelChargeSheetIdealWidth, minHeight: StyleGuide.Dimensions.travelChargeSheetMinHeight)
        .onAppear(perform: {
            setupViewModel()
        })
        .task {
            viewModel.loadData()
        }
        .overlay {
            if viewModel.form.isLoading {
                ProgressView("Loading Services...")
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
            }
        }
    }
    
    func setupViewModel() {
        viewModel.form.setupAndCalculateDistance()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Text("Add Travel Charges")
                    .font(StyleGuide.Typography.sectionTitle)
                    .fontWeight(.bold)
                Text("For: \(viewModel.form.mainSession.title)")
                    .foregroundColor(StyleGuide.Colors.textSecondary)
            }
            Spacer()
            Button("Cancel", role: .cancel, action: { dismiss() })
            Button("Save", action: viewModel.saveTravelCharges)
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.form.canSave)
        }
        .padding()
        .background(StyleGuide.Colors.background)
    }
}
