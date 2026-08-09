import SwiftUI
import SwiftData
import EventKit
import Core
import PersistenceModels
import SharedUI
import WorkspaceUI
import Observation

// Button Styles and Controls moved to SharedComponents/CalendarStylesAndControls.swift

// MARK: - Root calendar shell

struct CalendarView: View {
    @Bindable var viewModel: CalendarViewModel
    @Environment(\.geocodingService) private var geocodingService
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    private let openBillingHub: (([UUID]) -> Void)?

    init(
        viewModel: CalendarViewModel,
        queryRange: (start: Date, end: Date),
        openBillingHub: (([UUID]) -> Void)? = nil
    ) {
        self._viewModel = Bindable(viewModel)
        self.openBillingHub = openBillingHub
    }

    private struct FilterTaskID: Equatable {
        let viewStart: Date
        let viewEnd: Date
        let filterStatuses: Set<String>
        let clientFilterIDs: Set<UUID>
        let showCancelled: Bool
        let searchText: String
        let dataRevision: Int
    }

    private var filterTaskID: FilterTaskID {
        let (start, end) = viewModel.currentViewDateRange
        return FilterTaskID(
            viewStart: start,
            viewEnd: end,
            filterStatuses: viewModel.filterStatuses,
            clientFilterIDs: viewModel.selectedClientFilterIDs,
            showCancelled: viewModel.showCancelledSessions,
            searchText: viewModel.searchText,
            dataRevision: viewModel.dataRevision
        )
    }

    private enum ActivePresentation: String, Identifiable {
        case sessionEditor
        case eventConversion
        case travelCharge
        case recurringModification

        var id: String { rawValue }
    }

    private var activePresentation: Binding<ActivePresentation?> {
        Binding(
            get: {
                if viewModel.selectedSessionInfo != nil { return .sessionEditor }
                if viewModel.eventToConvert != nil { return .eventConversion }
                if viewModel.isShowingTravelChargeSheet { return .travelCharge }
                if viewModel.showingRecurringModificationDialog { return .recurringModification }
                return nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                viewModel.selectedSessionInfo = nil
                viewModel.eventToConvert = nil
                viewModel.dismissTravelChargePresentation()
                viewModel.pendingRecurringModification = nil
                viewModel.showingRecurringModificationDialog = false
            }
        )
    }

