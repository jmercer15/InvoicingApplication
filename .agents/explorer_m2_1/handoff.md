# Handoff Report: Area 1 — Validated Decimal Input Deduplication

## 1. Observation

Direct code inspection of the target files revealed duplicate decimal and double input parsing implementations across `Feature.Invoices` and `Feature.InvoiceTemplateEditor`:

1. **`Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterAmountField.swift` (lines 10–53)**:
   - Defines `InvoiceFilterAmountInput` with `parse(_:locale:) -> InvoiceFilterAmountParseResult` and `string(for:locale:) -> String`.
   - Instantiates `NumberFormatter` with `.decimal` style, `isLenient = false`, `usesGroupingSeparator = true`, `minimumFractionDigits = 0`, `maximumFractionDigits = 2`.
   - Uses `formatter.getObjectValue(&value, for: trimmed, range: &consumedRange)` and checks `consumedRange.location == 0 && consumedRange.length == (trimmed as NSString).length`.
   - Checks `number.doubleValue.isFinite && number.doubleValue >= 0`.
   - **Deficiency**: Lacks keypad fallback for numeric keypads emitting `.` in non-US locales (e.g., German/French locales where decimal separator is `,`).

2. **`Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift`**:
   - **`InvoiceDecimalInput` (lines 5–58)**:
     - Parses `Decimal?` using `NumberFormatter` (`.decimal`, `generatesDecimalNumbers = true`, `isLenient = false`, `usesGroupingSeparator = true`).
     - Includes keypad fallback: if strict parsing fails, checks `locale.decimalSeparator != "."` and regex `^\d+\.\d+$`, falling back to `en_US_POSIX` parsing.
   - **`InvoiceDoubleInput` (lines 179–222)**:
     - Parses `Double?` bounded by `ClosedRange<Double>`.
     - Instantiates `NumberFormatter` (`.decimal`, `isLenient = false`, `usesGroupingSeparator = true`, `minimumFractionDigits = 0`, `maximumFractionDigits = 2`).
     - **Deficiency**: Lacks keypad fallback logic present in `InvoiceDecimalInput`.

3. **`Packages/SharedUI/Sources/SharedUI/Components/`**:
   - Currently lacks a centralized decimal parsing engine and input field component.

4. **Test Suite Coverage**:
   - `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/InvoicesListQueryTests.swift` (lines 116–131) tests `InvoiceFilterAmountInput`.
   - `Packages/Feature.InvoiceTemplateEditor/Tests/InvoiceTableLayoutEditorTests/InvoiceEditorAccessibilityAndNavigationTests.swift` (lines 134–162), `InvoiceEditorSeparationTests.swift` (lines 213–243, 1104–1105), and `RequirementR2StressTests.swift` (lines 140–179) test `InvoiceDecimalInput` and `InvoiceDoubleInput`.

---

## 2. Logic Chain

1. **Observation**: All three input helper types (`InvoiceFilterAmountInput`, `InvoiceDecimalInput`, `InvoiceDoubleInput`) construct identical `NumberFormatter` objects (`.decimal` style, `isLenient = false`, `usesGroupingSeparator = true`) and perform identical strict length validation on `getObjectValue(&value, for:text, range:&consumedRange)`.
2. **Inference**: The core parsing engine is identical across all three implementations. Duplicating `NumberFormatter` setup and consumed range boundary checks across two feature packages creates code duplication and maintainability debt.
3. **Observation**: `InvoiceDecimalInput` contains keypad dot fallback logic (`locale.decimalSeparator != "." && trimmed.range(of: #"^\d+\.\d+$"#) != nil` -> `en_US_POSIX`), whereas `InvoiceFilterAmountInput` and `InvoiceDoubleInput` omit this fallback.
4. **Inference**: Consolidating parsing into a single `ValidatedDecimalParser` in `SharedUI` will eliminate code duplication AND fix the keypad dot fallback bug in `InvoiceFilterAmountInput` and `InvoiceDoubleInput` across all locales.
5. **Observation**: `SharedUI` is a foundational UI library imported by both `Feature.Invoices` and `Feature.InvoiceTemplateEditor`.
6. **Conclusion**: Moving the parsing engine and validated field abstractions into `SharedUI` provides a clean, single source of truth without violating dependency constraints or introducing layer inversions.

---

## 3. Caveats

- **Feature View Wrappers**: `InvoiceValidatedDecimalField` and `InvoiceValidatedDoubleField` in `Feature.InvoiceTemplateEditor` rely on feature-specific state handlers (`InvoiceNumericInputDraftStore`, `InvoiceInspectorFocusTarget`). `SharedUI` must NOT import these feature types. Therefore, the feature-specific view structs will remain in `Feature.InvoiceTemplateEditor` as thin view wrappers that consume `SharedUI.ValidatedDecimalParser`.
- **Backward Compatibility**: Existing unit tests reference `InvoiceFilterAmountInput`, `InvoiceDecimalInput`, and `InvoiceDoubleInput`. Preserving these types as thin wrappers/adapters around `ValidatedDecimalParser` ensures 100% test compatibility.

---

## 4. Conclusion

Consolidate decimal input parsing into a new file:
`Packages/SharedUI/Sources/SharedUI/Components/ValidatedDecimalField.swift`

### Proposed Architecture & Code Implementation

#### Step 1: Create `SharedUI/Components/ValidatedDecimalField.swift`

