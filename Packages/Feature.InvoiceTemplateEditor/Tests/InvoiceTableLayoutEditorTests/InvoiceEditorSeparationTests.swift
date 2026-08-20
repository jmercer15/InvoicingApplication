import Core
import Data
import Foundation
import PersistenceModels
import SwiftData
import Testing
@testable import InvoiceTableLayoutEditor

@Suite struct InvoiceEditorSeparationTests {
    @Test func RefactorSymbolsRemainInFocusedSourceFiles() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let views = packageRoot.appendingPathComponent("Sources/InvoiceTableLayoutEditor/Views")

        let placements: [(file: String, symbol: String)] = [
            ("InvoiceThemePalette.swift", "struct InvoiceThemePalette"),
            ("InvoiceDocumentDesignTokens.swift", "enum InvoiceDocumentDesign"),
            ("InvoiceFormatters.swift", "enum InvoiceMoneyFormatter"),
            ("InvoiceDocumentHeaderSections.swift", "extension InvoiceDocumentSections"),
            ("InvoiceDocumentPartySections.swift", "extension InvoiceDocumentSections"),
            ("InvoiceDocumentTotalsPaymentSections.swift", "extension InvoiceDocumentSections"),
            ("PreviewCommandScrollZoomMonitor.swift", "PreviewCommandScrollZoomMonitor"),
            ("InvoiceRootViewToolbarActions.swift", "InvoiceRootCommandConfigurator"),
        ]

        for placement in placements {
            let source = try String(
                contentsOf: views.appendingPathComponent(placement.file),
                encoding: .utf8
            )
            #expect(source.contains(placement.symbol))
        }

