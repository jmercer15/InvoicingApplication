import Accessibility
import Foundation
import SharedUI
import SwiftUI

enum InvoiceDecimalInput {
  static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
    ValidatedDecimalParser.parseDecimal(text, locale: locale)
  }

  static func string(for value: Decimal, locale: Locale = .current) -> String {
    ValidatedDecimalParser.string(for: value, locale: locale)
  }
}

struct InvoiceValidatedDecimalField: View {
  let title: String
  @Binding var value: Decimal
  let inputID: String
  let focusTarget: InvoiceInspectorFocusTarget
  let focus: FocusState<InvoiceInspectorFocusTarget?>.Binding
  let draftStore: InvoiceNumericInputDraftStore
  let resetRevision: Int
  let onValidityChange: (String, Bool) -> Void
  let showsValidationMessage: Bool
  let step: Decimal?
  let minimumValue: Decimal?
  let usesPlainTextFieldStyle: Bool

  @State private var text: String
  @State private var isInvalid = false

  init(
    _ title: String,
    value: Binding<Decimal>,
    inputID: String,
    focusTarget: InvoiceInspectorFocusTarget,
    focus: FocusState<InvoiceInspectorFocusTarget?>.Binding,
    draftStore: InvoiceNumericInputDraftStore,
    resetRevision: Int,
    showsValidationMessage: Bool = true,
    step: Decimal? = nil,
    minimumValue: Decimal? = nil,
    usesPlainTextFieldStyle: Bool = false,
    onValidityChange: @escaping (String, Bool) -> Void
  ) {
    self.title = title
    _value = value
    self.inputID = inputID
    self.focusTarget = focusTarget
    self.focus = focus
    self.draftStore = draftStore
    self.resetRevision = resetRevision
    self.showsValidationMessage = showsValidationMessage
    self.step = step
    self.minimumValue = minimumValue
    self.usesPlainTextFieldStyle = usesPlainTextFieldStyle
    self.onValidityChange = onValidityChange
    let baseline = InvoiceDecimalInput.string(for: value.wrappedValue)
    let restoredText = draftStore.restoredText(for: inputID, baseline: baseline)
    _text = State(initialValue: restoredText ?? baseline)
    _isInvalid = State(initialValue: restoredText != nil)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      inputControl

      if isInvalid, showsValidationMessage {
        Text("Enter a valid number.")
          .font(.caption)
          .foregroundStyle(.red)
          .accessibilityHidden(true)
      }
    }
    .onChange(of: text) { _, newText in
      updateValue(from: newText)
    }
    .onChange(of: value) { _, newValue in
      guard focus.wrappedValue != focusTarget else { return }
      synchronizeText(with: newValue)
    }
    .onChange(of: resetRevision) { _, _ in
      synchronizeText(with: value)
    }
    .onChange(of: focus.wrappedValue) { previousTarget, nextTarget in
      guard previousTarget == focusTarget, nextTarget != focusTarget else { return }
      guard !isInvalid else { return }
      synchronizeText(with: value)
    }
    .onAppear {
      onValidityChange(inputID, isInvalid)
      if isInvalid {
        AccessibilityNotification.Announcement("\(title): Invalid decimal value. Enter a valid number.").post()
      }
    }
  }

  @ViewBuilder
  private var inputControl: some View {
    if let step {
      Stepper(
        onIncrement: { adjustValue(by: step) },
        onDecrement: { adjustValue(by: -step) }
      ) {
        decimalTextField
      }
    } else {
      decimalTextField
    }
  }

  @ViewBuilder
  private var decimalTextField: some View {
    if usesPlainTextFieldStyle {
      configuredDecimalTextField
        .textFieldStyle(.plain)
    } else {
      configuredDecimalTextField
        .textFieldStyle(.roundedBorder)
    }
  }

  private var configuredDecimalTextField: some View {
    TextField(title, text: $text)
      .focused(focus, equals: focusTarget)
      .overlay {
        if isInvalid {
          RoundedRectangle(cornerRadius: 5)
            .stroke(.red, lineWidth: 1)
            .allowsHitTesting(false)
        }
      }
      .accessibilityValue(isInvalid ? "\(text), invalid decimal value" : text)
      .accessibilityHint(isInvalid ? "Enter a valid number" : "")
  }

  private func adjustValue(by step: Decimal) {
    let candidate = value + step
    let adjustedValue = minimumValue.map { max(candidate, $0) } ?? candidate
    if adjustedValue != value {
      value = adjustedValue
    }
    synchronizeText(with: adjustedValue)
  }

  private func updateValue(from text: String) {
    guard let parsedValue = InvoiceDecimalInput.parse(text) else {
      setInvalid(true)
      draftStore.preserve(
        text,
        for: inputID,
        baseline: InvoiceDecimalInput.string(for: value)
      )
      return
    }

    setInvalid(false)
    draftStore.clear(inputID)
    if parsedValue != value {
      value = parsedValue
    }
  }

  private func synchronizeText(with value: Decimal) {
    let updatedText = InvoiceDecimalInput.string(for: value)
    if text != updatedText {
      text = updatedText
    }
    setInvalid(false)
    draftStore.clear(inputID)
  }

  private func setInvalid(_ invalid: Bool) {
    guard isInvalid != invalid else { return }
    isInvalid = invalid
    onValidityChange(inputID, invalid)
    if invalid {
      AccessibilityNotification.Announcement("\(title): Invalid decimal value. Enter a valid number.").post()
    }
  }
}