```swift
import Foundation
import SwiftUI

public enum ValidatedDecimalParseResult<T: Equatable>: Equatable {
    case empty
    case value(T)
    case invalid
}

public struct ValidatedDecimalParser {
    public struct FormatOptions {
        public var minimumFractionDigits: Int?
        public var maximumFractionDigits: Int?
        public var generatesDecimalNumbers: Bool

        public init(
            minimumFractionDigits: Int? = nil,
            maximumFractionDigits: Int? = nil,
            generatesDecimalNumbers: Bool = false
        ) {
            self.minimumFractionDigits = minimumFractionDigits
            self.maximumFractionDigits = maximumFractionDigits
            self.generatesDecimalNumbers = generatesDecimalNumbers
        }

        public static let decimal = FormatOptions(generatesDecimalNumbers: true)
        public static let double = FormatOptions(minimumFractionDigits: 0, maximumFractionDigits: 2, generatesDecimalNumbers: false)
    }

    private static func parseStrict(
        _ text: String,
        locale: Locale,
        options: FormatOptions
    ) -> NSNumber? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        formatter.usesGroupingSeparator = true
        formatter.generatesDecimalNumbers = options.generatesDecimalNumbers
        if let min = options.minimumFractionDigits {
            formatter.minimumFractionDigits = min
        }
        if let max = options.maximumFractionDigits {
            formatter.maximumFractionDigits = max
        }

        var value: AnyObject?
        var consumedRange = NSRange(location: 0, length: (text as NSString).length)

        do {
            try formatter.getObjectValue(&value, for: text, range: &consumedRange)
        } catch {
            return nil
        }

        guard consumedRange.location == 0,
              consumedRange.length == (text as NSString).length,
              let number = value as? NSNumber else {
            return nil
        }
        return number
    }

    public static func parseNumber(
        _ text: String,
        locale: Locale = .current,
        options: FormatOptions = .decimal
    ) -> NSNumber? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let number = parseStrict(trimmed, locale: locale, options: options) {
            return number
        }

        let decimalSeparator = locale.decimalSeparator ?? "."
        guard decimalSeparator != ".",
              trimmed.range(of: #"^\d+\.\d+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return parseStrict(trimmed, locale: Locale(identifier: "en_US_POSIX"), options: options)
    }

    public static func parseDecimal(
        _ text: String,
        locale: Locale = .current
    ) -> Decimal? {
        parseNumber(text, locale: locale, options: .decimal)?.decimalValue
    }

    public static func string(
        for decimal: Decimal,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        formatter.isLenient = false
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSDecimalNumber(decimal: decimal))
            ?? NSDecimalNumber(decimal: decimal).stringValue
    }

    public static func parseDouble(
        _ text: String,
        in range: ClosedRange<Double>? = nil,
        locale: Locale = .current
    ) -> Double? {
        guard let number = parseNumber(text, locale: locale, options: .double) else { return nil }
        let dVal = number.doubleValue
        guard dVal.isFinite else { return nil }
        if let range = range {
            guard range.contains(dVal) else { return nil }
        }
        return dVal
    }

    public static func string(
        for double: Double,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: double)) ?? String(double)
    }

    public static func parseFilterAmount(
        _ text: String,
        locale: Locale = .current
    ) -> ValidatedDecimalParseResult<Double> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard let value = parseDouble(trimmed, locale: locale), value >= 0 else {
            return .invalid
        }
        return .value(value)
    }
}
```

#### Step 2: Refactor `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterAmountField.swift`

Replace `InvoiceFilterAmountInput` implementation with delegates to `ValidatedDecimalParser`:

```swift
public typealias InvoiceFilterAmountParseResult = ValidatedDecimalParseResult<Double>

enum InvoiceFilterAmountInput {
    static func parse(
        _ text: String,
        locale: Locale = .current
    ) -> InvoiceFilterAmountParseResult {
        ValidatedDecimalParser.parseFilterAmount(text, locale: locale)
    }

    static func string(for value: Double?, locale: Locale = .current) -> String {
        guard let value else { return "" }
        return ValidatedDecimalParser.string(for: value, locale: locale)
    }
}
```

#### Step 3: Refactor `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift`

Replace `InvoiceDecimalInput` and `InvoiceDoubleInput` implementations with delegates to `ValidatedDecimalParser`:

```swift
enum InvoiceDecimalInput {
    static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        ValidatedDecimalParser.parseDecimal(text, locale: locale)
    }

    static func string(for value: Decimal, locale: Locale = .current) -> String {
        ValidatedDecimalParser.string(for: value, locale: locale)
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
```

---

## 5. Verification Method

1. **Build & Test SharedUI Package**:
   ```bash
   swift test --package-path Packages/SharedUI
   ```
   Must pass with 0 failures.

2. **Build & Test Feature.Invoices Package**:
   ```bash
   swift test --package-path Packages/Feature.Invoices
   ```
   Must pass all 75+ tests, specifically `InvoicesListQueryTests`.

3. **Build & Test Feature.InvoiceTemplateEditor Package**:
   ```bash
   swift test --package-path Packages/Feature.InvoiceTemplateEditor
   ```
   Must pass all 159+ tests, specifically `InvoiceEditorAccessibilityAndNavigationTests`, `InvoiceEditorSeparationTests`, and `RequirementR2StressTests`.

4. **Architecture Guardrails**:
   ```bash
   ./scripts/architecture-check.sh
   ```
   Must pass with 0 architectural violations.

5. **Full Master Refactor Verification**:
   ```bash
   ./scripts/refactor-verify.sh
   ```
