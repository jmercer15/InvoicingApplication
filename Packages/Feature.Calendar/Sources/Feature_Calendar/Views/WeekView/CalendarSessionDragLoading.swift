import Foundation

@MainActor
enum CalendarSessionDragLoading {
    static func loadPayload(
        from provider: NSItemProvider,
        interactionHandler: CalendarInteractionHandler
    ) {
        _ = provider.loadTransferable(type: SessionDragPayload.self) { result in
            Task { @MainActor in
                guard case .success(let payload) = result else { return }
                interactionHandler.startDragging(
                    sessionID: payload.sessionID,
                    duration: payload.duration,
                    originalInstanceDate: payload.originalInstanceDate
                )
            }
        }
    }
}
