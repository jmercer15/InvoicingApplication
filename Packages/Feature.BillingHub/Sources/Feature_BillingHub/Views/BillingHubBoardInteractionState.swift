import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum BillingHubBoardTransfer {
    static let acceptedTypeIdentifiers: [UTType] = [
        .billingHubSessionID,
        .billingHubInvoiceID,
        .billingHubGroupID,
    ]

    static func provider(for id: UUID, type: UTType) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { done in
            done(id.uuidString.data(using: .utf8), nil)
            return nil
        }
        return provider
    }

    static func loadDragKind(
        from providers: [NSItemProvider],
        handle: @MainActor @escaping (BillingHubBoardDragKind) -> Void
    ) -> Bool {
        guard providers.count == 1, let provider = providers.first else {
            return false
        }

        let typeID = provider.registeredContentTypes.first {
            acceptedTypeIdentifiers.contains($0)
        }

        guard let typeID else { return false }

        loadUUID(from: provider, type: typeID) { id in
            if typeID == .billingHubSessionID {
                handle(.session(id))
            } else if typeID == .billingHubInvoiceID {
                handle(.invoice(id))
            } else if typeID == .billingHubGroupID {
                handle(.group(id))
            }
        }
        return true
    }

    private static func loadUUID(
        from provider: NSItemProvider,
        type: UTType,
        handle: @MainActor @escaping (UUID) -> Void
    ) {
        _ = provider.loadDataRepresentation(for: type) { data, _ in
            guard
                let data,
                let value = String(data: data, encoding: .utf8),
                let id = UUID(uuidString: value)
            else { return }

            Task { @MainActor in
                handle(id)
            }
        }
    }
}

enum BillingHubBoardMotion {
    static let quick = Animation.snappy(duration: 0.16)
    static let smooth = Animation.easeOut(duration: 0.16)
}

@MainActor
@Observable
final class BillingHubBoardInteractionState {
    var activeDragKind: BillingHubBoardDragKind?
    var activeGroupHostID: UUID?
    var lastRejectedDropID: UUID?
    var isDragActive: Bool { activeDragKind != nil }

    func begin(_ kind: BillingHubBoardDragKind) {
        activeDragKind = kind
        activeGroupHostID = nil
    }

    func setActiveGroupHost(_ groupID: UUID?) {
        activeGroupHostID = activeDragKind == nil ? nil : groupID
    }

    func endDrag() {
        activeDragKind = nil
        activeGroupHostID = nil
        lastRejectedDropID = nil
    }
}
