import Accessibility
import Core
import Foundation
import Observation

extension InvoiceEditorViewModel {
  func loadClientOptions() async {
    guard !isLoadingClientOptions else { return }
    isLoadingClientOptions = true
    clientOptionsLoadError = nil
    defer { isLoadingClientOptions = false }
    do {
      clientOptions = try await persistenceActor().fetchClientOptions()
      hasLoadedClientOptions = true
    } catch {
      let message = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Client records could not be read. Try again."
      )
      clientOptionsLoadError = message
      statusMessage = "Failed to load clients: \(message)"
    }
  }

  /// Cold invoice workspaces may open before a list selection exists. Load picker data when
  /// first document later arrives, while avoiding a fetch on every within-workspace switch.
  func loadClientOptionsIfNeeded() async {
    guard !hasLoadedClientOptions else { return }
    await loadClientOptions()
  }

  func selectClient(id: UUID?) {
    selectedClientID = id
    guard let id,
      let option = clientOptions.first(where: { $0.id == id })
    else { return }

    clientName = option.name
    clientAddress = option.address
    clientEmail = option.email
    clientPhone = option.phone
    clientTaxID = option.taxID
    billParticipantDirectly = option.billsDirectly
    billingAuthority = option.billingAuthority
    billToName = option.billToName
    billToAddress = option.billToAddress
    billToEmail = option.billToEmail
    billToPhone = option.billToPhone
    statusMessage = "Loaded \(option.name) billing details."
  }

  func updateBillingAuthority(_ authority: Core.BillingAuthority?) {
    billingAuthority = authority?.rawValue ?? ""
    billParticipantDirectly = authority == .client
  }

  func bootstrap(preferredInvoiceID: UUID? = nil) async {
    guard !isLoading else { return }
    if let preferredInvoiceID, currentInvoice?.id == preferredInvoiceID {
      selectedInvoiceID = preferredInvoiceID
      return
    }
    let requestID = UUID()
    selectionRequestID = requestID
    loadingActivity.begin(requestID)
    defer { loadingActivity.finish(requestID) }
    guard let preferredInvoiceID else {
      selectedInvoiceID = nil
      currentInvoice = nil
      clearDraft()
      return
    }
    do {
      guard let snapshot = try await persistenceActor().fetchInvoice(id: preferredInvoiceID) else {
        throw InvoiceModelError.invoiceNotFound
      }
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = preferredInvoiceID
      acceptLoadedSnapshot(snapshot)
    } catch {
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = nil
      currentInvoice = nil
      clearDraft()
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be read. Try again."
      )
      statusMessage = "Failed to load invoice: \(detail)"
    }
  }

  /// Opens initial workspace state without bypassing normal draft transitions on re-entry.
  /// `InvoiceEditorSession` outlives feature views, so a later route must save or explicitly
  /// discard its existing draft instead of replacing it through bootstrap.
  func openForWorkspace(requestedInvoiceID: UUID?) async {
    if currentInvoice == nil {
      await bootstrap(preferredInvoiceID: requestedInvoiceID)
    } else {
      await selectInvoice(id: requestedInvoiceID)
    }
  }

  func loadInvoice(id: UUID) async throws {
    guard let snapshot = try await persistenceActor().fetchInvoice(id: id) else {
      if selectedInvoiceID == id {
        selectedInvoiceID = nil
      }
      currentInvoice = nil
      clearDraft()
      throw InvoiceModelError.invoiceNotFound
    }
    acceptLoadedSnapshot(snapshot)
  }

  func acceptLoadedSnapshot(_ snapshot: InvoiceSnapshot) {
    currentInvoice = snapshot
    applySnapshot(snapshot)
    hasAttemptedSave = false
    hasRevisionConflict = false
    revisionConflictCanReload = true
    pendingDiscardTransition = nil
    invalidNumericInputIDs.removeAll()
    savedDraft = draftPayload
    statusMessage = nil
  }

  func selectInvoice(id: UUID?) async {
    let requestID = UUID()
    selectionRequestID = requestID
    pendingDiscardTransition = nil

    guard let id else {
      guard await waitForActiveOperation() else { return }
      guard selectionRequestID == requestID else { return }
      if hasUnsavedChanges {
        await saveCurrentInvoice(successMessage: "Changes saved.")
        guard selectionRequestID == requestID else { return }
        guard !hasUnsavedChanges else {
          reportBlockedTransition(
            pending: .close,
            validationMessage:
              "Fix the errors in the Validation section before closing this invoice."
          )
          return
        }
      }
      selectedInvoiceID = nil
      currentInvoice = nil
      hasAttemptedSave = false
      statusMessage = nil
      return
    }

    guard id != currentInvoice?.id else {
      return
    }

    guard await waitForActiveOperation() else { return }
    guard selectionRequestID == requestID else { return }

    if hasUnsavedChanges {
      await saveCurrentInvoice(successMessage: "Changes saved.")
      guard selectionRequestID == requestID else { return }
      guard !hasUnsavedChanges else {
        reportBlockedTransition(
          pending: .select(id),
          validationMessage: "Fix the errors in the Validation section before switching invoices."
        )
        return
      }
    }

    loadingActivity.begin(requestID)
    defer { loadingActivity.finish(requestID) }
    do {
      guard let snapshot = try await persistenceActor().fetchInvoice(id: id) else {
        throw InvoiceModelError.invoiceNotFound
      }
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = id
      acceptLoadedSnapshot(snapshot)
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be read. Try again."
      )
      statusMessage = "Failed to load invoice: \(detail)"
    }
  }

  func waitForActiveOperation() async -> Bool {
    let deadline = ContinuousClock.now + .seconds(30)
    while isSaving || isGeneratingDocument || isPerformingLifecycleOperation {
      if ContinuousClock.now >= deadline {
        return false
      }
      do {
        try Task.checkCancellation()
        try await Task.sleep(for: .milliseconds(20))
      } catch {
        return false
      }
    }
    return !Task.isCancelled
  }

  func waitForActiveOperationBeforeWorkspaceExit() async {
    let deadline = ContinuousClock.now + .seconds(30)
    while isSaving || isGeneratingDocument || isPerformingLifecycleOperation {
      if ContinuousClock.now >= deadline { return }
      guard await Task.waitUnlessCancelled(for: .milliseconds(20)) else { return }
    }
  }

  func reportBlockedTransition(
    pending: InvoicePendingDiscardTransition? = nil,
    validationMessage: String
  ) {
    guard !hasRevisionConflict else { return }
    pendingDiscardTransition = pending
    statusMessage = validationMessage
  }

  func keepEditingAfterBlockedTransition() {
    pendingDiscardTransition = nil
  }

  /// Captures recovery destination before SwiftUI dismisses its confirmation dialog.
  /// Dialog dismissal writes `false` to presentation binding synchronously and may otherwise
  /// clear this payload before button's asynchronous continuation begins.
  func prepareToDiscardDraftAndContinueTransition() -> InvoicePendingDiscardTransition? {
    guard let transition = pendingDiscardTransition else { return nil }
    pendingDiscardTransition = nil
    discardCurrentDraftChanges()
    return transition
  }

  func continueDiscardedTransition(_ transition: InvoicePendingDiscardTransition) async {
    switch transition {
    case .close:
      await selectInvoice(id: nil)
      if selectedInvoiceID == nil {
        statusMessage = "Unsaved changes discarded."
      }
    case .select(let id):
      await selectInvoice(id: id)
      if selectedInvoiceID == id {
        statusMessage = "Unsaved changes discarded."
      }
    case .duplicate:
      await duplicateSelectedInvoice()
    }
  }

  func discardCurrentDraftChanges() {
    guard let currentInvoice else {
      clearDraft()
      return
    }
    applySnapshot(currentInvoice)
    hasAttemptedSave = false
    invalidNumericInputIDs.removeAll()
    savedDraft = draftPayload
  }

  func saveCurrentInvoice(
    successMessage: String = "Invoice saved.",
    allowsLifecycleOperation: Bool = false
  ) async {
    hasAttemptedSave = true
    guard !hasInvalidNumericInput else {
      statusMessage = "Enter valid numeric values before saving."
      requestValidationRecovery()
      return
    }
    guard let currentInvoice,
      !isSaving,
      allowsLifecycleOperation || !isPerformingLifecycleOperation
    else { return }
    let id = currentInvoice.id
    isSaving = true
    defer { isSaving = false }
    do {
      let result = try await persistenceActor().updateInvoice(
        id: id,
        expectedRevision: currentInvoice.revision,
        draft: draftPayload
      )
      if let savedSnapshot = result.savedSnapshot {
        acceptLoadedSnapshot(savedSnapshot)
        mutationHandler?(.updated(id))
        statusMessage = successMessage
      } else {
        statusMessage =
          result.errors == validationErrors
          ? "Review the Validation section and try again."
          : result.errors.joined(separator: " ")
        requestValidationRecovery()
      }
    } catch InvoiceModelError.revisionConflict {
      hasRevisionConflict = true
      revisionConflictCanReload = true
      statusMessage =
        "Failed to save invoice: \(InvoiceModelError.revisionConflict.localizedDescription)"
    } catch InvoiceModelError.invoiceNotFound {
      hasRevisionConflict = true
      revisionConflictCanReload = false
      statusMessage = "Failed to save invoice: This invoice was deleted in another window."
    } catch {
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be saved. Try again."
      )
      statusMessage = "Failed to save invoice: \(detail)"
    }
  }

  /// Commits current draft before Feature.Invoices creates another record. Creation remains
  /// feature-owned; false prevents orphan rows when validation, persistence, or revision fails.
  func prepareForFeatureOwnedInvoiceCreation() async -> Bool {
    guard !isBusy, !hasRevisionConflict else { return false }
    guard hasUnsavedChanges else { return true }
    await saveCurrentInvoice(successMessage: "Changes saved before creating invoice.")
    return !hasUnsavedChanges && !hasRevisionConflict
  }

  /// Explicit cross-feature navigation waits for current document work, then commits a valid
  /// draft before AppShell changes tabs. Failed validation or revision ownership keeps user in
  /// Invoices with existing recovery UI visible.
  func prepareForWorkspaceHandoff() async -> Bool {
    guard !hasRevisionConflict else { return false }
    await waitForActiveOperationBeforeWorkspaceExit()
    guard !hasRevisionConflict else { return false }
    guard hasUnsavedChanges else { return true }
    await saveCurrentInvoice(successMessage: "Changes saved.")
    return !hasUnsavedChanges && !hasRevisionConflict
  }

  /// Persists a valid draft when its workspace leaves the hierarchy. Invalid drafts remain in
  /// the owning ``InvoiceEditorSession`` and reappear when the user returns to Invoices.
  func saveBeforeLeavingWorkspace() async {
    guard hasUnsavedChanges, !hasRevisionConflict else { return }
    await waitForActiveOperationBeforeWorkspaceExit()
    // Active work may have saved, replaced, or conflicted with this draft while we waited.
    guard hasUnsavedChanges, !hasRevisionConflict else { return }
    await saveCurrentInvoice(successMessage: "Changes saved.")
  }

  func keepEditingAfterRevisionConflict() {
    guard !isResolvingRevisionConflict else { return }
    hasRevisionConflict = false
    revisionConflictCanReload = true
  }

  func beginRevisionConflictResolution(
    _ resolution: InvoiceRevisionConflictResolution
  ) -> InvoiceRevisionConflictResolution? {
    guard hasRevisionConflict, !isResolvingRevisionConflict else { return nil }
    switch resolution {
    case .saveDraftAsNew:
      guard hasUnsavedChanges else { return nil }
    case .reloadLatest:
      guard revisionConflictCanReload else { return nil }
    case .closeDeleted:
      guard !revisionConflictCanReload else { return nil }
    }
    isResolvingRevisionConflict = true
    return resolution
  }

  func continueRevisionConflictResolution(
    _ resolution: InvoiceRevisionConflictResolution
  ) async {
    defer { isResolvingRevisionConflict = false }
    switch resolution {
    case .saveDraftAsNew:
      await saveRevisionConflictAsNewInvoice()
    case .reloadLatest:
      await reloadAfterRevisionConflict()
    case .closeDeleted:
      await closeDeletedInvoiceAfterRevisionConflict()
    }
  }

  func reloadAfterRevisionConflict() async {
    guard revisionConflictCanReload, !isBusy else { return }
    guard let id = currentInvoice?.id else {
      hasRevisionConflict = false
      return
    }
    let requestID = UUID()
    selectionRequestID = requestID
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }
    do {
      // Do not use `loadInvoice` here: its normal selection behavior clears
      // the draft when a record is missing. A second window can delete this
      // invoice after the conflict is detected but before this reload runs;
      // the user's unsaved draft must remain available in that case.
      guard let snapshot = try await persistenceActor().fetchInvoice(id: id) else {
        guard selectionRequestID == requestID else { return }
        hasRevisionConflict = true
        revisionConflictCanReload = false
        statusMessage =
          "This invoice was deleted in another window. Your local draft is still available."
        return
      }
      guard selectionRequestID == requestID else { return }
      acceptLoadedSnapshot(snapshot)
      statusMessage = "Reloaded the latest saved invoice."
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Latest invoice data could not be read. Try again."
      )
      statusMessage = "Failed to reload invoice: \(detail)"
    }
  }

  func closeDeletedInvoiceAfterRevisionConflict() async {
    guard let id = currentInvoice?.id else { return }
    await closeInvoiceDeletedExternally(id: id)
  }

  func prepareForOwningDeletion(
    invoiceIDs: Set<UUID>
  ) async -> InvoiceEditorDeletionLease? {
    guard let activeID = currentInvoice?.id ?? selectedInvoiceID,
      invoiceIDs.contains(activeID)
    else { return nil }

    let requestID = UUID()
    selectionRequestID = requestID
    guard await waitForActiveOperation() else { return nil }
    guard selectionRequestID == requestID,
      !isPerformingLifecycleOperation,
      let currentActiveID = currentInvoice?.id ?? selectedInvoiceID,
      invoiceIDs.contains(currentActiveID)
    else { return nil }

    isPerformingLifecycleOperation = true
    owningDeletionLeaseToken = requestID
    return InvoiceEditorDeletionLease(token: requestID, invoiceID: currentActiveID)
  }

  func completeOwningDeletion(
    lease: InvoiceEditorDeletionLease,
    deletedInvoiceIDs: Set<UUID>
  ) {
    guard owningDeletionLeaseToken == lease.token else { return }
    defer { releaseOwningDeletionLease() }
    guard deletedInvoiceIDs.contains(lease.invoiceID),
      currentInvoice?.id == lease.invoiceID || selectedInvoiceID == lease.invoiceID
    else { return }

    selectedInvoiceID = nil
    currentInvoice = nil
    clearDraft()
    statusMessage = "Closed the deleted invoice."
  }

  func cancelOwningDeletion(lease: InvoiceEditorDeletionLease) {
    guard owningDeletionLeaseToken == lease.token else { return }
    releaseOwningDeletionLease()
  }

  func releaseOwningDeletionLease() {
    owningDeletionLeaseToken = nil
    isPerformingLifecycleOperation = false
  }

  func closeInvoiceDeletedExternally(id: UUID) async {
    // Owning-feature deletion is authoritative. Supersede any in-flight lifecycle request and
    // wait for it to release mutation ownership; returning early would leave a deleted invoice
    // open in the editor with a stale draft.
    let requestID = UUID()
    selectionRequestID = requestID
    guard await waitForActiveOperation() else { return }
    guard selectionRequestID == requestID, !isPerformingLifecycleOperation else { return }
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }
    guard currentInvoice?.id == id || selectedInvoiceID == id else { return }
    selectedInvoiceID = nil
    currentInvoice = nil
    clearDraft()
    statusMessage = "Closed the deleted invoice."
  }

  func saveRevisionConflictAsNewInvoice() async {
    guard !isBusy else { return }
    hasAttemptedSave = true
    guard validationErrors.isEmpty else {
      hasRevisionConflict = false
      statusMessage = "Review the Validation section before saving as a new invoice."
      requestValidationRecovery()
      return
    }

    let requestID = UUID()
    selectionRequestID = requestID
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }
    do {
      let newID = try await persistenceActor().createInvoice(from: draftPayload)
      mutationHandler?(.inserted(newID))
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = newID
      try await loadInvoice(id: newID)
      guard selectionRequestID == requestID else { return }
      statusMessage = "Saved your draft as a new invoice."
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be created. Try again."
      )
      statusMessage = "Failed to save draft as a new invoice: \(detail)"
    }
  }

  func deleteSelectedInvoice() async {
    guard !isPerformingLifecycleOperation else { return }
    let requestID = UUID()
    selectionRequestID = requestID
    guard await waitForActiveOperation() else { return }
    guard selectionRequestID == requestID, !isPerformingLifecycleOperation else { return }
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }
    guard let invoice = currentInvoice else { return }
    do {
      try await persistenceActor().deleteInvoice(
        id: invoice.id,
        expectedRevision: invoice.revision
      )
      currentInvoice = nil
      clearDraft()
      mutationHandler?(.deleted(invoice.id))
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = nil
      statusMessage = "Invoice deleted."
    } catch InvoiceModelError.revisionConflict {
      guard selectionRequestID == requestID else { return }
      hasRevisionConflict = true
      revisionConflictCanReload = true
      statusMessage =
        "Failed to delete invoice: \(InvoiceModelError.revisionConflict.localizedDescription)"
    } catch InvoiceModelError.invoiceNotFound {
      guard selectionRequestID == requestID else { return }
      hasRevisionConflict = true
      revisionConflictCanReload = false
      statusMessage = "Failed to delete invoice: This invoice was deleted in another window."
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be deleted. Try again."
      )
      statusMessage = "Failed to delete invoice: \(detail)"
    }
  }

  func duplicateSelectedInvoice() async {
    guard !isPerformingLifecycleOperation else { return }
    let requestID = UUID()
    selectionRequestID = requestID
    guard await waitForActiveOperation() else { return }
    guard selectionRequestID == requestID, !isPerformingLifecycleOperation else { return }
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }

    if hasUnsavedChanges {
      await saveCurrentInvoice(
        successMessage: "Changes saved.",
        allowsLifecycleOperation: true
      )
      guard selectionRequestID == requestID else { return }
      guard !hasUnsavedChanges else {
        reportBlockedTransition(
          pending: .duplicate,
          validationMessage:
            "Fix the errors in the Validation section before duplicating this invoice."
        )
        return
      }
    }

    guard let id = currentInvoice?.id else { return }
    do {
      let newID = try await persistenceActor().duplicateInvoice(id: id)
      mutationHandler?(.inserted(newID))
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = newID
      try await loadInvoice(id: newID)
      guard selectionRequestID == requestID else { return }
      statusMessage = "Invoice duplicated."
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be duplicated. Try again."
      )
      statusMessage = "Failed to duplicate invoice: \(detail)"
    }
  }
}