    private var operationErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.operationErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.operationErrorMessage = nil
                }
            }
        )
    }

    var body: some View {
        CalendarTabView(viewModel: viewModel)
            .task(id: filterTaskID) {
                viewModel.updateDisplayableItems()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .loadingOverlay(isLoading: viewModel.display.isLoading, message: "Loading calendar...")
            .sheet(item: activePresentation) { presentation in
                switch presentation {
                case .sessionEditor:
                    if let sessionInfo = viewModel.selectedSessionInfo {
                        SessionEditorSheetContainer(
                            viewModel: viewModel,
                            sessionInfo: sessionInfo,
                            onDismiss: { viewModel.selectedSessionInfo = nil },
                            onSave: { editMode, editorViewModel in
                                viewModel.handleSaveFromEditor(with: editMode, viewModel: editorViewModel)
                            },
                            onDelete: { mode, editorViewModel in
                                viewModel.handleDeleteFromEditor(with: mode, viewModel: editorViewModel)
                            }
                        )
                        .fluidSheetTransition()
                    } else {
                        CalendarPresentationUnavailableView(
                            title: "Session Unavailable",
                            message: "This session changed or was removed before the editor opened.",
                            dismiss: { activePresentation.wrappedValue = nil }
                        )
                    }
                case .eventConversion:
                    if let event = viewModel.eventToConvert {
                        EventConversionSheetContainer(
                            viewModel: viewModel,
                            event: event,
                            onDismiss: { viewModel.eventToConvert = nil },
                            onSave: { editMode, editorViewModel in
                                viewModel.handleSaveFromEditor(with: editMode, viewModel: editorViewModel)
                            },
                            onDelete: { mode, editorViewModel in
                                viewModel.handleDeleteFromEditor(with: mode, viewModel: editorViewModel)
                            }
                        )
                        .fluidSheetTransition()
                    } else {
                        CalendarPresentationUnavailableView(
                            title: "Event Unavailable",
                            message: "This calendar event changed or was removed before conversion opened.",
                            dismiss: { activePresentation.wrappedValue = nil }
                        )
                    }
                case .travelCharge:
                    if let session = viewModel.selectedSessionForTravel,
                       viewModel.selectedInstanceStartDateForTravel != nil,
                       let geo = geocodingService {
                        TravelChargeView(
                            viewModel: viewModel.makeTravelChargeViewModel(
                                mainSession: session,
                                daySessions: viewModel.travelChargeDaySessions,
                                geocodingService: geo,
                                onSave: {
                                    viewModel.updateDisplayableItems()
                                    viewModel.bulkOperationFeedback = CalendarBulkOperationFeedback(
                                        message: "Travel charge saved. Billing Hub will include it when this session is invoiced.",
                                        severity: .success
                                    )
                                    viewModel.dismissTravelChargePresentation()
                                }
                            )
                        )
                    } else if geocodingService == nil {
                        CalendarPresentationUnavailableView(
                            title: "Travel Tools Unavailable",
                            message: "Geocoding is unavailable, so travel distance can’t be calculated right now.",
                            dismiss: { activePresentation.wrappedValue = nil }
                        )
                    } else {
                        CalendarPresentationUnavailableView(
                            title: "Session Unavailable",
                            message: "This session changed or was removed before travel charges opened.",
                            dismiss: { activePresentation.wrappedValue = nil }
                        )
                    }
                case .recurringModification:
                    RecurringScopePickerSheet(
                        title: "Apply Recurring Change",
                        options: viewModel.recurringModificationModes,
                        isDestructive: false,
                        label: { $0.title },
                        detail: { $0.detailText(isDelete: false) },
                        recommended: viewModel.recommendedRecurringModificationMode
                    ) { mode in
                        viewModel.executeRecurringModification(with: mode)
                    }
                }
            }
            .alert("Calendar Action Failed", isPresented: operationErrorIsPresented) {
                Button("OK", role: .cancel) {
                    viewModel.operationErrorMessage = nil
                }
            } message: {
                Text(viewModel.operationErrorMessage ?? "")
            }
            .confirmationDialog(
                "Session Linked to Invoice",
                isPresented: Binding(
                    get: { viewModel.pendingInvoicedSessionAction != nil },
                    set: { isPresented in
                        if !isPresented { viewModel.cancelPendingInvoicedSessionAction() }
                    }
            ),
            titleVisibility: .visible,
            presenting: viewModel.pendingInvoicedSessionAction
        ) { action in
                if let invoiceID = action.invoiceID,
                   let openBillingHub {
                    Button("Open Invoice in Billing Hub") {
                        viewModel.cancelPendingInvoicedSessionAction()
                        openBillingHub([invoiceID])
                    }
                }
                Button(
                    action.confirmTitle,
                    role: action.isDestructive ? .destructive : nil
                ) {
                    viewModel.confirmPendingInvoicedSessionAction()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelPendingInvoicedSessionAction()
                }
            } message: { action in
                Text(action.message)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    if let feedback = viewModel.bulkOperationFeedback {
                        CalendarBulkOperationFeedbackBanner(
                            feedback: feedback,
                            continueInBillingHub: !feedback.billingHubHandoffSessionIDs.isEmpty
                                ? openBillingHub.map { handler in
                                    {
                                        let focusIDs = feedback.billingHubHandoffSessionIDs
                                        viewModel.clearBulkOperationFeedback()
                                        handler(focusIDs)
                                    }
                                }
                                : nil,
                            openBillingHub: feedback.billingHubHandoffSessionIDs.isEmpty
                                && feedback.hasInvoicedSkips
                                ? openBillingHub.map { handler in
                                    {
                                        viewModel.clearBulkOperationFeedback()
                                        handler(feedback.invoicedInvoiceIDs)
                                    }
                                }
                                : nil,
                            dismiss: { viewModel.clearBulkOperationFeedback() }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: feedback) {
                            guard !voiceOverEnabled else { return }
                            guard await Task.waitUnlessCancelled(for: .seconds(10)) else { return }
                            if viewModel.bulkOperationFeedback == feedback {
                                viewModel.clearBulkOperationFeedback()
                            }
                        }
                    }

                    if let message = viewModel.sessionReadyForBillingHubMessage {
                        SessionCompletedNudgeBanner(
                            message: message,
                            completedCount: max(1, viewModel.sessionReadyForBillingHubSessionIDs.count),
                            openBillingHub: openBillingHub.map { openBillingHub in
                                {
                                    let focusIDs = viewModel.sessionReadyForBillingHubSessionIDs
                                    viewModel.clearBillingHubNudge()
                                    openBillingHub(focusIDs)
                                }
                            },
                            dismiss: { viewModel.clearBillingHubNudgeMessage() }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            guard !voiceOverEnabled else { return }
                            guard await Task.waitUnlessCancelled(for: .seconds(10)) else { return }
                            if viewModel.sessionReadyForBillingHubMessage == message {
                                viewModel.clearBillingHubNudgeMessage()
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .animation(.default, value: viewModel.sessionReadyForBillingHubMessage)
            .animation(.default, value: viewModel.bulkOperationFeedback)
            .appRespectsReduceMotion()
            .onChange(of: viewModel.bulkOperationFeedback) { _, feedback in
                guard voiceOverEnabled, let feedback else { return }
                AppAccessibilityAnnouncement.post(feedback.message)
            }
            .onChange(of: viewModel.sessionReadyForBillingHubMessage) { _, message in
                guard voiceOverEnabled, let message else { return }
                AppAccessibilityAnnouncement.post(
                    "\(message) Next, prepare this session for invoicing in Billing Hub."
                )
            }
    }
}

private struct CalendarPresentationUnavailableView: View {
    let title: String
    let message: String
    let dismiss: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Close", action: dismiss)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)
        }
        .frame(minWidth: 420, minHeight: 260)
    }
}

private struct CalendarBulkOperationFeedbackBanner: View {
    let feedback: CalendarBulkOperationFeedback
    /// Prefer when some sessions completed and need prepare handoff (partial Mark Completed).
    let continueInBillingHub: (() -> Void)?
    /// Fallback when only invoiced skips need review (no completed handoff).
    let openBillingHub: (() -> Void)?
    let dismiss: () -> Void

    private var symbolName: String {
        switch feedback.severity {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.circle.fill"
        }
    }

    private var tint: Color {
        switch feedback.severity {
        case .success: ColorSystem.Status.success
        case .warning: ColorSystem.Status.warning
        case .error: ColorSystem.Status.error
        }
    }

    var body: some View {
        VStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                Image(systemName: symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(feedback.message)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                    if let subtitle = feedback.nextStepSubtitle {
                        Text(subtitle)
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(Color.secondary)
                    }
                }

                Spacer(minLength: StyleGuide.Dimensions.paddingMedium)

                if let continueInBillingHub {
                    Button("Continue in Billing Hub", systemImage: "arrow.right", action: continueInBillingHub)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .help("Open Billing Hub and focus sessions marked Completed")
                        .accessibilityHint("Opens Billing Hub focused on completed sessions ready to prepare.")
                } else if let openBillingHub {
                    Button("Open Billing Hub", action: openBillingHub)
                        .buttonStyle(.bordered)
                        .help("Review invoices linked to the skipped sessions")
                        .accessibilityHint("Opens Billing Hub to review invoice-linked sessions.")
                }

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 28, minHeight: 28)
                .accessibilityLabel("Dismiss")
                .help("Dismiss")
            }

            if feedback.offersBillingHubPrepareStep {
                BillingPipelineProgressView(currentStage: .prepare)
            }
        }
        .padding(StyleGuide.Dimensions.paddingMediumLarge)
        .frame(maxWidth: 540)
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge,
                style: .continuous
            )
            .strokeBorder(tint.opacity(0.22))
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
    }
}

/// Non-blocking nudge shown after a session is marked Completed. Points the user at the next step
/// (Billing Hub) instead of leaving them to discover it on their own; auto-dismisses so it never
/// blocks calendar interaction.
private struct SessionCompletedNudgeBanner: View {
    let message: String
    let completedCount: Int
    let openBillingHub: (() -> Void)?
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(ColorSystem.Status.success)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(message)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(CalendarSessionCompletionFeedback.nextStepSubtitle(completedCount: completedCount))
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: 8)

                if let openBillingHub {
                    Button("Continue in Billing Hub", systemImage: "arrow.right", action: openBillingHub)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityHint("Switches to Billing Hub and focuses this completed session.")
                }

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 28, minHeight: 28)
                .accessibilityLabel("Dismiss")
                .help("Dismiss")
            }

            BillingPipelineProgressView(currentStage: .prepare)
        }
        .padding(StyleGuide.Dimensions.paddingMediumLarge)
        .frame(maxWidth: 540)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge, style: .continuous)
                .strokeBorder(ColorSystem.Status.success.opacity(0.20))
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
    }
}
