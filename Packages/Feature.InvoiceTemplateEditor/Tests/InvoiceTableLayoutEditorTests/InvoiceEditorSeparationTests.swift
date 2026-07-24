import Core
import Data
import Foundation
import SwiftData
import XCTest
@testable import InvoiceTableLayoutEditor

final class InvoiceEditorSeparationTests: XCTestCase {
    func testOperationErrorPresentationReplacesOpaqueSwiftDataDiagnostics() {
        let error = NSError(
            domain: "SwiftData.SwiftDataError",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "The operation couldn’t be completed. (SwiftData.SwiftDataError error 1.)"
            ]
        )

        XCTAssertEqual(
            InvoiceOperationErrorPresentation.detail(
                for: error,
                fallback: "Invoice data could not be read. Try again."
            ),
            "Invoice data could not be read. Try again."
        )
    }

    func testOperationErrorPresentationFindsNestedPersistenceDiagnostics() {
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

        XCTAssertEqual(
            InvoiceOperationErrorPresentation.detail(
                for: wrapper,
                fallback: "Invoice data could not be refreshed. Try again."
            ),
            "Invoice data could not be refreshed. Try again."
        )
    }

    func testOperationErrorPresentationPreservesMeaningfulDomainCopy() {
        XCTAssertEqual(
            InvoiceOperationErrorPresentation.detail(
                for: InvoiceModelError.invoiceNotFound,
                fallback: "Invoice data could not be read. Try again."
            ),
            "The invoice no longer exists."
        )
    }

    @MainActor
    func testTypedBillingAuthorityKeepsDirectBillingStateConsistent() {
        let viewModel = InvoiceEditorViewModel()

        viewModel.updateBillingAuthority(.client)
        XCTAssertEqual(viewModel.billingAuthority, Core.BillingAuthority.client.rawValue)
        XCTAssertTrue(viewModel.billParticipantDirectly)

        viewModel.updateBillingAuthority(.planManager)
        XCTAssertEqual(viewModel.billingAuthority, Core.BillingAuthority.planManager.rawValue)
        XCTAssertFalse(viewModel.billParticipantDirectly)

        viewModel.updateBillingAuthority(nil)
        XCTAssertEqual(viewModel.billingAuthority, "")
        XCTAssertFalse(viewModel.billParticipantDirectly)
    }

    func testDirectBillingWinsOverStaleAuthorityAtPersistenceBoundary() {
        XCTAssertEqual(
            InvoiceBillingAuthorityResolution.resolve(
                rawValue: Core.BillingAuthority.planManager.rawValue,
                billsParticipantDirectly: true
            ),
            .client
        )
        XCTAssertEqual(
            InvoiceBillingAuthorityResolution.resolve(
                rawValue: Core.BillingAuthority.parentGuardian.rawValue,
                billsParticipantDirectly: false
            ),
            .parentGuardian
        )
        XCTAssertNil(
            InvoiceBillingAuthorityResolution.resolve(
                rawValue: "invalid authority",
                billsParticipantDirectly: false
            )
        )
    }

    func testTemplateInvalidInputsRouteToStableRecoverySections() {
        XCTAssertEqual(
            InvoiceTemplateInvalidInputDestination.section(
                for: InvoiceTemplateGeometryInputID.pageWidth
            ),
            .layout
        )
        XCTAssertEqual(
            InvoiceTemplateInvalidInputDestination.section(
                for: InvoiceTemplateGeometryInputID.borderWidth
            ),
            .design
        )
        XCTAssertNil(
            InvoiceTemplateInvalidInputDestination.section(for: "unknown.template.input")
        )

        XCTAssertEqual(
            InvoiceTemplateInvalidInputDestination.firstSection(
                for: [
                    InvoiceTemplateGeometryInputID.borderWidth,
                    InvoiceTemplateGeometryInputID.margin,
                ]
            ),
            .layout
        )
    }

    func testBorderlessTemplateClearsNowIrrelevantBorderWidthInput() {
        XCTAssertEqual(
            InvoiceTemplateInputRelevance.disabledInputIDs(tableStyle: .borderless),
            [InvoiceTemplateGeometryInputID.borderWidth]
        )
        XCTAssertTrue(
            InvoiceTemplateInputRelevance.disabledInputIDs(tableStyle: .ruled).isEmpty
        )
    }

    func testInspectorPresentationPolicySuppressesEquivalentLayoutWrites() {
        XCTAssertNil(
            InvoiceEditorInspectorPresentationPolicy.replacement(
                current: true,
                requested: true
            )
        )
        XCTAssertNil(
            InvoiceEditorInspectorPresentationPolicy.replacement(
                current: false,
                requested: false
            )
        )
        XCTAssertEqual(
            InvoiceEditorInspectorPresentationPolicy.replacement(
                current: false,
                requested: true
            ),
            true
        )
        XCTAssertEqual(
            InvoiceEditorInspectorPresentationPolicy.replacement(
                current: true,
                requested: false
            ),
            false
        )
    }

    func testMoneyFormattingFallsBackForMalformedCurrencyCodes() {
        XCTAssertEqual(
            InvoiceMoneyFormatter.string(
                for: 125,
                currencyCode: "12!",
                displayStyle: .code
            ),
            "AUD 125"
        )
        XCTAssertEqual(
            InvoiceMoneyFormatter.editableSuffix(
                currencyCode: "invalid",
                displayStyle: .iso
            ),
            "AUD"
        )
    }

    func testAtomicPDFWriterReplacesExistingExport() throws {
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

        XCTAssertEqual(try Data(contentsOf: destination), replacementData)
        XCTAssertEqual(try Data(contentsOf: source), replacementData)
    }

    func testAtomicPDFWriterPreservesExistingExportWhenSourceReadFails() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("InvoicePDFWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let missingSource = directory.appendingPathComponent("missing.pdf")
        let destination = directory.appendingPathComponent("Invoice.pdf")
        let originalData = Data("existing export".utf8)
        try originalData.write(to: destination)

        XCTAssertThrowsError(
            try InvoicePDFFileWriter.write(source: missingSource, to: destination)
        )
        XCTAssertEqual(try Data(contentsOf: destination), originalData)
    }

    func testBusinessMarkUsesFirstTwoNameComponents() {
        XCTAssertEqual(InvoiceBrandMark.initials(for: "Mercer Care Services"), "MC")
        XCTAssertEqual(InvoiceBrandMark.initials(for: "acme"), "A")
        XCTAssertEqual(InvoiceBrandMark.initials(for: "NDIS 24 Seven"), "N2")
    }

    func testBusinessMarkHasStableFallbackForMissingSellerName() {
        XCTAssertEqual(InvoiceBrandMark.initials(for: "  —  "), "IN")
    }

    func testDocumentFilenamePreservesReadableSafeInvoiceNumber() {
        XCTAssertEqual(
            InvoiceDocumentFilename.pdf(invoiceNumber: "INV 2026-001"),
            "Invoice-INV 2026-001.pdf"
        )
    }

    func testDocumentFilenameReplacesPathAndPlatformReservedCharacters() {
        XCTAssertEqual(
            InvoiceDocumentFilename.pdf(invoiceNumber: "INV/2026:001\\Final?"),
            "Invoice-INV-2026-001-Final.pdf"
        )
    }

    func testDocumentFilenameFallsBackForUnsafeEmptyValue() {
        XCTAssertEqual(
            InvoiceDocumentFilename.pdf(invoiceNumber: " .\n/\\: "),
            "Invoice-Invoice.pdf"
        )
    }

    func testDocumentFilenameLimitsInvoiceNumberLength() {
        let filename = InvoiceDocumentFilename.pdf(invoiceNumber: String(repeating: "A", count: 200))

        XCTAssertEqual(filename.count, 96 + "Invoice-.pdf".count)
        XCTAssertTrue(filename.hasSuffix(".pdf"))
    }

    func testDocumentFilenameLimitsMultibyteValuesByFilesystemBytes() {
        let filename = InvoiceDocumentFilename.pdf(invoiceNumber: String(repeating: "🧾", count: 100))

        XCTAssertLessThanOrEqual(filename.utf8.count, 96 + "Invoice-.pdf".utf8.count)
        XCTAssertTrue(filename.hasSuffix(".pdf"))
    }

    func testDecimalInputRequiresCompleteLocalizedNumber() {
        let locale = Locale(identifier: "en_AU")

        XCTAssertEqual(InvoiceDecimalInput.parse("12.5", locale: locale), Decimal(string: "12.5"))
        XCTAssertEqual(InvoiceDecimalInput.parse("1,234.50", locale: locale), Decimal(string: "1234.5"))
        XCTAssertNil(InvoiceDecimalInput.parse("12x", locale: locale))
        XCTAssertNil(InvoiceDecimalInput.parse("", locale: locale))
        XCTAssertNil(InvoiceDecimalInput.parse("  ", locale: locale))
    }

    func testDecimalInputRoundTripsLocalizedDisplay() {
        let locale = Locale(identifier: "de_DE")
        let value = Decimal(string: "1234.5")!
        let display = InvoiceDecimalInput.string(for: value, locale: locale)

        XCTAssertEqual(InvoiceDecimalInput.parse(display, locale: locale), value)
    }

    func testTemplateDoubleInputRequiresCompleteInRangeLocalizedNumber() {
        let locale = Locale(identifier: "en_AU")
        let range = 0.75...2.0

        XCTAssertEqual(InvoiceDoubleInput.parse("1.25", in: range, locale: locale), 1.25)
        XCTAssertNil(InvoiceDoubleInput.parse("1.2x", in: range, locale: locale))
        XCTAssertNil(InvoiceDoubleInput.parse("0.5", in: range, locale: locale))
        XCTAssertNil(InvoiceDoubleInput.parse("2.1", in: range, locale: locale))
        XCTAssertNil(InvoiceDoubleInput.parse("", in: range, locale: locale))
    }

    func testTemplateDoubleInputRoundTripsLocalizedDisplay() {
        let locale = Locale(identifier: "de_DE")
        let display = InvoiceDoubleInput.string(for: 1.25, locale: locale)

        XCTAssertEqual(
            InvoiceDoubleInput.parse(display, in: 0.5...2.0, locale: locale),
            1.25
        )
    }

    func testLatestLoadingRequestOwnsActivityCompletion() {
        var activity = InvoiceLatestRequestActivity()
        let first = UUID()
        let second = UUID()

        activity.begin(first)
        activity.begin(second)
        activity.finish(first)

        XCTAssertTrue(activity.isActive)
        XCTAssertEqual(activity.requestID, second)

        activity.finish(second)
        XCTAssertFalse(activity.isActive)
    }

    func testInvoiceEditorActivityStateReportsWorkBeforeSavedState() {
        XCTAssertEqual(
            InvoiceEditorActivityState.resolve(
                isLoading: false,
                isSaving: false,
                isGeneratingDocument: true,
                isPerformingLifecycleOperation: false,
                hasRevisionConflict: false,
                hasUnsavedChanges: false
            ),
            .preparingDocument
        )
        XCTAssertEqual(InvoiceEditorActivityState.preparingDocument.title, "Preparing document…")
        XCTAssertTrue(InvoiceEditorActivityState.preparingDocument.isActive)

        XCTAssertEqual(
            InvoiceEditorActivityState.resolve(
                isLoading: false,
                isSaving: false,
                isGeneratingDocument: false,
                isPerformingLifecycleOperation: false,
                hasRevisionConflict: true,
                hasUnsavedChanges: false
            ),
            .conflict
        )
        XCTAssertEqual(InvoiceEditorActivityState.conflict.title, "Needs attention")
        XCTAssertFalse(InvoiceEditorActivityState.conflict.isActive)
    }

    func testInvoiceEditorActivityStateUsesDeterministicPriority() {
        XCTAssertEqual(
            InvoiceEditorActivityState.resolve(
                isLoading: true,
                isSaving: true,
                isGeneratingDocument: true,
                isPerformingLifecycleOperation: true,
                hasRevisionConflict: true,
                hasUnsavedChanges: true
            ),
            .opening
        )
        XCTAssertEqual(
            InvoiceEditorActivityState.resolve(
                isLoading: false,
                isSaving: false,
                isGeneratingDocument: false,
                isPerformingLifecycleOperation: false,
                hasRevisionConflict: false,
                hasUnsavedChanges: true
            ),
            .unsaved
        )
    }

    func testProgressPresentationKeepsTemplateAndInvoiceActivitySeparate() {
        XCTAssertEqual(
            InvoiceEditorProgressPresentation.resolve(
                mode: .template,
                templateSaveState: .saving,
                isCreatingInvoiceFromTemplate: false,
                invoiceActivity: .saved,
                canCancelDocumentAction: false
            ),
            InvoiceEditorProgressPresentation(
                title: "Saving template…",
                allowsCancellation: false
            )
        )
        XCTAssertEqual(
            InvoiceEditorProgressPresentation.resolve(
                mode: .template,
                templateSaveState: .saving,
                isCreatingInvoiceFromTemplate: true,
                invoiceActivity: .preparingDocument,
                canCancelDocumentAction: true
            ),
            InvoiceEditorProgressPresentation(
                title: "Creating invoice…",
                allowsCancellation: false
            )
        )
        XCTAssertNil(
            InvoiceEditorProgressPresentation.resolve(
                mode: .template,
                templateSaveState: .saved,
                isCreatingInvoiceFromTemplate: false,
                invoiceActivity: .opening,
                canCancelDocumentAction: true
            )
        )
    }

    func testInvoiceProgressPresentationOffersCancellationOnlyForDocumentGeneration() {
        XCTAssertEqual(
            InvoiceEditorProgressPresentation.resolve(
                mode: .invoice,
                templateSaveState: .saving,
                isCreatingInvoiceFromTemplate: true,
                invoiceActivity: .opening,
                canCancelDocumentAction: true
            ),
            InvoiceEditorProgressPresentation(
                title: "Opening…",
                allowsCancellation: false
            )
        )
        XCTAssertEqual(
            InvoiceEditorProgressPresentation.resolve(
                mode: .invoice,
                templateSaveState: .saved,
                isCreatingInvoiceFromTemplate: false,
                invoiceActivity: .preparingDocument,
                canCancelDocumentAction: true
            ),
            InvoiceEditorProgressPresentation(
                title: "Preparing document…",
                allowsCancellation: true
            )
        )
        XCTAssertNil(
            InvoiceEditorProgressPresentation.resolve(
                mode: .invoice,
                templateSaveState: .failed,
                isCreatingInvoiceFromTemplate: false,
                invoiceActivity: .unsaved,
                canCancelDocumentAction: true
            )
        )
    }

    func testPaginationMeasurementsCollapseSubpixelLayoutNoise() {
        XCTAssertEqual(InvoicePaginationMeasurementStability.normalizedHeight(100.24), 100)
        XCTAssertEqual(InvoicePaginationMeasurementStability.normalizedHeight(100.26), 100.5)
        XCTAssertEqual(InvoicePaginationMeasurementStability.normalizedHeight(100.49), 100.5)
        XCTAssertEqual(InvoicePaginationMeasurementStability.normalizedHeight(100.51), 100.5)
    }

    func testPaginationMeasurementsRejectInvalidOrNegativeHeights() {
        XCTAssertEqual(InvoicePaginationMeasurementStability.normalizedHeight(-12), 0)
        XCTAssertEqual(InvoicePaginationMeasurementStability.normalizedHeight(.infinity), 0)
        XCTAssertEqual(InvoicePaginationMeasurementStability.normalizedHeight(.nan), 0)
    }

    func testPaginationMeasurementRepublishesAfterModelCacheInvalidation() {
        let (dimensions, _) = InvoicePagination.MeasuredHeights.uniformRows(
            count: 1,
            rowHeight: 44
        )

        XCTAssertFalse(
            InvoicePaginationMeasurementPublicationPolicy.shouldStage(
                incoming: dimensions,
                reporterLatest: dimensions,
                modelCurrent: dimensions
            )
        )
        XCTAssertTrue(
            InvoicePaginationMeasurementPublicationPolicy.shouldStage(
                incoming: dimensions,
                reporterLatest: dimensions,
                modelCurrent: nil
            )
        )
    }

    func testPaginationMeasurementRejectsPreviousDocumentToken() {
        XCTAssertTrue(
            InvoicePaginationMeasurementPublicationPolicy.ownsCurrentContent(
                stagedContentToken: "invoice-b",
                currentContentToken: "invoice-b"
            )
        )
        XCTAssertFalse(
            InvoicePaginationMeasurementPublicationPolicy.ownsCurrentContent(
                stagedContentToken: "invoice-a",
                currentContentToken: "invoice-b"
            )
        )
    }

    @MainActor
    func testPaginationSectionReporterCoalescesInputInvalidations() async throws {
        let reporter = InvoicePaginationSectionReporter(
            reportingDelay: .milliseconds(1)
        )

        reporter.invalidate()
        reporter.invalidate()
        try await Task.sleep(for: .milliseconds(10))

        XCTAssertEqual(reporter.publicationRevision, 1)

        reporter.invalidate()
        try await Task.sleep(for: .milliseconds(10))

        XCTAssertEqual(reporter.publicationRevision, 2)
    }

    func testPreviewFitScaleCollapsesSubpixelResizeNoise() {
        XCTAssertEqual(InvoiceDocumentPreviewZoom.stabilizedFitScale(0.812_41), 0.812)
        XCTAssertEqual(InvoiceDocumentPreviewZoom.stabilizedFitScale(0.812_49), 0.812)
        XCTAssertEqual(InvoiceDocumentPreviewZoom.stabilizedFitScale(0.812_51), 0.813)
        XCTAssertEqual(InvoiceDocumentPreviewZoom.stabilizedFitScale(.nan), 1)
    }

    @MainActor
    func testDocumentActionCancellationInvokesInstalledActionOnce() {
        let cancellation = InvoiceDocumentActionCancellation()
        var invocationCount = 0
        cancellation.install { invocationCount += 1 }

        XCTAssertTrue(cancellation.isInstalled)
        cancellation.cancel()
        cancellation.cancel()

        XCTAssertEqual(invocationCount, 1)
        XCTAssertFalse(cancellation.isInstalled)
    }

    @MainActor
    func testDocumentActionCancellationCanClearWithoutInvokingAction() {
        let cancellation = InvoiceDocumentActionCancellation()
        var wasInvoked = false
        cancellation.install { wasInvoked = true }
        cancellation.clear()
        cancellation.cancel()

        XCTAssertFalse(wasInvoked)
        XCTAssertFalse(cancellation.isInstalled)
    }

    func testWorkspaceModesExposeOnlyTheirOwnedInspectorConcern() {
        XCTAssertTrue(InvoiceEditorWorkspaceMode.invoice.usesPersistedInvoiceData)
        XCTAssertEqual(InvoiceEditorWorkspaceMode.invoice.inspectorMode, .invoiceData)
        XCTAssertFalse(InvoiceEditorWorkspaceMode.template.usesPersistedInvoiceData)
        XCTAssertEqual(InvoiceEditorWorkspaceMode.template.inspectorMode, .templateFormatting)
        XCTAssertNotEqual(
            InvoiceEditorWorkspaceMode.invoice.inspectorSceneStorageKey,
            InvoiceEditorWorkspaceMode.template.inspectorSceneStorageKey
        )
    }

    func testTemplateExitPersistsValidStateAroundUnfinishedExactValueDrafts() {
        XCTAssertTrue(
            InvoiceTemplatePersistenceIntent.leaveWorkspace.permitsPersistence(
                hasInvalidInputs: true
            )
        )
        XCTAssertTrue(
            InvoiceTemplatePersistenceIntent.leaveWorkspace.permitsPersistence(
                hasInvalidInputs: false
            )
        )
    }

    func testTemplateCreationStillRequiresEveryExactValueToBeValid() {
        XCTAssertFalse(
            InvoiceTemplatePersistenceIntent.createInvoice.permitsPersistence(
                hasInvalidInputs: true
            )
        )
        XCTAssertTrue(
            InvoiceTemplatePersistenceIntent.createInvoice.permitsPersistence(
                hasInvalidInputs: false
            )
        )
    }

    func testEditorCreationActivityIncludesFeatureOwnedRequests() {
        XCTAssertFalse(
            InvoiceEditorCreationActivityPolicy.isActive(
                localRequest: false,
                featureRequest: false
            )
        )
        XCTAssertTrue(
            InvoiceEditorCreationActivityPolicy.isActive(
                localRequest: true,
                featureRequest: false
            )
        )
        XCTAssertTrue(
            InvoiceEditorCreationActivityPolicy.isActive(
                localRequest: false,
                featureRequest: true
            )
        )
    }

    func testCreationRequestStateRejectsOverlapAndIgnoresStaleCompletion() throws {
        var state = InvoiceEditorCreationRequestState()
        let firstRequest = try XCTUnwrap(state.begin())

        XCTAssertTrue(state.isActive)
        XCTAssertNil(state.begin())

        state.invalidatePresentation()
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.owns(firstRequest))

        let secondRequest = try XCTUnwrap(state.begin())
        state.finish(firstRequest)

        XCTAssertTrue(state.isActive)
        XCTAssertTrue(state.owns(secondRequest))

        state.finish(secondRequest)
        XCTAssertFalse(state.isActive)
    }

    func testFailedInitialOpenKeepsRequestedSelectionAvailableForRetry() {
        let requestedID = UUID()

        XCTAssertFalse(
            InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: requestedID,
                openedID: nil
            )
        )
        XCTAssertTrue(
            InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: requestedID,
                openedID: requestedID
            )
        )
        XCTAssertFalse(
            InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: requestedID,
                openedID: UUID()
            )
        )
        XCTAssertTrue(
            InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: nil,
                openedID: nil
            )
        )
        XCTAssertTrue(
            InvoiceWorkspaceOpeningPolicy.shouldPublishSelection(
                requestedID: requestedID,
                openedID: UUID(),
                hasOpenDocument: true
            )
        )
    }

    func testOnlyCurrentExternalSelectionRequestMayReconcileListBinding() {
        let firstRequest = UUID()
        let newerRequest = UUID()

        XCTAssertFalse(
            InvoiceExternalSelectionPublicationPolicy.requestIsCurrent(
                requestedID: firstRequest,
                externalID: newerRequest
            )
        )
        XCTAssertTrue(
            InvoiceExternalSelectionPublicationPolicy.requestIsCurrent(
                requestedID: newerRequest,
                externalID: newerRequest
            )
        )
        XCTAssertTrue(
            InvoiceExternalSelectionPublicationPolicy.requestIsCurrent(
                requestedID: nil,
                externalID: nil
            )
        )
    }

    func testOpeningRecoveryRetainsOnlyFailedColdRequest() {
        let requestedID = UUID()

        XCTAssertEqual(
            InvoiceWorkspaceOpeningPolicy.failedRequestID(
                requestedID: requestedID,
                openedID: nil,
                hasOpenDocument: false
            ),
            requestedID
        )
        XCTAssertNil(
            InvoiceWorkspaceOpeningPolicy.failedRequestID(
                requestedID: requestedID,
                openedID: requestedID,
                hasOpenDocument: true
            )
        )
        XCTAssertNil(
            InvoiceWorkspaceOpeningPolicy.failedRequestID(
                requestedID: requestedID,
                openedID: UUID(),
                hasOpenDocument: true
            )
        )
        XCTAssertNil(
            InvoiceWorkspaceOpeningPolicy.failedRequestID(
                requestedID: nil,
                openedID: nil,
                hasOpenDocument: false
            )
        )
    }

    @MainActor
    func testTemplateCommandContextExposesInspectorAndPreviewWithoutClaimingInvoiceCommands() {
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

        XCTAssertFalse(actions.isInvoiceContext)
        XCTAssertFalse(actions.canCreate)
        XCTAssertFalse(actions.canSave)
        XCTAssertFalse(actions.canAddLineItem)
        XCTAssertTrue(actions.canToggleInspector)
        XCTAssertTrue(actions.canZoomIn)
        XCTAssertTrue(actions.canZoomOut)
        XCTAssertTrue(actions.canSetActualSize)
        XCTAssertFalse(actions.canFitWidth)
    }

    @MainActor
    func testPreviewCommandClosuresRemainIndependentFromInvoiceDataCommands() {
        let actions = InvoiceEditorCommandActions()
        var zoomInCount = 0
        var fitWidthCount = 0
        actions.zoomIn = { zoomInCount += 1 }
        actions.fitWidth = { fitWidthCount += 1 }

        actions.zoomIn()
        actions.fitWidth()

        XCTAssertEqual(zoomInCount, 1)
        XCTAssertEqual(fitWidthCount, 1)
        XCTAssertFalse(actions.isInvoiceContext)
        XCTAssertFalse(actions.canSave)
    }

    @MainActor
    func testFocusedEditorCanGateWorkspaceCreationWithoutOwningCreation() async {
        let actions = InvoiceEditorCommandActions()
        var preparationCount = 0
        actions.prepareForInvoiceCreation = {
            preparationCount += 1
            return false
        }

        let isPrepared = await actions.prepareForInvoiceCreation()
        XCTAssertFalse(isPrepared)
        XCTAssertEqual(preparationCount, 1)
    }

    @MainActor
    func testInvoiceCommandContextPublishesAddLineItemCapability() {
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

        XCTAssertTrue(actions.isInvoiceContext)
        XCTAssertTrue(actions.canAddLineItem)
    }

    @MainActor
    func testAddLineItemRequestsHaveMonotonicRevision() {
        let toolbarState = InvoiceEditorToolbarState()

        XCTAssertEqual(toolbarState.addLineItemRequestRevision, 0)
        toolbarState.requestAddLineItem()
        XCTAssertEqual(toolbarState.addLineItemRequestRevision, 1)
        toolbarState.requestAddLineItem()
        XCTAssertEqual(toolbarState.addLineItemRequestRevision, 2)
    }

    @MainActor
    func testInvalidTemplateRecoveryRequestsHaveMonotonicRevision() {
        let toolbarState = InvoiceEditorToolbarState()

        XCTAssertEqual(toolbarState.invalidTemplateInputRecoveryRequestRevision, 0)
        toolbarState.requestInvalidTemplateInputRecovery()
        XCTAssertEqual(toolbarState.invalidTemplateInputRecoveryRequestRevision, 1)
        toolbarState.requestInvalidTemplateInputRecovery()
        XCTAssertEqual(toolbarState.invalidTemplateInputRecoveryRequestRevision, 2)
    }

    @MainActor
    func testNumericInputResetRevisionAdvancesEvenWhenTypedBaselineIsUnchanged() {
        let drafts = InvoiceNumericInputDraftStore()
        let toolbarState = InvoiceEditorToolbarState(numericInputDrafts: drafts)
        drafts.preserve("invalid", for: "template.page.width", baseline: "595")

        let clearedIDs = toolbarState.resetNumericInputDrafts()

        XCTAssertEqual(Set(clearedIDs), Set(["template.page.width"]))
        XCTAssertEqual(toolbarState.numericInputResetRevision, 1)
        XCTAssertTrue(drafts.inputIDs.isEmpty)

        toolbarState.resetNumericInputDraft("template.page.width")
        XCTAssertEqual(toolbarState.numericInputResetRevision, 2)
    }

    @MainActor
    func testTemplateNumericOverrideAppliesValueBeforeClearingInvalidDraft() {
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

        XCTAssertEqual(resolvedValue, 1.25)
        XCTAssertTrue(drafts.inputIDs.isEmpty)
        XCTAssertEqual(toolbarState.numericInputResetRevision, 1)
        XCTAssertEqual(validityEvents.first?.0, inputID)
        XCTAssertEqual(validityEvents.first?.1, false)
        XCTAssertEqual(validityEvents.first?.2, 1.25)
    }

    @MainActor
    func testLineItemUndoActionsAreRemovedWhenDocumentChanges() {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        let coordinator = InvoiceLineItemUndoCoordinator()

        undoManager.beginUndoGrouping()
        _ = coordinator.addLineItem(to: viewModel, undoManager: undoManager)
        undoManager.endUndoGrouping()
        XCTAssertTrue(undoManager.canUndo)

        let nextDocumentID = UUID()
        coordinator.activateDocument(id: nextDocumentID, undoManager: undoManager)

        XCTAssertEqual(coordinator.activeDocumentID, nextDocumentID)
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertFalse(undoManager.canRedo)
    }

    @MainActor
    func testStaleLineItemUndoCannotMutateDifferentDocument() {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        let coordinator = InvoiceLineItemUndoCoordinator()
        let originalCount = viewModel.lineItems.count

        undoManager.beginUndoGrouping()
        _ = coordinator.addLineItem(to: viewModel, undoManager: undoManager)
        undoManager.endUndoGrouping()
        XCTAssertEqual(viewModel.lineItems.count, originalCount + 1)

        viewModel.selectedInvoiceID = UUID()
        undoManager.undo()

        XCTAssertEqual(viewModel.lineItems.count, originalCount + 1)
    }

    func testNumericInputDraftStoreRestoresOnlyAgainstSameTypedBaseline() {
        let store = InvoiceNumericInputDraftStore()

        store.preserve("not a number", for: "tax", baseline: "10")

        XCTAssertEqual(
            store.restoredText(for: "tax", baseline: "10"),
            "not a number"
        )
        XCTAssertNil(store.restoredText(for: "tax", baseline: "15"))
        XCTAssertNil(store.restoredText(for: "tax", baseline: "10"))
    }

    func testNumericInputDraftStoreClearsAllTrackedFields() {
        let store = InvoiceNumericInputDraftStore()
        store.preserve("bad", for: "margin", baseline: "24")
        store.preserve("also bad", for: "scale", baseline: "1")

        XCTAssertEqual(Set(store.clearAll()), ["margin", "scale"])
        XCTAssertNil(store.restoredText(for: "margin", baseline: "24"))
        XCTAssertNil(store.restoredText(for: "scale", baseline: "1"))
    }

    func testNumericInputDraftStoreRoundTripsSceneSnapshot() {
        let source = InvoiceNumericInputDraftStore()
        source.preserve("invalid", for: "spacing", baseline: "1")

        let restored = InvoiceNumericInputDraftStore()
        restored.restore(from: source.encodedSnapshot)

        XCTAssertEqual(restored.inputIDs, ["spacing"])
        XCTAssertEqual(
            restored.restoredText(for: "spacing", baseline: "1"),
            "invalid"
        )
    }

    func testTemplatePreferenceStoreRoundTripsConfiguration() throws {
        let suiteName = "InvoiceTemplatePreferenceStoreTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .burgundy
        configuration.headerStyle = .compact
        configuration.tableStyle = .borderless

        XCTAssertTrue(InvoiceTemplatePreferenceStore.save(configuration, to: preferences))

        XCTAssertEqual(InvoiceTemplatePreferenceStore.load(from: preferences), configuration)
    }

    func testTemplatePreferenceStoreRoundTripsCompletePageSetup() throws {
        let suiteName = "InvoiceTemplateDefaultsTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .forest
        let defaults = InvoiceTemplateDefaults(
            paperSize: .legal,
            pageOrientation: .landscape,
            configuration: configuration
        )

        XCTAssertTrue(InvoiceTemplatePreferenceStore.save(defaults, to: preferences))
        XCTAssertEqual(InvoiceTemplatePreferenceStore.loadDefaults(from: preferences), defaults)
    }

    func testTemplateSaveTrackerWritesOnlyGenuineLocalChanges() {
        var tracker = InvoiceTemplateSaveTracker()
        let original = InvoiceTemplateDefaults()
        var edited = original
        edited.configuration.accentTheme = .forest

        XCTAssertTrue(tracker.requiresSave(original))

        tracker.markSaved(original)
        XCTAssertFalse(tracker.requiresSave(original))
        XCTAssertTrue(tracker.requiresSave(edited))

        tracker.markSaved(edited)
        XCTAssertFalse(tracker.requiresSave(edited))
    }

    func testTemplateInvalidInputHasDistinctPersistenceFeedback() {
        XCTAssertEqual(InvoiceTemplateSaveState.invalid.title, "Fix values")
        XCTAssertNotEqual(InvoiceTemplateSaveState.invalid, .saved)
        XCTAssertNotEqual(InvoiceTemplateSaveState.invalid, .saving)
        XCTAssertNotEqual(InvoiceTemplateSaveState.invalid, .failed)
    }

    func testEditorCommandCapabilitiesTrackWorkspaceAndViewportState() {
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

        XCTAssertFalse(fitWidthAtMinimum.isInvoiceContext)
        XCTAssertTrue(fitWidthAtMinimum.canCreate)
        XCTAssertFalse(fitWidthAtMinimum.canSave)
        XCTAssertTrue(fitWidthAtMinimum.canToggleInspector)
        XCTAssertFalse(fitWidthAtMinimum.canZoomOut)
        XCTAssertFalse(fitWidthAtMinimum.canFitWidth)

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

        XCTAssertFalse(invalidTemplate.canCreate)

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

        XCTAssertTrue(activeInvoice.isInvoiceContext)
        XCTAssertTrue(activeInvoice.canCreate)
        XCTAssertTrue(activeInvoice.canSave)
        XCTAssertTrue(activeInvoice.canAddLineItem)
        XCTAssertTrue(activeInvoice.canFitWidth)
        XCTAssertFalse(activeInvoice.canSetActualSize)

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

        XCTAssertFalse(busyInvoice.canCreate)
        XCTAssertFalse(busyInvoice.canSave)
        XCTAssertFalse(busyInvoice.canAddLineItem)
        XCTAssertTrue(busyInvoice.canZoomIn)
    }

    func testTemplateSaveRecoveryAppearsOnlyForActionablePersistenceFailure() {
        XCTAssertEqual(
            InvoiceTemplateSaveRecoveryPolicy.issue(
                saveState: .failed,
                hasInvalidInputs: true
            ),
            .invalidInputs
        )
        XCTAssertEqual(
            InvoiceTemplateSaveRecoveryPolicy.issue(
                saveState: .failed,
                hasInvalidInputs: false
            ),
            .saveFailure
        )
        XCTAssertEqual(
            InvoiceTemplateSaveRecoveryPolicy.issue(
                saveState: .saved,
                hasInvalidInputs: true
            ),
            .invalidInputs
        )
        XCTAssertNil(
            InvoiceTemplateSaveRecoveryPolicy.issue(
                saveState: .saved,
                hasInvalidInputs: false
            )
        )

        XCTAssertTrue(
            InvoiceTemplateSaveRecoveryPolicy.showsFailureRecovery(
                saveState: .failed,
                hasInvalidInputs: false
            )
        )
        XCTAssertFalse(
            InvoiceTemplateSaveRecoveryPolicy.showsFailureRecovery(
                saveState: .failed,
                hasInvalidInputs: true
            )
        )
        XCTAssertFalse(
            InvoiceTemplateSaveRecoveryPolicy.showsFailureRecovery(
                saveState: .saved,
                hasInvalidInputs: false
            )
        )

        XCTAssertEqual(
            InvoiceTemplateSaveRecoveryPolicy.reconciledState(
                .failed,
                requiresSave: false
            ),
            .saved
        )
        XCTAssertEqual(
            InvoiceTemplateSaveRecoveryPolicy.reconciledState(
                .failed,
                requiresSave: true
            ),
            .failed
        )
    }

    func testTemplatePreferenceStoreMigratesLegacyRawConfiguration() throws {
        let suiteName = "InvoiceTemplateLegacyDefaultsTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .burgundy
        preferences.set(
            try JSONEncoder().encode(configuration),
            forKey: InvoiceTemplatePreferenceStore.preferenceKey
        )

        let defaults = InvoiceTemplatePreferenceStore.loadDefaults(from: preferences)

        XCTAssertEqual(defaults.paperSize, .default)
        XCTAssertEqual(defaults.pageOrientation, .portrait)
        XCTAssertEqual(defaults.configuration.accentTheme, .burgundy)
    }

    func testLegacyTemplatePayloadPreservesKnownValuesAndDefaultsMissingFields() throws {
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

        XCTAssertEqual(configuration.accentTheme, .burgundy)
        XCTAssertFalse(configuration.showPaymentDetails)
        XCTAssertEqual(configuration.customAccentColor?.opacity, 1)
        XCTAssertFalse(configuration.columnVisibility.showDate)
        XCTAssertTrue(configuration.columnVisibility.showRate)
        XCTAssertEqual(configuration.headerStyle, .default)
    }

    func testMalformedTemplateFieldFallsBackWithoutDiscardingValidFields() throws {
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

        XCTAssertEqual(configuration.accentTheme, .burgundy)
        XCTAssertEqual(configuration.headerStyle, .default)
        XCTAssertFalse(configuration.showPaymentTerms)
    }

    func testExtremePersistedGeometryIsClampedToLayoutSafeBounds() throws {
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

        XCTAssertEqual(configuration.customPageWidthPoints, InvoiceTemplateLayoutLimits.pageDimensionRange.upperBound)
        XCTAssertEqual(configuration.customPageHeightPoints, InvoiceTemplateLayoutLimits.pageDimensionRange.lowerBound)
        XCTAssertEqual(configuration.customMarginPoints, InvoiceTemplateLayoutLimits.storedMarginRange.upperBound)
        XCTAssertEqual(configuration.customTypographyScale, InvoiceTemplateLayoutLimits.typographyScaleRange.upperBound)
        XCTAssertEqual(configuration.customSpacingScale, InvoiceTemplateLayoutLimits.spacingScaleRange.lowerBound)
        XCTAssertEqual(configuration.customBorderWidth, InvoiceTemplateLayoutLimits.borderWidthRange.upperBound)
        XCTAssertEqual(configuration.customAccentColor?.red, 1)
        XCTAssertEqual(configuration.customAccentColor?.green, 0)
        XCTAssertEqual(configuration.customAccentColor?.opacity, 1)
    }

    @MainActor
    func testPageGeometryAppliesPartialOverridesAndRetainsPrintableArea() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)
        let standardHeight = viewModel.paperSize.sizePoints(for: viewModel.pageOrientation).height

        viewModel.customPageWidthPoints = 900
        viewModel.customMarginPoints = 100_000

        XCTAssertEqual(viewModel.pageSizePoints.width, 900)
        XCTAssertEqual(viewModel.pageSizePoints.height, standardHeight)
        XCTAssertGreaterThanOrEqual(
            viewModel.pageSizePoints.width - (viewModel.effectiveMarginPoints * 2),
            InvoiceTemplateLayoutLimits.minimumContentDimension
        )
        XCTAssertGreaterThanOrEqual(
            viewModel.pageSizePoints.height - (viewModel.effectiveMarginPoints * 2),
            InvoiceTemplateLayoutLimits.minimumContentDimension
        )
    }

    func testTemplateMarginInputRangePreservesMinimumPrintableArea() {
        let pageSize = CGSize(width: 600, height: 900)
        let maximum = InvoiceTemplateLayoutLimits.maximumMargin(for: pageSize)

        XCTAssertEqual(maximum, 264)
        XCTAssertEqual(
            InvoiceTemplateLayoutLimits.effectiveMargin(1_000, pageSize: pageSize),
            264
        )
        XCTAssertEqual(
            InvoiceDoubleInput.parse("264", in: 0...maximum),
            264
        )
        XCTAssertNil(InvoiceDoubleInput.parse("264.1", in: 0...maximum))
    }

    @MainActor
    func testCustomPageOrientationSwapsResolvedDimensionsAndUpdatesLabel() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.customPageWidthPoints = 900
        viewModel.customPageHeightPoints = 600

        viewModel.updatePageOrientation(.landscape)

        XCTAssertEqual(viewModel.pageOrientation, .landscape)
        XCTAssertEqual(viewModel.pageSizePoints.width, 600)
        XCTAssertEqual(viewModel.pageSizePoints.height, 900)
        XCTAssertEqual(viewModel.pageDimensionsLabel, "600 × 900 pt")
    }

    @MainActor
    func testStandardPageOrientationKeepsStandardSizingImplicit() throws {
        let viewModel = InvoiceEditorViewModel()

        viewModel.updatePageOrientation(.landscape)

        XCTAssertNil(viewModel.customPageWidthPoints)
        XCTAssertNil(viewModel.customPageHeightPoints)
        XCTAssertEqual(viewModel.pageSizePoints, PaperSize.a4.sizePoints(for: .landscape))
        XCTAssertEqual(viewModel.pageDimensionsLabel, "297 × 210 mm")
    }

    @MainActor
    func testTemplatePreviewDoesNotOfferInvoiceDataTargeting() {
        let interaction = InvoicePreviewInspectorInteraction(mode: .templateFormatting)

        interaction.select(.sellerName)

        XCTAssertNil(interaction.focusRequest)
        XCTAssertEqual(interaction.formatInspectorRevealRevision, 1)
        XCTAssertEqual(interaction.requestedFormatSection, .content)
        XCTAssertFalse(interaction.allowsFieldTargeting)
        XCTAssertTrue(interaction.allowsFormatInspectorReveal)
        XCTAssertTrue(interaction.allowsPreviewTargetSelection)
        XCTAssertEqual(
            interaction.accessibilityLabel(for: .sellerName),
            "Format sender name"
        )
        XCTAssertEqual(
            interaction.accessibilityHint(for: .sellerName),
            "Opens Content format section without changing mock invoice data"
        )
        XCTAssertEqual(
            interaction.helpText(for: .sellerName),
            "Format sender name in Content"
        )
    }

    @MainActor
    func testTemplatePreviewRoutesDocumentRegionsToRelevantFormatSections() {
        let interaction = InvoicePreviewInspectorInteraction(mode: .templateFormatting)

        interaction.select(.header)
        XCTAssertEqual(interaction.requestedFormatSection, .template)

        interaction.select(.lineItemDescription(UUID()))
        XCTAssertEqual(interaction.requestedFormatSection, .lineItems)

        interaction.select(.paymentDetails)
        XCTAssertEqual(interaction.requestedFormatSection, .content)
        XCTAssertEqual(interaction.formatInspectorRevealRevision, 3)
        XCTAssertNil(interaction.focusRequest)
    }

    @MainActor
    func testRepeatedPreviewSelectionCreatesDistinctFocusRequests() {
        let interaction = InvoicePreviewInspectorInteraction()

        interaction.select(.invoiceNumber)
        let firstRequest = interaction.focusRequest
        interaction.select(.invoiceNumber)
        let secondRequest = interaction.focusRequest

        XCTAssertEqual(firstRequest?.target, .invoiceNumber)
        XCTAssertEqual(secondRequest?.target, .invoiceNumber)
        XCTAssertNotEqual(firstRequest?.id, secondRequest?.id)
        XCTAssertEqual(interaction.formatInspectorRevealRevision, 0)
        XCTAssertTrue(interaction.allowsFieldTargeting)
        XCTAssertFalse(interaction.allowsFormatInspectorReveal)
        XCTAssertTrue(interaction.allowsPreviewTargetSelection)
    }

    @MainActor
    func testCompletingSupersededPreviewFocusDoesNotClearLatestRequest() throws {
        let interaction = InvoicePreviewInspectorInteraction()

        interaction.select(.invoiceNumber)
        let firstRequest = try XCTUnwrap(interaction.focusRequest)
        interaction.select(.clientName)
        let secondRequest = try XCTUnwrap(interaction.focusRequest)

        interaction.completeFocusRequest(id: firstRequest.id)
        XCTAssertEqual(interaction.focusRequest, secondRequest)

        interaction.completeFocusRequest(id: secondRequest.id)
        XCTAssertNil(interaction.focusRequest)
    }

    func testDeferredInspectorFocusLeaseRequiresMatchingDocumentAndLatestLease() {
        let firstDocumentID = UUID()
        let secondDocumentID = UUID()
        let leaseID = UUID()
        let lease = InvoiceInspectorDeferredFocusLease(
            id: leaseID,
            documentID: firstDocumentID
        )

        XCTAssertTrue(
            lease.isCurrent(
                activeLeaseID: leaseID,
                selectedDocumentID: firstDocumentID
            )
        )
        XCTAssertFalse(
            lease.isCurrent(
                activeLeaseID: UUID(),
                selectedDocumentID: firstDocumentID
            )
        )
        XCTAssertFalse(
            lease.isCurrent(
                activeLeaseID: leaseID,
                selectedDocumentID: secondDocumentID
            )
        )
        XCTAssertFalse(
            lease.isCurrent(
                activeLeaseID: nil,
                selectedDocumentID: firstDocumentID
            )
        )
    }

    @MainActor
    func testStatusBannerAutoDismissesSuccessButKeepsActionableErrors() {
        XCTAssertTrue(InvoiceEditorStatusBanner.shouldAutoDismiss("Invoice saved."))
        XCTAssertTrue(InvoiceEditorStatusBanner.shouldAutoDismiss("Unsaved changes discarded."))
        XCTAssertFalse(InvoiceEditorStatusBanner.shouldAutoDismiss("Failed to save invoice: unavailable"))
        XCTAssertFalse(
            InvoiceEditorStatusBanner.shouldAutoDismiss(
                "Invoice couldn't be created. Store unavailable."
            )
        )
        XCTAssertFalse(
            InvoiceEditorStatusBanner.shouldAutoDismiss(
                "Fix the errors in the Validation section before switching invoices."
            )
        )
        XCTAssertFalse(
            InvoiceEditorStatusBanner.shouldAutoDismiss(
                "This invoice was deleted in another window. Your local draft is still available."
            )
        )
        XCTAssertFalse(
            InvoiceEditorStatusBanner.shouldAutoDismiss(
                "Current draft could not be saved."
            )
        )
        XCTAssertEqual(InvoiceEditorStatusBanner.tone(for: "Invoice saved."), .success)
        XCTAssertEqual(InvoiceEditorStatusBanner.tone(for: "Export cancelled."), .informational)
        XCTAssertEqual(InvoiceEditorStatusBanner.tone(for: "Unsaved changes discarded."), .informational)
        XCTAssertEqual(
            InvoiceEditorStatusBanner.tone(for: "Failed to save invoice: unavailable"),
            .error
        )
        XCTAssertEqual(
            InvoiceEditorStatusBanner.tone(
                for: "Invoice couldn't be created. Store unavailable."
            ),
            .error
        )
        XCTAssertEqual(
            InvoiceEditorStatusBanner.tone(
                for: "This invoice was deleted in another window. Your local draft is still available."
            ),
            .error
        )
        XCTAssertNil(
            InvoiceEditorStatusBanner.messageForPresentation(
                "Applied Modern template.",
                whileTemplateSaveFailed: true
            )
        )
        XCTAssertEqual(
            InvoiceEditorStatusBanner.messageForPresentation(
                "Failed to load invoice: unavailable",
                whileTemplateSaveFailed: true
            ),
            "Failed to load invoice: unavailable"
        )
    }

    @MainActor
    func testStatusDismissalCannotClearNewerFeedback() {
        let viewModel = InvoiceEditorViewModel()
        viewModel.statusMessage = "Invoice saved."
        let staleMessageID = viewModel.statusMessageID

        viewModel.statusMessage = "Failed to save invoice: Store unavailable."
        let latestMessageID = viewModel.statusMessageID

        viewModel.dismissStatusMessage(id: staleMessageID)
        XCTAssertEqual(
            viewModel.statusMessage,
            "Failed to save invoice: Store unavailable."
        )

        viewModel.dismissStatusMessage(id: latestMessageID)
        XCTAssertNil(viewModel.statusMessage)
    }

    @MainActor
    func testTemplateSaveFailureDiscardsOnlySuppressedNonErrorFeedback() {
        XCTAssertTrue(
            InvoiceEditorStatusBanner.shouldDiscardSuppressedMessage(
                "Applied Modern template.",
                whenTemplateSaveFailed: true
            )
        )
        XCTAssertFalse(
            InvoiceEditorStatusBanner.shouldDiscardSuppressedMessage(
                "Failed to create invoice: Store unavailable.",
                whenTemplateSaveFailed: true
            )
        )
        XCTAssertFalse(
            InvoiceEditorStatusBanner.shouldDiscardSuppressedMessage(
                "Applied Modern template.",
                whenTemplateSaveFailed: false
            )
        )
    }

    func testInvoiceEnvelopePreservesSemanticFieldsWithPartiallyMalformedTemplate() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let invoice = Core.Invoice(invoiceNumber: "INV-LEGACY")
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

        XCTAssertEqual(envelope.title, "Legacy Invoice")
        XCTAssertFalse(envelope.billParticipantDirectly)
        XCTAssertEqual(envelope.discountAmount, 0)
        XCTAssertEqual(envelope.template.accentTheme, .navy)
        XCTAssertEqual(envelope.template.headerStyle, .default)
    }

    func testLegacyInvoiceEnvelopeMissingTemplateIgnoresCurrentTemplatePreferences() throws {
        let preferences = UserDefaults.standard
        let originalData = preferences.data(forKey: InvoiceTemplatePreferenceStore.preferenceKey)
        defer {
            if let originalData {
                preferences.set(originalData, forKey: InvoiceTemplatePreferenceStore.preferenceKey)
            } else {
                preferences.removeObject(forKey: InvoiceTemplatePreferenceStore.preferenceKey)
            }
        }

        var currentTemplate = InvoiceTemplateConfiguration.default
        currentTemplate.accentTheme = .forest
        currentTemplate.headerStyle = .compact
        XCTAssertTrue(InvoiceTemplatePreferenceStore.save(currentTemplate, to: preferences))

        let invoice = Core.Invoice(invoiceNumber: "INV-LEGACY-NO-TEMPLATE")
        invoice.invoiceEditorStateData = Data(
            #"""
            {
              "title": "Legacy Stable Invoice",
              "billParticipantDirectly": false
            }
            """#.utf8
        )

        let envelope = InvoiceDocumentConfigurationEnvelope.decode(from: invoice)

        XCTAssertEqual(envelope.title, "Legacy Stable Invoice")
        XCTAssertFalse(envelope.billParticipantDirectly)
        XCTAssertEqual(envelope.template, .default)
    }

    func testMockPreviewUsesDeterministicContentAndRequestedTemplate() {
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .forest

        let snapshot = InvoiceTemplateMockData.snapshot(template: configuration)

        XCTAssertEqual(snapshot.id, UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        XCTAssertEqual(snapshot.invoiceNumber, "INV-DEMO-001")
        XCTAssertEqual(snapshot.clientName, "Alex Morgan")
        XCTAssertEqual(snapshot.currencyCode, "AUD")
        XCTAssertEqual(snapshot.lineItems.count, 3)
        XCTAssertEqual(snapshot.templateConfiguration, configuration)
    }

    @MainActor
    func testMockBootstrapAppliesCompleteTemplateDefaultsAtomically() {
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

        XCTAssertEqual(viewModel.paperSize, .legal)
        XCTAssertEqual(viewModel.pageOrientation, .landscape)
        XCTAssertEqual(viewModel.templateConfiguration, configuration)
        XCTAssertFalse(viewModel.hasUnsavedChanges)
    }

    @MainActor
    func testMockBootstrapDoesNotTouchPersistedInvoices() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        _ = try await actor.createInvoice()
        let viewModel = InvoiceEditorViewModel()

        viewModel.bootstrapMock(template: .default)
        let persistedCount = try await actor.invoiceCount()

        XCTAssertEqual(viewModel.currentInvoice?.invoiceNumber, "INV-DEMO-001")
        XCTAssertEqual(persistedCount, 1)
    }

    @MainActor
    func testResetTemplateRestoresPageSetupAndFormattingDefaults() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: InvoiceTemplatePreset.modern.configuration)
        viewModel.paperSize = .legal
        viewModel.pageOrientation = .landscape

        XCTAssertFalse(viewModel.isUsingDefaultTemplate)

        viewModel.resetTemplateToDefaults()

        XCTAssertEqual(viewModel.paperSize, .default)
        XCTAssertEqual(viewModel.pageOrientation, .portrait)
        XCTAssertEqual(viewModel.templateConfiguration, .default)
        XCTAssertTrue(viewModel.isUsingDefaultTemplate)
    }

    func testDeleteConfirmationWarnsWhenDraftWillBeDiscarded() {
        XCTAssertEqual(
            InvoiceEditorDeleteCopy.message(
                invoiceNumber: "INV-1042",
                discardsUnsavedChanges: true
            ),
            "This permanently deletes INV-1042 and all of its line items. Unsaved changes to this invoice will also be discarded."
        )
        XCTAssertEqual(
            InvoiceEditorDeleteCopy.message(
                invoiceNumber: "   ",
                discardsUnsavedChanges: false
            ),
            "This permanently deletes the selected invoice and all of its line items."
        )
    }

    @MainActor
    func testCustomPageAndMarginOverridesCanReturnToSelectedPresets() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)
        viewModel.paperSize = .legal
        viewModel.marginPreset = .wide
        viewModel.customPageWidthPoints = 700
        viewModel.customPageHeightPoints = 1_000
        viewModel.customMarginPoints = 72

        XCTAssertTrue(viewModel.hasCustomPageSize)
        XCTAssertTrue(viewModel.hasCustomMargin)

        viewModel.useSelectedPaperSize()
        viewModel.useSelectedMarginPreset()

        XCTAssertFalse(viewModel.hasCustomPageSize)
        XCTAssertFalse(viewModel.hasCustomMargin)
        XCTAssertEqual(viewModel.pageSizePoints, PaperSize.legal.sizePoints(for: .portrait))
        XCTAssertEqual(viewModel.effectiveMarginPoints, InvoiceMarginPreset.wide.marginPoints)
    }

    @MainActor
    func testDirectTemplateNumericEditsClampToSafeControlRanges() throws {
        let viewModel = InvoiceEditorViewModel()
        viewModel.bootstrapMock(template: .default)

        viewModel.updateCustomTypographyScale(100)
        viewModel.updateCustomSpacingScale(-20)
        viewModel.updateCustomBorderWidth(.infinity)

        XCTAssertEqual(
            viewModel.customTypographyScale,
            InvoiceTemplateLayoutLimits.typographyScaleRange.upperBound
        )
        XCTAssertEqual(
            viewModel.customSpacingScale,
            InvoiceTemplateLayoutLimits.spacingScaleRange.lowerBound
        )
        XCTAssertNil(viewModel.customBorderWidth)
    }

    func testNewInvoiceReceivesSavedTemplateDefaults() async throws {
        let preferences = UserDefaults.standard
        let original = preferences.data(forKey: InvoiceTemplatePreferenceStore.preferenceKey)
        defer {
            if let original {
                preferences.set(original, forKey: InvoiceTemplatePreferenceStore.preferenceKey)
            } else {
                preferences.removeObject(forKey: InvoiceTemplatePreferenceStore.preferenceKey)
            }
        }
        var configuration = InvoiceTemplateConfiguration.default
        configuration.accentTheme = .navy
        configuration.headerStyle = .compact
        InvoiceTemplatePreferenceStore.save(
            InvoiceTemplateDefaults(
                paperSize: .legal,
                pageOrientation: .landscape,
                configuration: configuration
            ),
            to: preferences
        )

        let container = try ModelContainerFactory.makeInMemoryContainer()
        let actor = InvoiceModelActor(modelContainer: container)
        let id = try await InvoiceEditorStore.createInvoice(in: container)
        let fetchedSnapshot = try await actor.fetchInvoice(id: id)
        let snapshot = try XCTUnwrap(fetchedSnapshot)

        XCTAssertEqual(snapshot.templateConfiguration, configuration)
        XCTAssertEqual(snapshot.paperSize, .legal)
        XCTAssertEqual(snapshot.pageOrientation, .landscape)
    }
}
