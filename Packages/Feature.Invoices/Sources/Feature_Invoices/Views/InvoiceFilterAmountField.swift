import Foundation
import SwiftUI

enum InvoiceFilterAmountParseResult: Equatable {
    case empty
    case value(Double)
    case invalid
}

enum InvoiceFilterAmountInput {
    static func parse(
        _ text: String,
        locale: Locale = .current
    ) -> InvoiceFilterAmountParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let formatter = formatter(locale: locale)
        var value: AnyObject?
        var consumedRange = NSRange(location: 0, length: (trimmed as NSString).length)

        do {
            try formatter.getObjectValue(&value, for: trimmed, range: &consumedRange)
        } catch {
            return .invalid
        }

        guard consumedRange.location == 0,
              consumedRange.length == (trimmed as NSString).length,
              let number = value as? NSNumber,
              number.doubleValue.isFinite,
              number.doubleValue >= 0 else {
            return .invalid
        }
        return .value(number.doubleValue)
    }

    static func string(for value: Double?, locale: Locale = .current) -> String {
        guard let value else { return "" }
        return formatter(locale: locale).string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func formatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

struct InvoiceFilterAmountField: View {
    let title: String
    @Binding var value: Double?
    let resetRevision: Int

    @State private var text: String
    @State private var isInvalid = false
    @FocusState private var isFocused: Bool

    init(_ title: String, value: Binding<Double?>, resetRevision: Int) {
        self.title = title
        _value = value
        self.resetRevision = resetRevision
        _text = State(initialValue: InvoiceFilterAmountInput.string(for: value.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .overlay {
                    if isInvalid {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(.red, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("\(title) invoice amount")
                .accessibilityValue(isInvalid ? "Invalid amount" : text)
                .accessibilityHint(isInvalid ? "Enter zero or a positive amount" : "")

            if isInvalid {
                Text("Enter zero or greater.")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: text) { _, newText in
            switch InvoiceFilterAmountInput.parse(newText) {
            case .empty:
                isInvalid = false
                if value != nil { value = nil }
            case .value(let amount):
                isInvalid = false
                if value != amount { value = amount }
            case .invalid:
                isInvalid = true
            }
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            synchronizeText(with: newValue)
        }
        .onChange(of: resetRevision) { _, _ in
            synchronizeText(with: value)
        }
        .onChange(of: isFocused) { wasFocused, isFocused in
            guard wasFocused, !isFocused else { return }
            synchronizeText(with: value)
        }
    }

    private func synchronizeText(with value: Double?) {
        let updatedText = InvoiceFilterAmountInput.string(for: value)
        if text != updatedText {
            text = updatedText
        }
        isInvalid = false
    }
}