        #expect(!FileManager.default.fileExists(
            atPath: views.appendingPathComponent("InvoiceFormatting.swift").path
        ))
        let sectionsFacade = try String(
            contentsOf: views.appendingPathComponent("InvoiceDocumentSections.swift"),
            encoding: .utf8
        )
        #expect(sectionsFacade.contains("enum InvoiceDocumentSections"))
        #expect(!sectionsFacade.contains("static func"))

        let rootView = try String(
            contentsOf: views.appendingPathComponent("InvoiceRootView.swift"),
            encoding: .utf8
        )
        #expect(!rootView.contains(".clipped()"))

        let documentActions = try String(
            contentsOf: views.appendingPathComponent("InvoiceEditorInspector+DocumentActions.swift"),
            encoding: .utf8
        )
        let header = try String(
            contentsOf: views.appendingPathComponent("InvoiceEditorInspector+Header.swift"),
            encoding: .utf8
        )
        #expect(documentActions.contains("ToolbarItem(placement: .status)"))
        #expect(documentActions.contains("ToolbarItem(placement: .primaryAction)"))
        #expect(documentActions.contains("AppToolbarUtilityGroup"))
        #expect(!documentActions.contains("TextField(\"Currency\""))
        #expect(header.contains("TextField(\"Currency\""))
        #expect(header.contains("defaultTaxRateField"))
    }

    @MainActor
    @Test func InvoiceWorkspaceUsesCurrentInjectedModelWhenSwitchingInvoices() {
        let templateViewModel = InvoiceEditorViewModel()
        let firstInvoiceViewModel = InvoiceEditorViewModel()
        let secondInvoiceViewModel = InvoiceEditorViewModel()

        #expect(InvoiceRootViewModelOwnership.active(
                invoiceViewModel: firstInvoiceViewModel,
                templateViewModel: templateViewModel
            ) === firstInvoiceViewModel)
        #expect(InvoiceRootViewModelOwnership.active(
                invoiceViewModel: secondInvoiceViewModel,
                templateViewModel: templateViewModel
            ) === secondInvoiceViewModel)
        #expect(InvoiceRootViewModelOwnership.active(
                invoiceViewModel: nil,
                templateViewModel: templateViewModel
            ) === templateViewModel)
    }

    @Test func OperationErrorPresentationReplacesOpaqueSwiftDataDiagnostics() {
        let error = NSError(
            domain: "SwiftData.SwiftDataError",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "The operation couldn’t be completed. (SwiftData.SwiftDataError error 1.)"
            ]
        )

        #expect(InvoiceOperationErrorPresentation.detail(
                for: error,
                fallback: "Invoice data could not be read. Try again."
            ) == "Invoice data could not be read. Try again.")
    }

    @Test func OperationErrorPresentationFindsNestedPersistenceDiagnostics() {
        let persistenceError = NSError(
            domain: "SwiftData.SwiftDataError",
            code: 1
        )
        let wrapper = NSError(
            domain: NSCocoaErrorDomain,
            code: 4099,
            userInfo: [
                NSLocalizedDescriptionKey: "Connection was interrupted.",
                NSUnderlyingErrorKey: persistenceError
            ]
        )

        #expect(InvoiceOperationErrorPresentation.detail(
                for: wrapper,
                fallback: "Invoice data could not be refreshed. Try again."
            ) == "Invoice data could not be refreshed. Try again.")
    }

    @Test func OperationErrorPresentationPreservesMeaningfulDomainCopy() {
        #expect(InvoiceOperationErrorPresentation.detail(
                for: InvoiceModelError.invoiceNotFound,
                fallback: "Invoice data could not be read. Try again."
            ) == "The invoice no longer exists.")
    }

    @MainActor
    @Test func TypedBillingAuthorityKeepsDirectBillingStateConsistent() {
        let viewModel = InvoiceEditorViewModel()

        viewModel.updateBillingAuthority(.client)
        #expect(viewModel.billingAuthority == Core.BillingAuthority.client.rawValue)
        #expect(viewModel.billParticipantDirectly)

        viewModel.updateBillingAuthority(.planManager)
        #expect(viewModel.billingAuthority == Core.BillingAuthority.planManager.rawValue)
        #expect(!(viewModel.billParticipantDirectly))

        viewModel.updateBillingAuthority(nil)
        #expect(viewModel.billingAuthority == "")
        #expect(!(viewModel.billParticipantDirectly))
    }

    @Test func DirectBillingWinsOverStaleAuthorityAtPersistenceBoundary() {
        #expect(InvoiceBillingAuthorityResolution.resolve(
                rawValue: Core.BillingAuthority.planManager.rawValue,
                billsParticipantDirectly: true
            ) == .client)
        #expect(InvoiceBillingAuthorityResolution.resolve(
                rawValue: Core.BillingAuthority.parentGuardian.rawValue,
                billsParticipantDirectly: false
            ) == .parentGuardian)
        #expect(InvoiceBillingAuthorityResolution.resolve(
                rawValue: "invalid authority",
                billsParticipantDirectly: false
            ) == nil)
    }

    @Test func TemplateInvalidInputsRouteToStableRecoverySections() {
        #expect(InvoiceTemplateInvalidInputDestination.section(
                for: InvoiceTemplateGeometryInputID.pageWidth
            ) == .layout)
        #expect(InvoiceTemplateInvalidInputDestination.section(
                for: InvoiceTemplateGeometryInputID.borderWidth
            ) == .design)
        #expect(InvoiceTemplateInvalidInputDestination.section(for: "unknown.template.input") == nil)

        #expect(InvoiceTemplateInvalidInputDestination.firstSection(
                for: [
                    InvoiceTemplateGeometryInputID.borderWidth,
                    InvoiceTemplateGeometryInputID.margin,
                ]
            ) == .layout)
    }

    @Test func BorderlessTemplateClearsNowIrrelevantBorderWidthInput() {
        #expect(InvoiceTemplateInputRelevance.disabledInputIDs(tableStyle: .borderless) == [InvoiceTemplateGeometryInputID.borderWidth])
        #expect(InvoiceTemplateInputRelevance.disabledInputIDs(tableStyle: .ruled).isEmpty)
    }

    @Test func InspectorPresentationPolicySuppressesEquivalentLayoutWrites() {
        #expect(InvoiceEditorInspectorPresentationPolicy.replacement(
                current: true,
                requested: true
            ) == nil)
        #expect(InvoiceEditorInspectorPresentationPolicy.replacement(
                current: false,
                requested: false
            ) == nil)
        #expect(InvoiceEditorInspectorPresentationPolicy.replacement(
                current: false,
                requested: true
            ) == true)
        #expect(InvoiceEditorInspectorPresentationPolicy.replacement(
                current: true,
                requested: false
            ) == false)
    }

    @Test func MoneyFormattingFallsBackForMalformedCurrencyCodes() {
        #expect(InvoiceMoneyFormatter.string(
                for: 125,
                currencyCode: "12!",
                displayStyle: .code
            ) == "AUD 125")
        #expect(InvoiceMoneyFormatter.editableSuffix(
                currencyCode: "invalid",
                displayStyle: .iso
            ) == "AUD")
    }

    @Test func InvoiceTableUsesConciseHeadingsAndUnitLabels() {
        #expect(LineItemTableColumn.date.headerTitle == "Date")
        #expect(LineItemTableColumn.rate.headerTitle == "Rate")
        #expect(InvoiceLineItemsTableStyle.cellHorizontalPadding == 6)
        #expect(InvoiceUnitFormatter.string(for: "Kilometre") == "km")
        #expect(InvoiceUnitFormatter.string(for: "hours") == "hr")
        #expect(InvoiceUnitFormatter.string(for: "Each") == "ea")
        #expect(InvoiceUnitFormatter.string(for: "custom unit") == "custom unit")
    }

    @Test func AtomicPDFWriterReplacesExistingExport() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("InvoicePDFWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source.pdf")
        let destination = directory.appendingPathComponent("Invoice.pdf")
        let originalData = Data("existing export".utf8)
        let replacementData = Data("%PDF replacement".utf8)
        try originalData.write(to: destination)
        try replacementData.write(to: source)

        try InvoicePDFFileWriter.write(source: source, to: destination)

        #expect(try Data(contentsOf: destination) == replacementData)
        #expect(try Data(contentsOf: source) == replacementData)
    }

    @Test func AtomicPDFWriterPreservesExistingExportWhenSourceReadFails() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("InvoicePDFWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let missingSource = directory.appendingPathComponent("missing.pdf")
        let destination = directory.appendingPathComponent("Invoice.pdf")
        let originalData = Data("existing export".utf8)
        try originalData.write(to: destination)

        #expect(throws: (any Error).self) {
            try InvoicePDFFileWriter.write(source: missingSource, to: destination)
        }
        #expect(try Data(contentsOf: destination) == originalData)
    }

    @Test func BusinessMarkUsesFirstTwoNameComponents() {
        #expect(InvoiceBrandMark.initials(for: "Mercer Care Services") == "MC")
        #expect(InvoiceBrandMark.initials(for: "acme") == "A")
        #expect(InvoiceBrandMark.initials(for: "NDIS 24 Seven") == "N2")
    }

    @Test func BusinessMarkHasStableFallbackForMissingSellerName() {
        #expect(InvoiceBrandMark.initials(for: "  —  ") == "IN")
    }

    @Test func DocumentFilenamePreservesReadableSafeInvoiceNumber() {
        #expect(InvoiceDocumentFilename.pdf(invoiceNumber: "INV 2026-001") == "Invoice-INV 2026-001.pdf")
    }

    @Test func DocumentFilenameReplacesPathAndPlatformReservedCharacters() {
        #expect(InvoiceDocumentFilename.pdf(invoiceNumber: "INV/2026:001\\Final?") == "Invoice-INV-2026-001-Final.pdf")
    }

    @Test func DocumentFilenameFallsBackForUnsafeEmptyValue() {
        #expect(InvoiceDocumentFilename.pdf(invoiceNumber: " .\n/\\: ") == "Invoice-Invoice.pdf")
    }

    @Test func DocumentFilenameLimitsInvoiceNumberLength() {
        let filename = InvoiceDocumentFilename.pdf(invoiceNumber: String(repeating: "A", count: 200))

        #expect(filename.count == 96 + "Invoice-.pdf".count)
        #expect(filename.hasSuffix(".pdf"))
    }

    @Test func DocumentFilenameLimitsMultibyteValuesByFilesystemBytes() {
        let filename = InvoiceDocumentFilename.pdf(invoiceNumber: String(repeating: "🧾", count: 100))

        #expect(filename.utf8.count <= 96 + "Invoice-.pdf".utf8.count)
        #expect(filename.hasSuffix(".pdf"))
    }

    @Test func DecimalInputRequiresCompleteLocalizedNumber() {
        let locale = Locale(identifier: "en_AU")

        #expect(InvoiceDecimalInput.parse("12.5", locale: locale) == Decimal(string: "12.5"))
        #expect(InvoiceDecimalInput.parse("1,234.50", locale: locale) == Decimal(string: "1234.5"))
        #expect(InvoiceDecimalInput.parse("12x", locale: locale) == nil)
        #expect(InvoiceDecimalInput.parse("", locale: locale) == nil)
        #expect(InvoiceDecimalInput.parse("  ", locale: locale) == nil)
    }

    @Test func DecimalInputRoundTripsLocalizedDisplay() {
        let locale = Locale(identifier: "de_DE")
        let value = Decimal(string: "1234.5")!
        let display = InvoiceDecimalInput.string(for: value, locale: locale)

        #expect(InvoiceDecimalInput.parse(display, locale: locale) == value)
    }

    @Test func TemplateDoubleInputRequiresCompleteInRangeLocalizedNumber() {
        let locale = Locale(identifier: "en_AU")
        let range = 0.75...2.0

        #expect(InvoiceDoubleInput.parse("1.25", in: range, locale: locale) == 1.25)
        #expect(InvoiceDoubleInput.parse("1.2x", in: range, locale: locale) == nil)
        #expect(InvoiceDoubleInput.parse("0.5", in: range, locale: locale) == nil)
        #expect(InvoiceDoubleInput.parse("2.1", in: range, locale: locale) == nil)
        #expect(InvoiceDoubleInput.parse("", in: range, locale: locale) == nil)
    }

    @Test func TemplateDoubleInputRoundTripsLocalizedDisplay() {
        let locale = Locale(identifier: "de_DE")
        let display = InvoiceDoubleInput.string(for: 1.25, locale: locale)

        #expect(InvoiceDoubleInput.parse(display, in: 0.5...2.0, locale: locale) == 1.25)
    }

    @Test func LatestLoadingRequestOwnsActivityCompletion() {
        var activity = InvoiceLatestRequestActivity()
        let first = UUID()
        let second = UUID()

        activity.begin(first)
        activity.begin(second)
        activity.finish(first)

        #expect(activity.isActive)
        #expect(activity.requestID == second)

        activity.finish(second)
        #expect(!(activity.isActive))
    }

    @Test func InvoiceEditorActivityStateReportsWorkBeforeSavedState() {
        #expect(InvoiceEditorActivityState.resolve(
                isLoading: false,
                isSaving: false,
                isGeneratingDocument: true,
                isPerformingLifecycleOperation: false,
                hasRevisionConflict: false,
                hasUnsavedChanges: false
            ) == .preparingDocument)
        #expect(InvoiceEditorActivityState.preparingDocument.title == "Preparing document…")
        #expect(InvoiceEditorActivityState.preparingDocument.isActive)

        #expect(InvoiceEditorActivityState.resolve(
                isLoading: false,
                isSaving: false,
                isGeneratingDocument: false,
                isPerformingLifecycleOperation: false,
                hasRevisionConflict: true,
                hasUnsavedChanges: false
            ) == .conflict)
        #expect(InvoiceEditorActivityState.conflict.title == "Needs attention")
        #expect(!(InvoiceEditorActivityState.conflict.isActive))
    }

    @Test func InvoiceEditorActivityStateUsesDeterministicPriority() {
        #expect(InvoiceEditorActivityState.resolve(
                isLoading: true,
                isSaving: true,
                isGeneratingDocument: true,
                isPerformingLifecycleOperation: true,
                hasRevisionConflict: true,
                hasUnsavedChanges: true
            ) == .opening)
        #expect(InvoiceEditorActivityState.resolve(
                isLoading: false,
                isSaving: false,
                isGeneratingDocument: false,
                isPerformingLifecycleOperation: false,
                hasRevisionConflict: false,
                hasUnsavedChanges: true
            ) == .unsaved)
    }

    @Test func ProgressPresentationKeepsTemplateAndInvoiceActivitySeparate() {
        #expect(InvoiceEditorProgressPresentation.resolve(
                mode: .template,
                templateSaveState: .saving,
                isCreatingInvoiceFromTemplate: false,
                invoiceActivity: .saved,
                canCancelDocumentAction: false
            ) == InvoiceEditorProgressPresentation(
                title: "Saving template…",
                allowsCancellation: false
            ))
        #expect(InvoiceEditorProgressPresentation.resolve(
                mode: .template,
                templateSaveState: .saving,
                isCreatingInvoiceFromTemplate: true,
                invoiceActivity: .preparingDocument,
                canCancelDocumentAction: true
            ) == InvoiceEditorProgressPresentation(
                title: "Creating invoice…",
                allowsCancellation: false
            ))
        #expect(InvoiceEditorProgressPresentation.resolve(
                mode: .template,
                templateSaveState: .saved,
                isCreatingInvoiceFromTemplate: false,
                invoiceActivity: .opening,
                canCancelDocumentAction: true
            ) == nil)
    }

    @Test func InvoiceProgressPresentationOffersCancellationOnlyForDocumentGeneration() {
        #expect(InvoiceEditorProgressPresentation.resolve(
                mode: .invoice,
                templateSaveState: .saving,
                isCreatingInvoiceFromTemplate: true,
                invoiceActivity: .opening,
                canCancelDocumentAction: true
            ) == InvoiceEditorProgressPresentation(
                title: "Opening…",
                allowsCancellation: false
            ))
        #expect(InvoiceEditorProgressPresentation.resolve(
                mode: .invoice,
                templateSaveState: .saved,
                isCreatingInvoiceFromTemplate: false,
                invoiceActivity: .preparingDocument,
                canCancelDocumentAction: true
            ) == InvoiceEditorProgressPresentation(
                title: "Preparing document…",
                allowsCancellation: true
            ))
        #expect(InvoiceEditorProgressPresentation.resolve(
                mode: .invoice,
                templateSaveState: .failed,
                isCreatingInvoiceFromTemplate: false,
                invoiceActivity: .unsaved,
                canCancelDocumentAction: true
            ) == nil)
    }

    @Test func PaginationMeasurementsCollapseSubpixelLayoutNoise() {
        #expect(InvoicePaginationMeasurementStability.normalizedHeight(100.24) == 100)
        #expect(InvoicePaginationMeasurementStability.normalizedHeight(100.26) == 100.5)
        #expect(InvoicePaginationMeasurementStability.normalizedHeight(100.49) == 100.5)
        #expect(InvoicePaginationMeasurementStability.normalizedHeight(100.51) == 100.5)
    }

    @Test func PaginationMeasurementsRejectInvalidOrNegativeHeights() {
        #expect(InvoicePaginationMeasurementStability.normalizedHeight(-12) == 0)
        #expect(InvoicePaginationMeasurementStability.normalizedHeight(.infinity) == 0)
        #expect(InvoicePaginationMeasurementStability.normalizedHeight(.nan) == 0)
    }

    @Test func PaginationMeasurementRepublishesAfterModelCacheInvalidation() {
        let (dimensions, _) = InvoicePagination.MeasuredHeights.uniformRows(
            count: 1,
            rowHeight: 44
        )

        #expect(!(InvoicePaginationMeasurementPublicationPolicy.shouldStage(
                incoming: dimensions,
                reporterLatest: dimensions,
                modelCurrent: dimensions
            )))
        #expect(InvoicePaginationMeasurementPublicationPolicy.shouldStage(
                incoming: dimensions,
                reporterLatest: dimensions,
                modelCurrent: nil
            ))
    }

    @Test func PaginationMeasurementRejectsPreviousDocumentToken() {
        #expect(InvoicePaginationMeasurementPublicationPolicy.ownsCurrentContent(
                stagedContentToken: "invoice-b",
                currentContentToken: "invoice-b"
            ))
        #expect(!(InvoicePaginationMeasurementPublicationPolicy.ownsCurrentContent(
                stagedContentToken: "invoice-a",
                currentContentToken: "invoice-b"
            )))
    }

    @MainActor
    @Test func PaginationSectionReporterCoalescesInputInvalidations() async throws {
        let reporter = InvoicePaginationSectionReporter(
            reportingDelay: .milliseconds(1)
        )

        reporter.invalidate()
        reporter.invalidate()
        try await waitForPaginationPublication(reporter, expected: 1)

        reporter.invalidate()
        try await waitForPaginationPublication(reporter, expected: 2)
    }

    @MainActor
    private func waitForPaginationPublication(
        _ reporter: InvoicePaginationSectionReporter,
        expected: Int,
        timeout: Duration = .milliseconds(500)
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while reporter.publicationRevision < expected {
            if ContinuousClock.now >= deadline {
                Issue.record("Expected publicationRevision \(expected), got \(reporter.publicationRevision)")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func PreviewFitScaleCollapsesSubpixelResizeNoise() {
        #expect(InvoiceDocumentPreviewZoom.stabilizedFitScale(0.812_41) == 0.812)
        #expect(InvoiceDocumentPreviewZoom.stabilizedFitScale(0.812_49) == 0.812)
        #expect(InvoiceDocumentPreviewZoom.stabilizedFitScale(0.812_51) == 0.813)
        #expect(InvoiceDocumentPreviewZoom.stabilizedFitScale(.nan) == 1)
    }

    @MainActor
    @Test func DocumentActionCancellationInvokesInstalledActionOnce() {
        let cancellation = InvoiceDocumentActionCancellation()
        var invocationCount = 0
        cancellation.install { invocationCount += 1 }

        #expect(cancellation.isInstalled)
        cancellation.cancel()
        cancellation.cancel()

        #expect(invocationCount == 1)
        #expect(!(cancellation.isInstalled))
    }

    @MainActor
    @Test func DocumentActionCancellationCanClearWithoutInvokingAction() {
        let cancellation = InvoiceDocumentActionCancellation()
        var wasInvoked = false
        cancellation.install { wasInvoked = true }
        cancellation.clear()
        cancellation.cancel()

        #expect(!(wasInvoked))
        #expect(!(cancellation.isInstalled))
    }

    @Test func WorkspaceModesExposeOnlyTheirOwnedInspectorConcern() {
        #expect(InvoiceEditorWorkspaceMode.invoice.usesPersistedInvoiceData)
        #expect(InvoiceEditorWorkspaceMode.invoice.inspectorMode == .invoiceData)
        #expect(!(InvoiceEditorWorkspaceMode.template.usesPersistedInvoiceData))
        #expect(InvoiceEditorWorkspaceMode.template.inspectorMode == .templateFormatting)
        #expect(InvoiceEditorWorkspaceMode.invoice.inspectorSceneStorageKey != InvoiceEditorWorkspaceMode.template.inspectorSceneStorageKey)
    }

    @Test func TemplateExitPersistsValidStateAroundUnfinishedExactValueDrafts() {
        #expect(InvoiceTemplatePersistenceIntent.leaveWorkspace.permitsPersistence(
                hasInvalidInputs: true
            ))
        #expect(InvoiceTemplatePersistenceIntent.leaveWorkspace.permitsPersistence(
                hasInvalidInputs: false
            ))
    }

    @Test func TemplateCreationStillRequiresEveryExactValueToBeValid() {
        #expect(!(InvoiceTemplatePersistenceIntent.createInvoice.permitsPersistence(
                hasInvalidInputs: true
            )))
        #expect(InvoiceTemplatePersistenceIntent.createInvoice.permitsPersistence(
                hasInvalidInputs: false
            ))
    }

    @Test func EditorCreationActivityIncludesFeatureOwnedRequests() {
        #expect(!(InvoiceEditorCreationActivityPolicy.isActive(
                localRequest: false,
                featureRequest: false
            )))
        #expect(InvoiceEditorCreationActivityPolicy.isActive(
                localRequest: true,
                featureRequest: false
            ))
        #expect(InvoiceEditorCreationActivityPolicy.isActive(
                localRequest: false,
                featureRequest: true
            ))
    }

    @Test func CreationRequestStateRejectsOverlapAndIgnoresStaleCompletion() throws {
        var state = InvoiceEditorCreationRequestState()
        guard let firstRequest = state.begin() else {
            Issue.record("Expected first creation request")
            return
        }

        #expect(state.isActive)
        #expect(state.begin() == nil)

        state.invalidatePresentation()
        #expect(!(state.isActive))
        #expect(!(state.owns(firstRequest)))

        guard let secondRequest = state.begin() else {
            Issue.record("Expected second creation request")
            return
        }
        state.finish(firstRequest)

        #expect(state.isActive)
        #expect(state.owns(secondRequest))

        state.finish(secondRequest)
        #expect(!(state.isActive))
    }

    @Test func FailedInitialOpenKeepsRequestedSelectionAvailableForRetry() {
        let requestedID = UUID()

        #expect(!(InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: requestedID,
                openedID: nil
            )))
        #expect(InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: requestedID,
                openedID: requestedID
            ))
        #expect(!(InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: requestedID,
                openedID: UUID()
            )))
        #expect(InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: nil,
                openedID: nil
            ))
        #expect(InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: requestedID,
                openedID: UUID(),
                hasOpenDocument: true
            ))
    }

    @Test func OnlyCurrentExternalSelectionRequestMayReconcileListBinding() {
        let firstRequest = UUID()
        let newerRequest = UUID()

        #expect(!(InvoiceExternalSelectionPublicationPolicy.requestIsCurrent(
                requestedID: firstRequest,
                externalID: newerRequest
            )))
        #expect(InvoiceExternalSelectionPublicationPolicy.requestIsCurrent(
                requestedID: newerRequest,
                externalID: newerRequest
            ))
        #expect(InvoiceExternalSelectionPublicationPolicy.requestIsCurrent(
                requestedID: nil,
                externalID: nil
            ))
    }

    @Test func OpeningRecoveryRetainsOnlyFailedColdRequest() {
        let requestedID = UUID()

        #expect(InvoiceWorkspaceOpeningPolicy.failedRequestID(
                requestedID: requestedID,
                openedID: nil,
                hasOpenDocument: false
            ) == requestedID)
        #expect(InvoiceWorkspaceOpeningPolicy.failedRequestID(
                requestedID: requestedID,
                openedID: requestedID,
                hasOpenDocument: true
            ) == nil)
        #expect(InvoiceWorkspaceOpeningPolicy.failedRequestID(
                requestedID: requestedID,
                openedID: UUID(),
                hasOpenDocument: true
            ) == nil)
        #expect(InvoiceWorkspaceOpeningPolicy.failedRequestID(
                requestedID: nil,
                openedID: nil,
                hasOpenDocument: false
            ) == nil)
    }

    @MainActor
    @Test func TemplateCommandContextExposesInspectorAndPreviewWithoutClaimingInvoiceCommands() {
        let actions = InvoiceEditorCommandActions()
        actions.updateCapabilities(
            canCreate: false,
            canSave: false,
            canDuplicate: false,
            canDelete: false,
            canPrint: false,
            canExportPDF: false,
            canToggleInspector: true,
            isInvoiceContext: false,
            canZoomIn: true,
            canZoomOut: true,
            canSetActualSize: true,
            canFitWidth: false
        )

        #expect(!(actions.isInvoiceContext))
        #expect(!(actions.canCreate))
        #expect(!(actions.canSave))
        #expect(!(actions.canAddLineItem))
        #expect(actions.canToggleInspector)
        #expect(actions.canZoomIn)
        #expect(actions.canZoomOut)
        #expect(actions.canSetActualSize)
        #expect(!(actions.canFitWidth))
    }

    @MainActor
    @Test func PreviewCommandClosuresRemainIndependentFromInvoiceDataCommands() {
        let actions = InvoiceEditorCommandActions()
        var zoomInCount = 0
        var fitWidthCount = 0
        actions.zoomIn = { zoomInCount += 1 }
        actions.fitWidth = { fitWidthCount += 1 }

        actions.zoomIn()
        actions.fitWidth()

        #expect(zoomInCount == 1)
        #expect(fitWidthCount == 1)
        #expect(!(actions.isInvoiceContext))
        #expect(!(actions.canSave))
    }

    @MainActor
    @Test func FocusedEditorCanGateWorkspaceCreationWithoutOwningCreation() async {
        let actions = InvoiceEditorCommandActions()
        var preparationCount = 0
        actions.prepareForInvoiceCreation = {
            preparationCount += 1
            return false
        }

        let isPrepared = await actions.prepareForInvoiceCreation()
        #expect(!(isPrepared))
        #expect(preparationCount == 1)
    }

    @MainActor
    @Test func InvoiceCommandContextPublishesAddLineItemCapability() {
        let actions = InvoiceEditorCommandActions()
        actions.updateCapabilities(
            canCreate: true,
            canSave: true,
            canDuplicate: true,
            canDelete: true,
            canPrint: true,
            canExportPDF: true,
            canToggleInspector: true,
            isInvoiceContext: true,
            canAddLineItem: true
        )

        #expect(actions.isInvoiceContext)
        #expect(actions.canAddLineItem)
    }

    @MainActor
    @Test func AddLineItemRequestsHaveMonotonicRevision() {
        let toolbarState = InvoiceEditorToolbarState()

        #expect(toolbarState.addLineItemRequestRevision == 0)
        toolbarState.requestAddLineItem()
        #expect(toolbarState.addLineItemRequestRevision == 1)
        toolbarState.requestAddLineItem()
        #expect(toolbarState.addLineItemRequestRevision == 2)
    }

    @MainActor
    @Test func InvalidTemplateRecoveryRequestsHaveMonotonicRevision() {
        let toolbarState = InvoiceEditorToolbarState()

        #expect(toolbarState.invalidTemplateInputRecoveryRequestRevision == 0)
        toolbarState.requestInvalidTemplateInputRecovery()
        #expect(toolbarState.invalidTemplateInputRecoveryRequestRevision == 1)
        toolbarState.requestInvalidTemplateInputRecovery()
        #expect(toolbarState.invalidTemplateInputRecoveryRequestRevision == 2)
    }

    @MainActor
    @Test func NumericInputResetRevisionAdvancesEvenWhenTypedBaselineIsUnchanged() {
        let drafts = InvoiceNumericInputDraftStore()
        let toolbarState = InvoiceEditorToolbarState(numericInputDrafts: drafts)
        drafts.preserve("invalid", for: "template.page.width", baseline: "595")

        let clearedIDs = toolbarState.resetNumericInputDrafts()

        #expect(Set(clearedIDs) == Set(["template.page.width"]))
        #expect(toolbarState.numericInputResetRevision == 1)
        #expect(drafts.inputIDs.isEmpty)

        toolbarState.resetNumericInputDraft("template.page.width")
        #expect(toolbarState.numericInputResetRevision == 2)
    }

    @MainActor
    @Test func TemplateNumericOverrideAppliesValueBeforeClearingInvalidDraft() {
        let inputID = "template.typographyScale"
        let drafts = InvoiceNumericInputDraftStore()
        let toolbarState = InvoiceEditorToolbarState(numericInputDrafts: drafts)
        drafts.preserve("invalid", for: inputID, baseline: "1")
        var resolvedValue = 1.0
        var validityEvents: [(String, Bool, Double)] = []

        InvoiceTemplateNumericDraftResolution.replace(
            inputID: inputID,
            toolbarState: toolbarState,
            onValidityChange: { id, isInvalid in
                validityEvents.append((id, isInvalid, resolvedValue))
            },
            applying: {
                resolvedValue = 1.25
            }
        )

        #expect(resolvedValue == 1.25)
        #expect(drafts.inputIDs.isEmpty)
        #expect(toolbarState.numericInputResetRevision == 1)
        #expect(validityEvents.first?.0 == inputID)
        #expect(validityEvents.first?.1 == false)
        #expect(validityEvents.first?.2 == 1.25)
    }

    @MainActor
    @Test func LineItemUndoActionsAreRemovedWhenDocumentChanges() {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        let coordinator = InvoiceLineItemUndoCoordinator()

        undoManager.beginUndoGrouping()
        _ = coordinator.addLineItem(to: viewModel, undoManager: undoManager)
        undoManager.endUndoGrouping()
        #expect(undoManager.canUndo)

        let nextDocumentID = UUID()
        coordinator.activateDocument(id: nextDocumentID, undoManager: undoManager)

        #expect(coordinator.activeDocumentID == nextDocumentID)
        #expect(!(undoManager.canUndo))
        #expect(!(undoManager.canRedo))
    }

    @MainActor
    @Test func StaleLineItemUndoCannotMutateDifferentDocument() {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        let coordinator = InvoiceLineItemUndoCoordinator()
        let originalCount = viewModel.lineItems.count

        undoManager.beginUndoGrouping()
        _ = coordinator.addLineItem(to: viewModel, undoManager: undoManager)
        undoManager.endUndoGrouping()
        #expect(viewModel.lineItems.count == originalCount + 1)

        viewModel.selectedInvoiceID = UUID()
        undoManager.undo()

        #expect(viewModel.lineItems.count == originalCount + 1)
    }

    @Test func NumericInputDraftStoreRestoresOnlyAgainstSameTypedBaseline() {
        let store = InvoiceNumericInputDraftStore()

        store.preserve("not a number", for: "tax", baseline: "10")

        #expect(store.restoredText(for: "tax", baseline: "10") == "not a number")
        #expect(store.restoredText(for: "tax", baseline: "15") == nil)
        #expect(store.restoredText(for: "tax", baseline: "10") == nil)
    }

    @Test func NumericInputDraftStoreClearsAllTrackedFields() {
        let store = InvoiceNumericInputDraftStore()
        store.preserve("bad", for: "margin", baseline: "24")
        store.preserve("also bad", for: "scale", baseline: "1")

        #expect(Set(store.clearAll()) == ["margin", "scale"])
        #expect(store.restoredText(for: "margin", baseline: "24") == nil)
        #expect(store.restoredText(for: "scale", baseline: "1") == nil)
    }

    @Test func NumericInputDraftStoreRoundTripsSceneSnapshot() {
        let source = InvoiceNumericInputDraftStore()
        source.preserve("invalid", for: "spacing", baseline: "1")

        let restored = InvoiceNumericInputDraftStore()
        restored.restore(from: source.encodedSnapshot)

        #expect(restored.inputIDs == ["spacing"])
        #expect(restored.restoredText(for: "spacing", baseline: "1") == "invalid")
    }

    @Test func TemplatePreferenceStoreRoundTripsConfiguration() throws {
        let suiteName = "InvoiceTemplatePreferenceStoreTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .burgundy
        configuration.headerStyle = .compact
        configuration.tableStyle = .borderless

        #expect(InvoiceTemplatePreferenceStore.save(configuration, to: preferences) == true)

        #expect(InvoiceTemplatePreferenceStore.load(from: preferences) == configuration)
    }

    @Test func TemplatePreferenceStoreRoundTripsCompletePageSetup() throws {
        let suiteName = "InvoiceTemplateDefaultsTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .forest
        let defaults = InvoiceTemplateDefaults(
            paperSize: .legal,
            pageOrientation: .landscape,
            configuration: configuration
        )

        #expect(InvoiceTemplatePreferenceStore.save(defaults, to: preferences) == true)
        #expect(InvoiceTemplatePreferenceStore.loadDefaults(from: preferences) == defaults)
    }

    @Test func TemplateSaveTrackerWritesOnlyGenuineLocalChanges() {
        var tracker = InvoiceTemplateSaveTracker()
        let original = InvoiceTemplateDefaults()
        var edited = original
        edited.configuration.accentTheme = .forest

        #expect(tracker.requiresSave(original))

        tracker.markSaved(original)
        #expect(!(tracker.requiresSave(original)))
        #expect(tracker.requiresSave(edited))

        tracker.markSaved(edited)
        #expect(!(tracker.requiresSave(edited)))
    }

    @Test func TemplateInvalidInputHasDistinctPersistenceFeedback() {
        #expect(InvoiceTemplateSaveState.invalid.title == "Fix values")
        #expect(InvoiceTemplateSaveState.invalid != .saved)
        #expect(InvoiceTemplateSaveState.invalid != .saving)
        #expect(InvoiceTemplateSaveState.invalid != .failed)
    }

    @Test func EditorCommandCapabilitiesTrackWorkspaceAndViewportState() {
        let fitWidthAtMinimum = InvoiceEditorCommandCapabilities(
            mode: .template,
            hasInvoice: false,
            hasDocument: true,
            hasUnsavedChanges: false,
            isBusy: false,
            hasRevisionConflict: false,
            zoom: InvoiceDocumentPreviewZoom(mode: .fitWidth),
            fitScale: InvoiceDocumentPreviewZoom.minimumScale
        )

        #expect(!(fitWidthAtMinimum.isInvoiceContext))
        #expect(fitWidthAtMinimum.canCreate)
        #expect(!(fitWidthAtMinimum.canSave))
        #expect(fitWidthAtMinimum.canToggleInspector)
        #expect(!(fitWidthAtMinimum.canZoomOut))
        #expect(!(fitWidthAtMinimum.canFitWidth))

        let invalidTemplate = InvoiceEditorCommandCapabilities(
            mode: .template,
            hasInvoice: false,
            hasDocument: true,
            hasUnsavedChanges: false,
            isBusy: false,
            hasRevisionConflict: false,
            creationIsAvailable: false,
            zoom: InvoiceDocumentPreviewZoom(mode: .fitWidth),
            fitScale: 0.75
        )

        #expect(!(invalidTemplate.canCreate))

        let activeInvoice = InvoiceEditorCommandCapabilities(
            mode: .invoice,
            hasInvoice: true,
            hasDocument: true,
            hasUnsavedChanges: true,
            isBusy: false,
            hasRevisionConflict: false,
            zoom: InvoiceDocumentPreviewZoom(mode: .absolute(1)),
            fitScale: 0.75
        )

        #expect(activeInvoice.isInvoiceContext)
        #expect(activeInvoice.canCreate)
        #expect(activeInvoice.canSave)
        #expect(activeInvoice.canAddLineItem)
        #expect(!(activeInvoice.canToggleInspector))
        #expect(activeInvoice.canFitWidth)
        #expect(!(activeInvoice.canSetActualSize))

        let busyInvoice = InvoiceEditorCommandCapabilities(
            mode: .invoice,
            hasInvoice: true,
            hasDocument: true,
            hasUnsavedChanges: true,
            isBusy: true,
            hasRevisionConflict: false,
            zoom: InvoiceDocumentPreviewZoom(mode: .absolute(1)),
            fitScale: 0.75
        )

        #expect(!(busyInvoice.canCreate))
        #expect(!(busyInvoice.canSave))
        #expect(!(busyInvoice.canAddLineItem))
        #expect(busyInvoice.canZoomIn)
    }

    @Test func TemplateSaveRecoveryAppearsOnlyForActionablePersistenceFailure() {
        #expect(InvoiceTemplateSaveRecoveryPolicy.issue(
                saveState: .failed,
                hasInvalidInputs: true
            ) == .invalidInputs)
        #expect(InvoiceTemplateSaveRecoveryPolicy.issue(
                saveState: .failed,
                hasInvalidInputs: false
            ) == .saveFailure)
        #expect(InvoiceTemplateSaveRecoveryPolicy.issue(
                saveState: .saved,
                hasInvalidInputs: true
            ) == .invalidInputs)
        #expect(InvoiceTemplateSaveRecoveryPolicy.issue(
                saveState: .saved,
                hasInvalidInputs: false
            ) == nil)

        #expect(InvoiceTemplateSaveRecoveryPolicy.showsFailureRecovery(
                saveState: .failed,
                hasInvalidInputs: false
            ))
        #expect(!(InvoiceTemplateSaveRecoveryPolicy.showsFailureRecovery(
                saveState: .failed,
                hasInvalidInputs: true
            )))
        #expect(!(InvoiceTemplateSaveRecoveryPolicy.showsFailureRecovery(
                saveState: .saved,
                hasInvalidInputs: false
            )))

        #expect(InvoiceTemplateSaveRecoveryPolicy.reconciledState(
                .failed,
                requiresSave: false
            ) == .saved)
        #expect(InvoiceTemplateSaveRecoveryPolicy.reconciledState(
                .failed,
                requiresSave: true
            ) == .failed)
    }

    @Test func TemplatePreferenceStoreMigratesLegacyRawConfiguration() throws {
        let suiteName = "InvoiceTemplateLegacyDefaultsTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .burgundy
        preferences.set(
            try JSONEncoder().encode(configuration),
            forKey: InvoiceTemplatePreferenceStore.preferenceKey
        )

        let defaults = InvoiceTemplatePreferenceStore.loadDefaults(from: preferences)

        #expect(defaults.paperSize == .default)
        #expect(defaults.pageOrientation == .portrait)
        #expect(defaults.configuration.accentTheme == .burgundy)
    }

    @Test func LegacyTemplatePayloadPreservesKnownValuesAndDefaultsMissingFields() throws {
        let data = Data(
            #"""
            {
              "accentTheme": "burgundy",
              "showPaymentDetails": false,
              "customAccentColor": { "red": 0.2, "green": 0.3, "blue": 0.4 },
              "columnVisibility": { "showDate": false }
            }
            """#.utf8
        )

        let configuration = try JSONDecoder().decode(
            InvoiceTemplateConfiguration.self,
            from: data
        )

        #expect(configuration.accentTheme == .burgundy)
        #expect(!(configuration.showPaymentDetails))
        #expect(configuration.customAccentColor?.opacity == 1)
        #expect(!(configuration.columnVisibility.showDate))
        #expect(configuration.columnVisibility.showRate)
        #expect(configuration.headerStyle == .default)
    }

    @Test func MalformedTemplateFieldFallsBackWithoutDiscardingValidFields() throws {
        let data = Data(
            #"""
            {
              "accentTheme": "burgundy",
              "headerStyle": "unsupported-future-style",
              "showPaymentTerms": false
            }
            """#.utf8
        )

        let configuration = try JSONDecoder().decode(
            InvoiceTemplateConfiguration.self,
            from: data
        )

        #expect(configuration.accentTheme == .burgundy)
        #expect(configuration.headerStyle == .default)
        #expect(!(configuration.showPaymentTerms))
    }

    @Test func ExtremePersistedGeometryIsClampedToLayoutSafeBounds() throws {
        let data = Data(
            #"""
            {
              "customPageWidthPoints": 102954,
              "customPageHeightPoints": -50,
              "customMarginPoints": 99999,
              "customTypographyScale": 40,
              "customSpacingScale": -2,
              "customBorderWidth": 50,
              "customAccentColor": { "red": 8, "green": -4, "blue": 0.5, "opacity": 7 }
            }
            """#.utf8
        )

        let configuration = try JSONDecoder().decode(
            InvoiceTemplateConfiguration.self,
            from: data
        )

        #expect(configuration.customPageWidthPoints == InvoiceTemplateLayoutLimits.pageDimensionRange.upperBound)
        #expect(configuration.customPageHeightPoints == InvoiceTemplateLayoutLimits.pageDimensionRange.lowerBound)
        #expect(configuration.customMarginPoints == InvoiceTemplateLayoutLimits.storedMarginRange.upperBound)
        #expect(configuration.customTypographyScale == InvoiceTemplateLayoutLimits.typographyScaleRange.upperBound)
        #expect(configuration.customSpacingScale == InvoiceTemplateLayoutLimits.spacingScaleRange.lowerBound)
        #expect(configuration.customBorderWidth == InvoiceTemplateLayoutLimits.borderWidthRange.upperBound)
        #expect(configuration.customAccentColor?.red == 1)
        #expect(configuration.customAccentColor?.green == 0)
        #expect(configuration.customAccentColor?.opacity == 1)
    }

    @MainActor
    @Test func PageGeometryAppliesPartialOverridesAndRetainsPrintableArea() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)
        let standardHeight = viewModel.paperSize.sizePoints(for: viewModel.pageOrientation).height

        viewModel.customPageWidthPoints = 900
        viewModel.customMarginPoints = 100_000

        #expect(viewModel.pageSizePoints.width == 900)
        #expect(viewModel.pageSizePoints.height == standardHeight)
        #expect(viewModel.pageSizePoints.width - (viewModel.effectiveMarginPoints * 2) >= InvoiceTemplateLayoutLimits.minimumContentDimension
        )
        #expect(viewModel.pageSizePoints.height - (viewModel.effectiveMarginPoints * 2) >= InvoiceTemplateLayoutLimits.minimumContentDimension
        )
    }

    @Test func TemplateMarginInputRangePreservesMinimumPrintableArea() {
        let pageSize = CGSize(width: 600, height: 900)
        let maximum = InvoiceTemplateLayoutLimits.maximumMargin(for: pageSize)

        #expect(maximum == 264)
        #expect(InvoiceTemplateLayoutLimits.effectiveMargin(1_000, pageSize: pageSize) == 264)
        #expect(InvoiceDoubleInput.parse("264", in: 0...maximum) == 264)
        #expect(InvoiceDoubleInput.parse("264.1", in: 0...maximum) == nil)
    }

    @MainActor
    @Test func CustomPageOrientationSwapsResolvedDimensionsAndUpdatesLabel() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.customPageWidthPoints = 900
        viewModel.customPageHeightPoints = 600

        viewModel.updatePageOrientation(.landscape)

        #expect(viewModel.pageOrientation == .landscape)
        #expect(viewModel.pageSizePoints.width == 600)
        #expect(viewModel.pageSizePoints.height == 900)
        #expect(viewModel.pageDimensionsLabel == "600 × 900 pt")
    }

    @MainActor
    @Test func StandardPageOrientationKeepsStandardSizingImplicit() throws {
        let viewModel = InvoiceEditorViewModel()

        viewModel.updatePageOrientation(.landscape)

        #expect(viewModel.customPageWidthPoints == nil)
        #expect(viewModel.customPageHeightPoints == nil)
        #expect(viewModel.pageSizePoints == PaperSize.a4.sizePoints(for: .landscape))
        #expect(viewModel.pageDimensionsLabel == "297 × 210 mm")
    }

    @MainActor
    @Test func TemplatePreviewDoesNotOfferInvoiceDataTargeting() {
        let interaction = InvoicePreviewInspectorInteraction(mode: .templateFormatting)

        interaction.select(.sellerName)

        #expect(interaction.focusRequest == nil)
        #expect(interaction.formatInspectorRevealRevision == 1)
        #expect(interaction.requestedFormatSection == .content)
        #expect(!(interaction.allowsFieldTargeting))
        #expect(interaction.allowsFormatInspectorReveal)
        #expect(interaction.allowsPreviewTargetSelection)
        #expect(interaction.accessibilityLabel(for: .sellerName) == "Format sender name")
        #expect(interaction.accessibilityHint(for: .sellerName) == "Opens Content format section without changing mock invoice data")
        #expect(interaction.helpText(for: .sellerName) == "Format sender name in Content")
    }

    @MainActor
    @Test func TemplatePreviewRoutesDocumentRegionsToRelevantFormatSections() {
        let interaction = InvoicePreviewInspectorInteraction(mode: .templateFormatting)

        interaction.select(.header)
        #expect(interaction.requestedFormatSection == .template)

        interaction.select(.lineItemDescription(UUID()))
        #expect(interaction.requestedFormatSection == .lineItems)

        interaction.select(.paymentDetails)
        #expect(interaction.requestedFormatSection == .content)
        #expect(interaction.formatInspectorRevealRevision == 3)
        #expect(interaction.focusRequest == nil)
    }

    @MainActor
    @Test func RepeatedPreviewSelectionCreatesDistinctFocusRequests() {
        let interaction = InvoicePreviewInspectorInteraction()

        interaction.select(.invoiceNumber)
        let firstRequest = interaction.focusRequest
        interaction.select(.invoiceNumber)
        let secondRequest = interaction.focusRequest

        #expect(firstRequest?.target == .invoiceNumber)
        #expect(secondRequest?.target == .invoiceNumber)
        #expect(firstRequest?.id != secondRequest?.id)
        #expect(interaction.formatInspectorRevealRevision == 0)
        #expect(interaction.allowsFieldTargeting)
        #expect(!(interaction.allowsFormatInspectorReveal))
        #expect(interaction.allowsPreviewTargetSelection)
    }

    @MainActor
    @Test func CompletingSupersededPreviewFocusDoesNotClearLatestRequest() throws {
        let interaction = InvoicePreviewInspectorInteraction()

        interaction.select(.invoiceNumber)
        let firstRequest = try #require(interaction.focusRequest)
        interaction.select(.clientName)
        let secondRequest = try #require(interaction.focusRequest)

        interaction.completeFocusRequest(id: firstRequest.id)
        #expect(interaction.focusRequest == secondRequest)

        interaction.completeFocusRequest(id: secondRequest.id)
        #expect(interaction.focusRequest == nil)
    }

    @Test func DeferredInspectorFocusLeaseRequiresMatchingDocumentAndLatestLease() {
        let firstDocumentID = UUID()
        let secondDocumentID = UUID()
        let leaseID = UUID()
        let lease = InvoiceInspectorDeferredFocusLease(
            id: leaseID,
            documentID: firstDocumentID
        )

        #expect(lease.isCurrent(
                activeLeaseID: leaseID,
                selectedDocumentID: firstDocumentID
            ))
        #expect(!(lease.isCurrent(
                activeLeaseID: UUID(),
                selectedDocumentID: firstDocumentID
            )))
        #expect(!(lease.isCurrent(
                activeLeaseID: leaseID,
                selectedDocumentID: secondDocumentID
            )))
        #expect(!(lease.isCurrent(
                activeLeaseID: nil,
                selectedDocumentID: firstDocumentID
            )))
    }

    @MainActor
    @Test func StatusBannerAutoDismissesSuccessButKeepsActionableErrors() {
        #expect(InvoiceEditorStatusBanner.shouldAutoDismiss("Invoice saved."))
        #expect(InvoiceEditorStatusBanner.shouldAutoDismiss("Unsaved changes discarded."))
        #expect(!(InvoiceEditorStatusBanner.shouldAutoDismiss("Failed to save invoice: unavailable")))
        #expect(!(InvoiceEditorStatusBanner.shouldAutoDismiss(
                "Invoice couldn't be created. Store unavailable."
            )))
        #expect(!(InvoiceEditorStatusBanner.shouldAutoDismiss(
                "Fix the errors in the Validation section before switching invoices."
            )))
        #expect(!(InvoiceEditorStatusBanner.shouldAutoDismiss(
                "This invoice was deleted in another window. Your local draft is still available."
            )))
        #expect(!(InvoiceEditorStatusBanner.shouldAutoDismiss(
                "Current draft could not be saved."
            )))
        #expect(InvoiceEditorStatusBanner.tone(for: "Invoice saved.") == .success)
        #expect(InvoiceEditorStatusBanner.tone(for: "Export cancelled.") == .informational)
        #expect(InvoiceEditorStatusBanner.tone(for: "Unsaved changes discarded.") == .informational)
        #expect(InvoiceEditorStatusBanner.tone(for: "Failed to save invoice: unavailable") == .error)
        #expect(InvoiceEditorStatusBanner.tone(
                for: "Invoice couldn't be created. Store unavailable."
            ) == .error)
        #expect(InvoiceEditorStatusBanner.tone(
                for: "This invoice was deleted in another window. Your local draft is still available."
            ) == .error)
        #expect(InvoiceEditorStatusBanner.messageForPresentation(
                "Applied Modern template.",
                whileTemplateSaveFailed: true
            ) == nil)
        #expect(InvoiceEditorStatusBanner.messageForPresentation(
                "Failed to load invoice: unavailable",
                whileTemplateSaveFailed: true
            ) == "Failed to load invoice: unavailable")
    }

    @MainActor
    @Test func StatusDismissalCannotClearNewerFeedback() {
        let viewModel = InvoiceEditorViewModel()
        viewModel.statusMessage = "Invoice saved."
        let staleMessageID = viewModel.statusMessageID

        viewModel.statusMessage = "Failed to save invoice: Store unavailable."
        let latestMessageID = viewModel.statusMessageID

        viewModel.dismissStatusMessage(id: staleMessageID)
        #expect(viewModel.statusMessage == "Failed to save invoice: Store unavailable.")

        viewModel.dismissStatusMessage(id: latestMessageID)
        #expect(viewModel.statusMessage == nil)
    }

    @MainActor
    @Test func TemplateSaveFailureDiscardsOnlySuppressedNonErrorFeedback() {
        #expect(InvoiceEditorStatusBanner.shouldDiscardSuppressedMessage(
                "Applied Modern template.",
                whenTemplateSaveFailed: true
            ))
        #expect(!(InvoiceEditorStatusBanner.shouldDiscardSuppressedMessage(
                "Failed to create invoice: Store unavailable.",
                whenTemplateSaveFailed: true
            )))
        #expect(!(InvoiceEditorStatusBanner.shouldDiscardSuppressedMessage(
                "Applied Modern template.",
                whenTemplateSaveFailed: false
            )))
    }

    @Test func InvoiceEnvelopePreservesSemanticFieldsWithPartiallyMalformedTemplate() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Invoice(invoiceNumber: "INV-LEGACY")
        invoice.invoiceEditorStateData = Data(
            #"""
            {
              "title": "Legacy Invoice",
              "billParticipantDirectly": false,
              "discountAmount": "invalid",
              "template": {
                "accentTheme": "navy",
                "headerStyle": "unsupported-future-style"
              }
            }
            """#.utf8
        )
        context.insert(invoice)

        let envelope = InvoiceDocumentConfigurationEnvelope.decode(from: invoice)

        #expect(envelope.title == "Legacy Invoice")
        #expect(!(envelope.billParticipantDirectly))
        #expect(envelope.discountAmount == 0)
        #expect(envelope.template.accentTheme == .navy)
        #expect(envelope.template.headerStyle == .default)
    }

    @Test func LegacyInvoiceEnvelopeMissingTemplateIgnoresCurrentTemplatePreferences() throws {
        let suiteName = "InvoiceEditorSeparationTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer {
            preferences.removePersistentDomain(forName: suiteName)
        }

        var currentTemplate = InvoiceTemplateConfiguration.default
        currentTemplate.accentTheme = .forest
        currentTemplate.headerStyle = .compact
        #expect(InvoiceTemplatePreferenceStore.save(currentTemplate, to: preferences) == true)

        let invoice = Invoice(invoiceNumber: "INV-LEGACY-NO-TEMPLATE")
        invoice.invoiceEditorStateData = Data(
            #"""
            {
              "title": "Legacy Stable Invoice",
              "billParticipantDirectly": false
            }
            """#.utf8
        )

        let envelope = InvoiceDocumentConfigurationEnvelope.decode(from: invoice)

        #expect(envelope.title == "Legacy Stable Invoice")
        #expect(!(envelope.billParticipantDirectly))
        #expect(envelope.template == .default)
    }

    @Test func MockPreviewUsesDeterministicContentAndRequestedTemplate() {
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .forest

        let snapshot = InvoiceTemplateMockData.snapshot(template: configuration)

        #expect(snapshot.id == UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        #expect(snapshot.invoiceNumber == "INV-DEMO-001")
        #expect(snapshot.clientName == "Alex Morgan")
        #expect(snapshot.currencyCode == "AUD")
        #expect(snapshot.lineItems.count == 3)
        #expect(snapshot.templateConfiguration == configuration)
    }

    @MainActor
    @Test func MockBootstrapAppliesCompleteTemplateDefaultsAtomically() {
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .forest
        configuration.headerStyle = .compact
        let defaults = InvoiceTemplateDefaults(
            paperSize: .legal,
            pageOrientation: .landscape,
            configuration: configuration
        )
        let viewModel = InvoiceEditorViewModel()

        viewModel.bootstrapMock(defaults: defaults)

        #expect(viewModel.paperSize == .legal)
        #expect(viewModel.pageOrientation == .landscape)
        #expect(viewModel.templateConfiguration == configuration)
        #expect(!(viewModel.hasUnsavedChanges))
    }

    @MainActor
    @Test func MockBootstrapDoesNotTouchPersistedInvoices() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        _ = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel()

        viewModel.bootstrapMock(template: .default)
        let persistedCount = try await actor.invoiceCount()

        #expect(viewModel.currentInvoice?.invoiceNumber == "INV-DEMO-001")
        #expect(persistedCount == 1)
    }

    @MainActor
    @Test func ResetTemplateRestoresPageSetupAndFormattingDefaults() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: InvoiceTemplatePreset.modern.configuration)
        viewModel.paperSize = .legal
        viewModel.pageOrientation = .landscape

        #expect(!(viewModel.isUsingDefaultTemplate))

        viewModel.resetTemplateToDefaults()

        #expect(viewModel.paperSize == .default)
        #expect(viewModel.pageOrientation == .portrait)
        #expect(viewModel.templateConfiguration == .default)
        #expect(viewModel.isUsingDefaultTemplate)
    }

    @Test func DeleteConfirmationWarnsWhenDraftWillBeDiscarded() {
        #expect(InvoiceEditorDeleteCopy.message(
                invoiceNumber: "INV-1042",
                discardsUnsavedChanges: true
            ) == "This permanently deletes INV-1042 and all of its line items. This cannot be undone. Unsaved changes to this invoice will also be discarded.")
        #expect(InvoiceEditorDeleteCopy.message(
                invoiceNumber: "   ",
                discardsUnsavedChanges: false
            ) == "This permanently deletes the selected invoice and all of its line items. This cannot be undone.")
    }

    @MainActor
    @Test func CustomPageAndMarginOverridesCanReturnToSelectedPresets() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)
        viewModel.paperSize = .legal
        viewModel.marginPreset = .wide
        viewModel.customPageWidthPoints = 700
        viewModel.customPageHeightPoints = 1_000
        viewModel.customMarginPoints = 72

        #expect(viewModel.hasCustomPageSize)
        #expect(viewModel.hasCustomMargin)

        viewModel.useSelectedPaperSize()
        viewModel.useSelectedMarginPreset()

        #expect(!(viewModel.hasCustomPageSize))
        #expect(!(viewModel.hasCustomMargin))
        #expect(viewModel.pageSizePoints == PaperSize.legal.sizePoints(for: .portrait))
        #expect(viewModel.effectiveMarginPoints == InvoiceMarginPreset.wide.marginPoints)
    }

    @MainActor
    @Test func DirectTemplateNumericEditsClampToSafeControlRanges() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)

        viewModel.updateCustomTypographyScale(100)
        viewModel.updateCustomSpacingScale(-20)
        viewModel.updateCustomBorderWidth(.infinity)

        #expect(viewModel.customTypographyScale == InvoiceTemplateLayoutLimits.typographyScaleRange.upperBound)
        #expect(viewModel.customSpacingScale == InvoiceTemplateLayoutLimits.spacingScaleRange.lowerBound)
        #expect(viewModel.customBorderWidth == nil)
    }

    @Test func NewInvoiceReceivesSavedTemplateDefaults() async throws {
        let suiteName = "NewInvoiceReceivesSavedTemplateDefaults.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .navy
        configuration.headerStyle = .compact
        let templateDefaults = InvoiceTemplateDefaults(
            paperSize: .legal,
            pageOrientation: .landscape,
            configuration: configuration
        )
        #expect(InvoiceTemplatePreferenceStore.save(templateDefaults, to: preferences))

        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await actor.createInvoice(
            defaults: InvoiceCreationDefaults.load(from: preferences),
            templateDefaults: templateDefaults
        )
        let fetchedSnapshot = try await actor.fetchInvoice(id: id)
        let snapshot = try #require(fetchedSnapshot)

        #expect(snapshot.templateConfiguration == configuration)
        #expect(snapshot.paperSize == .legal)
        #expect(snapshot.pageOrientation == .landscape)
    }
}
