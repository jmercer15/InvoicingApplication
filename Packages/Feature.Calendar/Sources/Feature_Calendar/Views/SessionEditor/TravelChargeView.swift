import SwiftUI
import SwiftData
import PersistenceModels
import MapKit
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
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                if let message = viewModel.form.saveReadinessMessage {
                    feedbackSection(
                        message: message,
                        systemImage: "exclamationmark.triangle.fill",
                        color: ColorSystem.Status.warning
                    )
                }

                if let saveError = viewModel.saveError {
                    feedbackSection(
                        message: "Travel charges could not be saved. \(saveError)",
                        systemImage: "xmark.octagon.fill",
                        color: ColorSystem.Status.error
                    )
                }

                switch viewModel.form.chargeType {
                case .standard:
                    standardTravelForm
                case .activityBased:
                    activityBasedForm
                }

                travelEstimateSection

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
                ProgressView("Loading services…")
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
            }
        }
    }
    
    func setupViewModel() {
        viewModel.form.setupAndCalculateDistance()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: StyleGuide.Dimensions.paddingMedium) {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Text("Add Travel Charges")
                    .font(StyleGuide.Typography.sectionTitle)
                    .fontWeight(.bold)
                Text("For: \(viewModel.form.mainSession.title)")
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer()
            Button("Cancel", role: .cancel, action: { dismiss() })
                .keyboardShortcut(.cancelAction)
            Button("Save") {
                viewModel.saveTravelCharges()
            }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.form.canSave)
                .keyboardShortcut(.defaultAction)
                .help(viewModel.form.saveReadinessMessage ?? "Save travel charges")
        }
        .padding()
        .background(StyleGuide.Colors.background)
    }

    private func feedbackSection(
        message: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Section {
            Label(message, systemImage: systemImage)
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