enum InvoiceDoubleInput {
  static func parse(
    _ text: String,
    in range: ClosedRange<Double>,
    locale: Locale = .current
  ) -> Double? {
    ValidatedDecimalParser.parseDouble(text, in: range, locale: locale)
  }

  static func string(for value: Double, locale: Locale = .current) -> String {
    ValidatedDecimalParser.string(for: value, locale: locale)
  }
}

struct InvoiceValidatedDoubleField: View {
  let title: String
  @Binding var value: Double
  let inputID: String
  let validRange: ClosedRange<Double>
  let draftStore: InvoiceNumericInputDraftStore
  let resetRevision: Int
  let onValidityChange: (String, Bool) -> Void

  @State private var text: String
  @State private var isInvalid = false
  @FocusState private var isFocused: Bool

  init(
    _ title: String,
    value: Binding<Double>,
    inputID: String,
    validRange: ClosedRange<Double>,
    draftStore: InvoiceNumericInputDraftStore,
    resetRevision: Int,
    onValidityChange: @escaping (String, Bool) -> Void
  ) {
    self.title = title
    _value = value
    self.inputID = inputID
    self.validRange = validRange
    self.draftStore = draftStore
    self.resetRevision = resetRevision
    self.onValidityChange = onValidityChange
    let baseline = InvoiceDoubleInput.string(for: value.wrappedValue)
    let restoredText = draftStore.restoredText(for: inputID, baseline: baseline)
    _text = State(initialValue: restoredText ?? baseline)
    _isInvalid = State(initialValue: restoredText != nil)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      TextField(title, text: $text)
        .textFieldStyle(.roundedBorder)
        .font(.caption.monospacedDigit())
        .focused($isFocused)
        .overlay {
          if isInvalid {
            RoundedRectangle(cornerRadius: 5)
              .stroke(.red, lineWidth: 1)
              .allowsHitTesting(false)
          }
        }
        .accessibilityValue(isInvalid ? "\(text), invalid value" : text)
        .accessibilityHint(isInvalid ? rangeHint : "")

      if isInvalid {
        Text(rangeHint)
          .font(.caption2)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityHidden(true)
      }
    }
    .onChange(of: text) { _, newText in
      guard let parsedValue = InvoiceDoubleInput.parse(newText, in: validRange) else {
        setInvalid(true)
        draftStore.preserve(
          newText,
          for: inputID,
          baseline: InvoiceDoubleInput.string(for: value)
        )
        return
      }
      setInvalid(false)
      draftStore.clear(inputID)
      if value != parsedValue {
        value = parsedValue
      }
    }
    .onChange(of: value) { _, newValue in
      guard !isFocused else { return }
      synchronizeText(with: newValue)
    }
    .onChange(of: resetRevision) { _, _ in
      synchronizeText(with: value)
    }
    .onChange(of: validRange) { _, newRange in
      guard let parsedValue = InvoiceDoubleInput.parse(text, in: newRange) else {
        setInvalid(true)
        draftStore.preserve(
          text,
          for: inputID,
          baseline: InvoiceDoubleInput.string(for: value)
        )
        return
      }
      setInvalid(false)
      draftStore.clear(inputID)
      if value != parsedValue {
        value = parsedValue
      }
    }
    .onChange(of: isFocused) { wasFocused, isFocused in
      guard wasFocused, !isFocused else { return }
      guard !isInvalid else { return }
      synchronizeText(with: value)
    }
    .onAppear {
      onValidityChange(inputID, isInvalid)
      if isInvalid {
        AccessibilityNotification.Announcement("\(title): Invalid value. \(rangeHint)").post()
      }
    }
  }

  private var rangeHint: String {
    let lower = InvoiceDoubleInput.string(for: validRange.lowerBound)
    let upper = InvoiceDoubleInput.string(for: validRange.upperBound)
    return "Enter \(lower)–\(upper)."
  }

  private func synchronizeText(with value: Double) {
    let updatedText = InvoiceDoubleInput.string(for: value)
    if text != updatedText {
      text = updatedText
    }
    setInvalid(false)
    draftStore.clear(inputID)
  }

  private func setInvalid(_ invalid: Bool) {
    guard isInvalid != invalid else { return }
    isInvalid = invalid
    onValidityChange(inputID, invalid)
    if invalid {
      AccessibilityNotification.Announcement("\(title): Invalid value. \(rangeHint)").post()
    }
  }
}
