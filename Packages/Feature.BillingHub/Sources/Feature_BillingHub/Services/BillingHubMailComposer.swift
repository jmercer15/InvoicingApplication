import AppKit
import InvoiceTableLayoutEditor

/// Outcome of an `NSSharingService` compose-email hand-off.
enum BillingHubMailOutcome: Equatable {
    case completed
    case cancelled
    case failed(String)
}

/// Owns one Mail compose hand-off (and its temporary PDF, if any) so the sheet outlives the
/// presenting SwiftUI panel until the share genuinely completes, is cancelled, or fails.
/// Callers keep a strong reference (e.g. on the view model) for the lifetime of the send.
@MainActor
final class BillingHubMailComposer: NSObject, NSSharingServiceDelegate {
    private let service: NSSharingService
    private var temporaryPDF: InvoiceTemporaryPDF?
    private var completion: ((BillingHubMailOutcome) -> Void)?
    private var hasFinished = false

    init(
        service: NSSharingService,
        temporaryPDF: InvoiceTemporaryPDF?,
        completion: @escaping (BillingHubMailOutcome) -> Void
    ) {
        self.service = service
        self.temporaryPDF = temporaryPDF
        self.completion = completion
        super.init()
        service.delegate = self
    }

    deinit {
        temporaryPDF?.discard()
    }

    func perform(with items: [Any]) {
        service.perform(withItems: items)
    }

    func cancel() {
        finish(with: .cancelled)
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        finish(with: .completed)
    }

    func sharingService(
        _ sharingService: NSSharingService,
        didFailToShareItems items: [Any],
        error: Error
    ) {
        let cocoaError = error as NSError
        if cocoaError.domain == NSCocoaErrorDomain, cocoaError.code == NSUserCancelledError {
            finish(with: .cancelled)
        } else {
            finish(with: .failed("Email could not be shared. \(error.localizedDescription)"))
        }
    }

    private func finish(with outcome: BillingHubMailOutcome) {
        guard !hasFinished else { return }
        hasFinished = true
        service.delegate = nil
        temporaryPDF?.discard()
        temporaryPDF = nil
        let completion = completion
        self.completion = nil
        completion?(outcome)
    }
}

@MainActor
final class BillingHubMailShareSession {
    weak var composer: BillingHubMailComposer?

    func cancel() {
        composer?.cancel()
    }
}

enum BillingHubEmailRecipients {
    /// Splits a free-form "To" field on commas/semicolons/newlines into individual addresses.
    static func parse(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Lightweight client-side validation. Mail remains source of truth for delivery, but obvious
    /// malformed addresses should be explained before users leave Billing Hub.
    static func invalidAddresses(in raw: String) -> [String] {
        parse(raw).filter { !isPlausibleEmailAddress($0) }
    }

    static func validSingleAddress(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let addresses = parse(raw)
        guard addresses.count == 1, invalidAddresses(in: raw).isEmpty else { return nil }
        return addresses[0]
    }

    static func unique(_ addresses: [String]) -> [String] {
        var seen = Set<String>()
        return addresses.filter { address in
            seen.insert(address.lowercased()).inserted
        }
    }

    static func validationMessage(
        for raw: String,
        fieldName: String,
        required: Bool
    ) -> String? {
        let addresses = parse(raw)
        if addresses.isEmpty {
            let recipientName = fieldName == "To" ? "recipient" : fieldName.lowercased()
            return required ? "Enter at least one \(recipientName) email address." : nil
        }

        let invalid = addresses.filter { !isPlausibleEmailAddress($0) }
        guard !invalid.isEmpty else { return nil }
        if invalid.count == 1 {
            return "\(fieldName) contains an invalid email address: \(invalid[0])"
        }
        return "\(fieldName) contains \(invalid.count) invalid email addresses."
    }

    private static func isPlausibleEmailAddress(_ address: String) -> Bool {
        guard !address.contains(where: \.isWhitespace),
              !address.hasPrefix("."),
              !address.hasSuffix("."),
              !address.contains("..") else {
            return false
        }

        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return false }

        let domain = String(parts[1])
        guard domain.contains("."),
              !domain.hasPrefix("."),
              !domain.hasSuffix("."),
              !domain.contains("..") else {
            return false
        }

        return domain.split(separator: ".").allSatisfy { label in
            !label.isEmpty && !label.hasPrefix("-") && !label.hasSuffix("-")
        }
    }
}
