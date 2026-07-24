import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension View {
    func billingHubDragPointerStyle(isBeingDragged: Bool, interactionState: BillingHubBoardInteractionState) -> some View {
        billingHubPointerStyle(
            interactionState.isDragActive
                ? (isBeingDragged ? .closedHand : .openHand)
                : .openHand
        )
    }
}

enum BillingHubGroupDropPlacement {
    case index(Int)
    case end

    func resolvedIndex(for count: Int) -> Int {
        if case let .index(index) = self {
            return min(index, count)
        }
        return count
    }
}

struct BillingHubBoardCleanupModifier: ViewModifier {
    let interactionState: BillingHubBoardInteractionState
    @State private var monitors: [Any] = []

    func body(content: Content) -> some View {
        content
            .onAppear { updateMonitoring(interactionState.isDragActive) }
            .onChange(of: interactionState.isDragActive) { _, active in updateMonitoring(active) }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                if interactionState.isDragActive { interactionState.endDrag() }
            }
            .onDisappear {
                removeMonitoring()
                interactionState.endDrag()
            }
    }

    private func updateMonitoring(_ active: Bool) {
        active ? installMonitoring() : removeMonitoring()
    }

    private func installMonitoring() {
        guard monitors.isEmpty else { return }
        monitors = [
            NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { event in
                if interactionState.isDragActive { interactionState.endDrag() }
                return event
            },
            NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                if event.keyCode == 53, interactionState.isDragActive { interactionState.endDrag() }
                return event
            },
        ].compactMap { $0 }
    }

    private func removeMonitoring() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}

extension View {
    @ViewBuilder
    func billingHubBoardCleanup(interactionState: BillingHubBoardInteractionState) -> some View {
        if BillingHubPreviewRuntime.isCanvasPreview {
            self
        } else {
            modifier(BillingHubBoardCleanupModifier(interactionState: interactionState))
        }
    }

    func resetBillingHubTargetOnDragEnd(_ isDragActive: Bool, perform reset: @escaping () -> Void) -> some View {
        onChange(of: isDragActive) { _, active in
            if !active { reset() }
        }
    }

    @ViewBuilder
    func billingHubDropHandler(
        targeted: Binding<Bool>,
        interactionState: BillingHubBoardInteractionState? = nil,
        accepts: @escaping (BillingHubBoardDragKind) -> Bool = { _ in true },
        action: @MainActor @escaping (BillingHubBoardDragKind) -> Void
    ) -> some View {
        if BillingHubPreviewRuntime.isCanvasPreview {
            self
        } else {
            onDrop(of: BillingHubBoardTransfer.acceptedTypeIdentifiers, isTargeted: targeted) { providers in
                if let activeDragKind = interactionState?.activeDragKind {
                    guard accepts(activeDragKind) else { return false }
                    action(activeDragKind)
                    return true
                }

                return BillingHubBoardTransfer.loadDragKind(from: providers) { dragKind in
                    guard accepts(dragKind) else { return }
                    action(dragKind)
                }
            }
        }
    }

    @ViewBuilder
    func billingHubDragSource<Preview: View>(
        interactionState: BillingHubBoardInteractionState,
        dragKind: BillingHubBoardDragKind,
        provider: @escaping () -> NSItemProvider,
        @ViewBuilder preview: @escaping () -> Preview
    ) -> some View {
        if BillingHubPreviewRuntime.isCanvasPreview {
            self
        } else {
            onDrag {
                withAnimation(BillingHubBoardMotion.quick) {
                    interactionState.begin(dragKind)
                }
                return provider()
            } preview: {
                preview()
            }
        }
    }
}
