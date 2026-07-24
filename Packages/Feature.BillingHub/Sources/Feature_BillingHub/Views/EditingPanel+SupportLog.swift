import SwiftUI
import Core
import Data
import SharedUI

extension EditingPanel {
    
    @ViewBuilder
    internal var supportLogContent: some View {
        if case .session(let sessionData) = card {
            TextField(text: $supportLogDraft.participantName) { Text("Participant name") }
            TextField(text: $supportLogDraft.participantNdisNumber) { Text("Participant NDIS number") }
            TextField(text: $supportLogDraft.supportItemNumber) { Text("Support item number") }
            TextField(text: $supportLogDraft.serviceDescription) { Text("Service description") }
            TextField(text: $supportLogDraft.location) { Text("Location") }
            DatePicker("Delivered from", selection: $supportLogDraft.deliveredFrom, displayedComponents: [.date, .hourAndMinute])
            DatePicker("Delivered to", selection: $supportLogDraft.deliveredTo, displayedComponents: [.date, .hourAndMinute])
            TextField(text: $supportLogDraft.deliveredBy) { Text("Delivered by") }
            TextField(text: $supportLogDraft.attestedBy) { Text("Attested by") }
            DatePicker("Attested at", selection: $supportLogDraft.attestedAt, displayedComponents: [.date, .hourAndMinute])
            TextField("Signed by (optional)", text: Binding(
                get: { supportLogDraft.signedBy ?? "" },
                set: { supportLogDraft.signedBy = $0.isEmpty ? nil : $0 }
            ))
            Picker(
                "Signature Method",
                selection: Binding(
                    get: { supportLogDraft.signatureMethod ?? SignatureMethod.attestation.rawValue },
                    set: { supportLogDraft.signatureMethod = $0 }
                )
            ) {
                ForEach(SignatureMethod.allCases, id: \.rawValue) { method in
                    Text(method.rawValue.capitalized).tag(method.rawValue)
                }
            }
            TextField(text: Binding(
                get: { supportLogDraft.cancellationReasonCode ?? "" },
                set: { supportLogDraft.cancellationReasonCode = $0.isEmpty ? nil : $0 }
            )) { Text("Cancellation reason (optional)") }
            TextField(text: Binding(
                get: { supportLogDraft.notes ?? "" },
                set: { supportLogDraft.notes = $0.isEmpty ? nil : $0 }
            )) { Text("Notes (optional)") }

            if let supportLogError,
               !supportLogError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(supportLogError)
                    .font(.caption)
                    .foregroundStyle(ColorSystem.Status.error)
            }

            Button("Save Support Log") {
                Task {
                    await saveSupportLog(for: sessionData.sessionId)
                }
            }
        }
    }

    internal func saveSupportLog(for sessionId: UUID) async {
        do {
            _ = try await viewModel.upsertSupportLog(sessionId: sessionId, draft: supportLogDraft)
            supportLogError = nil
        } catch {
            supportLogError = error.localizedDescription
        }
    }

    internal func supportLogDraft(from log: SupportLog) -> SupportLogDraft {
        SupportLogDraft(
            participantName: log.participantName,
            participantNdisNumber: log.participantNdisNumber,
            supportItemNumber: log.supportItemNumber,
            serviceDescription: log.serviceDescription,
            location: log.location,
            deliveredFrom: log.deliveredFrom,
            deliveredTo: log.deliveredTo,
            quantityHours: log.quantityHours,
            deliveredBy: log.deliveredBy,
            attestedBy: log.attestedBy,
            attestedAt: log.attestedAt,
            signatureMethod: log.signatureMethod,
            signedBy: log.signedBy,
            signedAt: log.signedAt,
            cancellationReasonCode: log.cancellationReasonCode,
            notes: log.notes
        )
    }
}
