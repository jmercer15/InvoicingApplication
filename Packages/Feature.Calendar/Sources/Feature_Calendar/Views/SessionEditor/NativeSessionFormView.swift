//
//  NativeSessionFormView.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Native Form Implementation
//
import SwiftUI
import SwiftData
import PersistenceModels
import SharedUI
import Observation

/// Native session form following Mario Guzman's layout guidelines
/// Uses native SwiftUI controls with calendar-style glass morphism effects
struct NativeSessionFormView: View {
    @Bindable var viewModel: NewSessionViewModel

    @State private var selectedRepeatOption: RepeatOption? = .never
    @State private var showAddressEditingSheet = false
    @State private var validationErrors: [String: String] = [:]

    private var clientPickerOptions: [Client] {
        var options = viewModel.availableClients
        if let selectedClient = viewModel.selectedClient,
           !options.contains(where: { $0.id == selectedClient.id }) {
            options.insert(selectedClient, at: 0)
        }
        return options
    }

    private var servicePickerOptions: [ClientService] {
        var options = viewModel.availableServices
        if let selectedService = viewModel.selectedClientService,
           !options.contains(where: { $0.id == selectedService.id }) {
            options.insert(selectedService, at: 0)
        }
        return options
    }

    private var clientPickerSelection: Binding<UUID?> {
        Binding(
            get: { viewModel.formModel.selectedClientID },
            set: { newID in viewModel.updateSelectedClientID(newID) }
        )
    }

    private var servicePickerSelection: Binding<UUID?> {
        Binding(
            get: { viewModel.formModel.selectedClientServiceID },
            set: { newID in viewModel.updateSelectedClientServiceID(newID) }
        )
    }

    private var missingSelectedClientID: UUID? {
        guard let selectedClientID = viewModel.formModel.selectedClientID else { return nil }
        return clientPickerOptions.contains(where: { $0.id == selectedClientID }) ? nil : selectedClientID
    }

    private var missingSelectedServiceID: UUID? {
        guard let selectedServiceID = viewModel.formModel.selectedClientServiceID else { return nil }
        return servicePickerOptions.contains(where: { $0.id == selectedServiceID }) ? nil : selectedServiceID
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NativeSessionFormHeaderView(isEditing: viewModel.isEditing)
                    .padding(.bottom, StyleGuide.Dimensions.paddingSheetContent)

                VStack(spacing: FormSectionTokens.sectionStackSpacing) {
                    NativeSessionFormBasicInformationSection(
                        viewModel: viewModel,
                        validationErrors: $validationErrors
                    )
                    NativeSessionFormClientServiceSection(
                        viewModel: viewModel,
                        clientPickerOptions: clientPickerOptions,
                        servicePickerOptions: servicePickerOptions,
                        clientPickerSelection: clientPickerSelection,
                        servicePickerSelection: servicePickerSelection,
                        missingSelectedClientID: missingSelectedClientID,
                        missingSelectedServiceID: missingSelectedServiceID
                    )
                    NativeSessionFormStatusSection(viewModel: viewModel)
                    NativeSessionFormRecurrenceSection(
                        viewModel: viewModel,
                        selectedRepeatOption: $selectedRepeatOption
                    )
                    NativeSessionFormLocationSection(
                        viewModel: viewModel,
                        showAddressEditingSheet: $showAddressEditingSheet
                    )
                    NativeSessionFormNotesSection(viewModel: viewModel)
                    NativeSessionFormSupportLogSection(viewModel: viewModel)
                }
                .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    StyleGuide.Colors.background,
                    StyleGuide.Colors.background.opacity(0.95),
                    StyleGuide.Colors.background.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(minWidth: StyleGuide.Dimensions.sessionSheetMinWidth, minHeight: StyleGuide.Dimensions.sessionSheetMinHeight)
        .onAppear {
            selectedRepeatOption = NativeSessionFormRecurrenceMapping.repeatPickerValue(for: viewModel.formModel)
        }
    }
}
