import Foundation
import SwiftUI
import SwiftData
import Core
import Data

extension NewSessionViewModel {

    // MARK: - Save Entry Points

    func handleSaveButtonTapped() {
        guard !isPerformingPersistence else { return }

        let normalizedSnapshot = normalizedFormSnapshotForPersistence(from: formModel)
        formModel = normalizedSnapshot

        let validationErrors = normalizedSnapshot.validateForm()
        if !validationErrors.isEmpty {
            self.persistenceError = validationErrors.map { $0.localizedDescription }.joined(separator: "\n")
            pendingSaveSnapshot = nil
            return
        } else {
            self.persistenceError = nil
        }

        let availableModes = availableSaveModes
        if availableModes.count > 1 {
            pendingSaveSnapshot = normalizedSnapshot
            presentSaveScopePicker()
        } else {
            executeSave(with: availableModes.first ?? .thisOnly, using: normalizedSnapshot)
        }
    }

    func executeSave(with span: RecurringEditMode, using providedSnapshot: SessionFormModel? = nil) {
        guard !isPerformingPersistence else { return }

        let formSnapshot = providedSnapshot
            ?? pendingSaveSnapshot
            ?? normalizedFormSnapshotForPersistence(from: formModel)
        formModel = formSnapshot

        let validationErrors = formSnapshot.validateForm()
        if !validationErrors.isEmpty {
            persistenceError = validationErrors.map { $0.localizedDescription }.joined(separator: "\n")
            pendingSaveSnapshot = nil
            showingEditModeDialog = false
            return
        }

        isSaving = true
        persistenceError = nil
        showingEditModeDialog = false
        pendingSaveSnapshot = nil
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            await persistFormSnapshot(formSnapshot, with: span)
        }
    }

    func persistFormSnapshot(_ formSnapshot: SessionFormModel, with span: RecurringEditMode) async {
        defer {
            isSaving = false
            saveTask = nil
        }

        if isEditing, let session = sessionToEdit {
            let instanceDate   = session.recurrenceRuleData != nil ? originalInstanceDate : nil
            let effectiveSpan  = normalizedEditMode(span, session: session, instanceDate: instanceDate)
            let modelToSave    = adjustedFormModelForSave(formSnapshot, span: effectiveSpan, session: session)
            do {
                let savedSession = try await sessionModificationService.modifySession(
                    session,
                    with: modelToSave,
                    mode: effectiveSpan,
                    originalInstanceDate: instanceDate
                )
                try await persistSupportLogIfNeeded(for: savedSession, using: modelToSave)
                notifySuccessfulSave(using: effectiveSpan)
            } catch is CancellationError {
                return
            } catch {
                self.persistenceError = userFacingErrorMessage(for: error)
            }
        } else {
            let effectiveSpan = normalizedCreateMode(span, formSnapshot: formSnapshot)
            let modelToSave   = adjustedCreateFormModelForSave(formSnapshot, span: effectiveSpan)
            do {
                let savedSession = try await sessionModificationService.createSession(from: modelToSave)
                try await persistSupportLogIfNeeded(for: savedSession, using: modelToSave)
                notifySuccessfulSave(using: effectiveSpan)
            } catch is CancellationError {
                return
            } catch {
                self.persistenceError = userFacingErrorMessage(for: error)
            }
        }
    }

    func notifySuccessfulSave(using span: RecurringEditMode) {
        onSave?(span)
        onSaveCompleted?()
    }

    // MARK: - Delete Entry Points

    func delete() {
        guard !isPerformingPersistence, sessionToEdit != nil else { return }
        let availableModes = availableDeleteModes
        if availableModes.count > 1 {
            presentDeleteScopePicker()
        } else {
            executeDelete(with: availableModes.first ?? .thisOnly)
        }
    }

    func executeDelete(with span: RecurringEditMode) {
        guard !isPerformingPersistence, let sessionSnapshot = sessionToEdit else { return }
        showingRecurringDeleteOptions = false
        persistenceError = nil
        pendingSaveSnapshot = nil
        isDeleting = true
        let instanceDateSnapshot = sessionSnapshot.recurrenceRuleData != nil ? originalInstanceDate : nil
        deleteTask?.cancel()
        deleteTask = Task { @MainActor in
            await persistDeleteSession(sessionSnapshot, span: span, instanceDate: instanceDateSnapshot)
        }
    }

    func persistDeleteSession(_ sessionToDelete: Session, span: RecurringEditMode, instanceDate: Date?) async {
        defer {
            isDeleting = false
            deleteTask = nil
        }
        do {
            let effectiveSpan = normalizedDeleteMode(span, session: sessionToDelete, instanceDate: instanceDate)
            try await sessionModificationService.deleteSession(
                sessionToDelete,
                mode: effectiveSpan,
                originalInstanceDate: instanceDate
            )
            onDelete?(effectiveSpan)
            onSaveCompleted?()
        } catch is CancellationError {
            return
        } catch {
            self.persistenceError = userFacingErrorMessage(for: error)
        }
    }

    // MARK: - Form Model Normalisation & Adjustment

    func normalizedFormSnapshotForPersistence(from model: SessionFormModel) -> SessionFormModel {
        var normalized = model

        if normalized.selectedClientID == nil, let selectedClient {
            normalized.selectedClientID = selectedClient.id
        }
        if normalized.selectedClientServiceID == nil, let selectedClientService {
            normalized.selectedClientServiceID = selectedClientService.id
        }
        if let selectedServiceID = normalized.selectedClientServiceID,
           let resolvedService = resolveClientService(for: selectedServiceID) {
            if normalized.selectedClientID == nil || normalized.selectedClientID != resolvedService.clientId {
                normalized.selectedClientID = resolvedService.clientId
            }
        }

        if normalized.supportLogDraft.isEnabled {
            if normalized.supportLogDraft.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalized.supportLogDraft.location = normalized.location
            }
            if normalized.supportLogDraft.serviceDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalized.supportLogDraft.serviceDescription = normalized.title
            }
            if normalized.supportLogDraft.deliveredFrom > normalized.supportLogDraft.deliveredTo {
                normalized.supportLogDraft.deliveredTo = normalized.supportLogDraft.deliveredFrom.addingTimeInterval(3600)
            }
        }

        return normalized
    }

    func adjustedFormModelForSave(_ model: SessionFormModel, span: RecurringEditMode, session: Session?) -> SessionFormModel {
        guard span == .all,
              let session,
              session.recurrenceRuleData != nil,
              let masterStart = session.startTime,
              let clickedStart = originalInstanceDate else { return model }

        let calendar = Calendar.current
        guard !calendar.isDate(masterStart, inSameDayAs: clickedStart),
              calendar.isDate(model.startTime, inSameDayAs: clickedStart) else { return model }

        var adjusted = model
        let duration = max(0, model.endTime.timeIntervalSince(model.startTime))
        let adjustedStart: Date
        if model.isAllDay {
            adjustedStart = calendar.startOfDay(for: masterStart)
        } else {
            adjustedStart = dateByCombining(dayFrom: masterStart, timeFrom: model.startTime, calendar: calendar)
        }
        adjusted.startTime = adjustedStart
        adjusted.endTime   = adjustedStart.addingTimeInterval(duration)
        return adjusted
    }

    func adjustedCreateFormModelForSave(_ model: SessionFormModel, span: RecurringEditMode) -> SessionFormModel {
        guard span == .thisOnly else { return model }
        var adjusted = model
        adjusted.recurrenceFrequency = .none
        return adjusted
    }

    // MARK: - Scope Normalisation

    func normalizedEditMode(_ requested: RecurringEditMode, session: Session, instanceDate: Date?) -> RecurringEditMode {
        guard session.recurrenceRuleData != nil else { return .thisOnly }
        guard instanceDate != nil else { return .all }
        return requested
    }

    func normalizedDeleteMode(_ requested: RecurringEditMode, session: Session, instanceDate: Date?) -> RecurringEditMode {
        guard session.recurrenceRuleData != nil else { return .thisOnly }
        guard instanceDate != nil else { return .all }
        return requested
    }

    func normalizedCreateMode(_ requested: RecurringEditMode, formSnapshot: SessionFormModel) -> RecurringEditMode {
        guard formSnapshot.sourceEventIdentifier != nil, formSnapshot.hasRecurrence else { return .thisOnly }
        if requested == .thisAndFuture { return .all }
        return requested
    }

    // MARK: - Support Log Persistence

    func persistSupportLogIfNeeded(for session: Session, using model: SessionFormModel) async throws {
        guard model.supportLogDraft.isEnabled else { return }
        let draft    = model.supportLogDraft
        let existing = session.supportLogs?.first
        let quantityHours = max(draft.deliveredTo.timeIntervalSince(draft.deliveredFrom), 0) / 3600.0

        let log = existing ?? SupportLog(id: UUID())
        log.participantName        = draft.participantName
        log.participantNdisNumber  = draft.participantNdisNumber
        log.supportItemNumber      = draft.supportItemNumber
        log.serviceDescription     = draft.serviceDescription
        log.location               = draft.location
        log.deliveredFrom          = draft.deliveredFrom
        log.deliveredTo            = draft.deliveredTo
        log.quantityHours          = quantityHours > 0 ? quantityHours : 1.0
        log.deliveredBy            = draft.deliveredBy
        log.attestedBy             = draft.attestedBy
        log.attestedAt             = draft.attestedAt
        log.signatureMethod        = draft.signatureMethod
        log.signedBy               = draft.signedBy
        log.signedAt               = draft.signedAt
        log.cancellationReasonCode = draft.cancellationReasonCode
        log.notes                  = draft.notes
        log.client                 = session.client
        log.session                = session

        if existing == nil { modelContext.insert(log) }
        try modelContext.save()
    }

    // MARK: - Helpers

    func dateByCombining(dayFrom date: Date, timeFrom timeSource: Date, calendar: Calendar) -> Date {
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: timeSource)
        var dayComponents  = calendar.dateComponents([.year, .month, .day], from: date)
        dayComponents.hour       = timeComponents.hour
        dayComponents.minute     = timeComponents.minute
        dayComponents.second     = timeComponents.second
        dayComponents.nanosecond = timeComponents.nanosecond
        return calendar.date(from: dayComponents) ?? date
    }

    func userFacingErrorMessage(for error: Error) -> String {
        if let persistenceError = error as? PersistenceError { return persistenceError.localizedDescription }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return description }
        return error.localizedDescription
    }

    func presentSaveScopePicker() {
        showingRecurringDeleteOptions = false
        showingEditModeDialog = true
    }

    func presentDeleteScopePicker() {
        showingEditModeDialog = false
        showingRecurringDeleteOptions = true
    }
}
