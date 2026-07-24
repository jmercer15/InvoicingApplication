import Observation

@Observable
@MainActor
final class InvoiceDocumentActionCancellation {
    @ObservationIgnored
    private var cancellation: (() -> Void)?

    var isInstalled: Bool { cancellation != nil }

    func install(_ cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func clear() {
        cancellation = nil
    }

    func cancel() {
        let cancellation = cancellation
        self.cancellation = nil
        cancellation?()
    }
}
