# Handoff Report — Explorer M2 Area 3 (Date & Currency Formatter Centralization)

## 1. Observation

### Observation 3.1: Centralized Helpers in `SharedUI`
- **File**: `Packages/SharedUI/Sources/SharedUI/Helpers/CurrencyFormatting.swift`
- **Line 5–30 (`CurrencyFormatting`)**:
  ```swift
  public enum CurrencyFormatting {
      public static func display(
          _ amount: Double,
          code: String = "AUD",
          locale: Locale = .current
      ) -> String {
          Decimal(amount).formatted(.currency(code: code).locale(locale))
      }

      public static func display(
          _ amount: Decimal,
          code: String = "AUD",
          locale: Locale = .current
      ) -> String {
          amount.formatted(.currency(code: code).locale(locale))
      }

      /// Numeric text for editable amount fields (no currency symbol).
      public static func editableAmount(_ amount: Double, fractionDigits: Int = 2) -> String {
          amount.formatted(.number.precision(.fractionLength(fractionDigits)))
      }

      public static func editableAmount(_ amount: Decimal, fractionDigits: Int = 2) -> String {
          amount.formatted(.number.precision(.fractionLength(fractionDigits)))
      }
  }
  ```
- **Line 33–79 (`DateFormatting`)**:
  ```swift
  public enum DateFormatting {
      public static func shortDate(_ date: Date, locale: Locale = .current) -> String {
          date.formatted(Date.FormatStyle(date: .numeric, time: .omitted).locale(locale))
      }

      public static func mediumDate(_ date: Date, locale: Locale = .current) -> String {
          date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
      }

      public static func mediumDateTime(_ date: Date, locale: Locale = .current) -> String {
          date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
      }

      public static func longDate(_ date: Date, locale: Locale = .current) -> String {
          date.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale))
      }

      public static func timeOnly(_ date: Date, locale: Locale = .current) -> String {
          date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
      }
      // ...
  }
  ```

### Observation 3.2: Render-Pass Allocations & Singletons in `InvoiceFormatting.swift`
- **File**: `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift`
- **Lines 411–430 (`InvoiceMoneyFormatter` formatters)**:
  ```swift
  private static let wholeNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    formatter.usesGroupingSeparator = true
    return formatter
  }()

  private static let fractionalFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = fractionDigits
    formatter.maximumFractionDigits = fractionDigits
    formatter.usesGroupingSeparator = true
    return formatter
  }()
  ```
- **Lines 492–511 (`currencySymbol` & `currencyString` render-pass `NumberFormatter` allocations)**:
  ```swift
  private static func currencySymbol(for currencyCode: String) -> String {
    let code = InvoiceCurrencyCode.normalizedOrDefault(currencyCode)
    if code == "USD" { return "$" }

    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    return formatter.currencySymbol ?? code
  }

  private static func currencyString(for roundedAmount: Decimal, currencyCode: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currencyCode.uppercased()
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = fractionDigits
    formatter.usesGroupingSeparator = true
    let fallback = numericString(for: roundedAmount)
    return formatter.string(from: NSDecimalNumber(decimal: roundedAmount)) ?? fallback
  }
  ```
- **Lines 1017–1048 (`InvoiceDateFormatter` static `DateFormatter` instances)**:
  ```swift
  enum InvoiceDateFormatter {
    private static let mediumFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      return formatter
    }()

    private static let shortFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateStyle = .short
      formatter.timeStyle = .none
      return formatter
    }()

    private static let longFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateStyle = .long
      formatter.timeStyle = .none
      return formatter
    }()

    static func documentString(for date: Date, style: InvoiceDateFormatStyle) -> String {
      switch style {
      case .medium: mediumFormatter.string(from: date)
      case .short: shortFormatter.string(from: date)
      case .long: longFormatter.string(from: date)
      }
    }
  }
  ```

### Observation 3.3: Ad-Hoc `DateFormatter` in `InvoicesContentToolbar.swift`
- **File**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift`
- **Lines 28–32 & 166–167**:
  ```swift
  private static let shortDateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateStyle = .short
      return formatter
  }()

  // ...
  if viewModel.isDateFilterActive {
      let startStr = viewModel.filterStartDate.map { Self.shortDateFormatter.string(from: $0) } ?? "-"
      let endStr = viewModel.filterEndDate.map { Self.shortDateFormatter.string(from: $0) } ?? "-"
      parts.append("Date: \(startStr) - \(endStr)")
  }
  ```

### Observation 3.4: Ad-Hoc `NumberFormatter` in `NDISPriceUtilities.swift`
- **File**: `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift`
- **Lines 74–86**:
  ```swift
  private static let priceFormatter: NumberFormatter = {
      let formatter = NumberFormatter()
      formatter.numberStyle = .currency
      formatter.currencyCode = "AUD"
      formatter.maximumFractionDigits = 2
      formatter.minimumFractionDigits = 2
      return formatter
  }()

  public static func formatPrice(_ price: Decimal) -> String {
      return priceFormatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
  }
  ```

---

## 2. Logic Chain

1. **Observation 3.1 & 3.2**: `SharedUI` already provides modern Foundation `FormatStyle`-based enums `CurrencyFormatting` and `DateFormatting`. Meanwhile, `InvoiceFormatting.swift` instantiates `NumberFormatter()` during view rendering (in `currencySymbol` and `currencyString`). `NumberFormatter` instantiation is expensive and unnecessary when Foundation `FormatStyle` or centralized singletons are available.
2. **Observation 3.2 & 3.3**: `InvoiceDateFormatter` and `InvoicesContentToolbar.swift` both instantiate static `DateFormatter` objects (`mediumFormatter`, `shortFormatter`, `longFormatter`, `shortDateFormatter`). These can be directly replaced by calls to `SharedUI.DateFormatting.shortDate`, `mediumDate`, `longDate`, which leverage Swift's thread-safe and efficient `Date.FormatStyle`.
3. **Observation 3.4**: `NDISPriceUtilities.swift` maintains a private static `priceFormatter: NumberFormatter` to format price decimals as AUD currency strings. By using `SharedUI.CurrencyFormatting.display(_:code:locale:)` or Foundation's `Decimal.formatted(.currency(code: "AUD"))`, the ad-hoc static `NumberFormatter` in `NDISPriceUtilities.swift` can be completely eliminated.
4. **Enhancements to `SharedUI.CurrencyFormatting`**: To fully support `InvoiceMoneyFormatter` display styles (`.symbol`, `.code`, `.iso`), `SharedUI.CurrencyFormatting` should be extended with:
   - `public static func currencySymbol(for code: String, locale: Locale = .current) -> String`
   - `public static func display(_ amount: Decimal, code: String, omitFractionIfWhole: Bool, locale: Locale = .current) -> String`
5. **Impact**: Deleting local static `NumberFormatter`/`DateFormatter` objects across packages reduces memory footprint and eliminates per-render-pass heap allocations, standardizing output across the app.

---

## 3. Caveats

- **Locale Consistency**: `DateFormatting.shortDate` uses `.formatted(Date.FormatStyle(date: .numeric, time: .omitted))` while `DateFormatter.dateStyle = .short` formats dates similarly for the active locale. Both respect `Locale.current`.
- **Package Dependency Hierarchy**: `PersistenceModels` depends on `Core`. `SharedUI` depends on `Core` and `PersistenceModels`. Therefore, `SharedUI` can access `PersistenceModels` types if needed, but `PersistenceModels` cannot import `SharedUI`. In `NDISPriceUtilities.swift`, price formatting uses `Foundation` (`Decimal.formatted(.currency(code: "AUD"))`) or delegates to `SharedUI` at UI call sites.
- **Whole-Number Formatting in Invoices**: `InvoiceMoneyFormatter` omits `.00` for whole numbers (e.g. `$50` instead of `$50.00`) depending on whether fractional digits exist. The enhanced `CurrencyFormatting` helper will preserve this custom formatting option when requested.

---

## 4. Conclusion & Actionable Replacements

### Action Item 1: Extend `SharedUI.CurrencyFormatting`
Add helper methods to `Packages/SharedUI/Sources/SharedUI/Helpers/CurrencyFormatting.swift`:
```swift
extension CurrencyFormatting {
    /// Returns symbol for currency code (e.g. "USD" -> "$", "AUD" -> "$", "EUR" -> "€").
    public static func symbol(for code: String, locale: Locale = .current) -> String {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalizedCode == "USD" { return "$" }
        let formatStyle = Decimal.FormatStyle.currency(code: normalizedCode).locale(locale)
        return locale.currencySymbol ?? normalizedCode
    }

    /// Formats decimal amount with optional zero fraction digits trimming for whole numbers.
    public static func display(
        _ amount: Decimal,
        code: String = "AUD",
        omitFractionIfWhole: Bool = false,
        locale: Locale = .current
    ) -> String {
        if omitFractionIfWhole && isWholeNumber(amount) {
            return amount.formatted(.currency(code: code).precision(.fractionLength(0)).locale(locale))
        }
        return amount.formatted(.currency(code: code).locale(locale))
    }

    private static func isWholeNumber(_ amount: Decimal) -> Bool {
        var value = amount
        var truncated = Decimal()
        NSDecimalRound(&truncated, &value, 0, .down)
        return amount == truncated
    }
}
```

### Action Item 2: Refactor `InvoiceFormatting.swift`
- In `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift`:
  - Replace `currencySymbol(for:)` body with `CurrencyFormatting.symbol(for: currencyCode)`.
  - Replace `currencyString(for:currencyCode:)` with `CurrencyFormatting.display(roundedAmount, code: currencyCode, omitFractionIfWhole: true)`.
  - In `InvoiceDateFormatter`, replace static `DateFormatter` singletons with calls to `SharedUI.DateFormatting.shortDate`, `mediumDate`, `longDate`.

### Action Item 3: Refactor `InvoicesContentToolbar.swift`
- In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift`:
  - Remove `private static let shortDateFormatter: DateFormatter`.
  - Update `filterHelpText`:
    ```swift
    let startStr = viewModel.filterStartDate.map { DateFormatting.shortDate($0) } ?? "-"
    let endStr = viewModel.filterEndDate.map { DateFormatting.shortDate($0) } ?? "-"
    ```

### Action Item 4: Refactor `NDISPriceUtilities.swift`
- In `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift`:
  - Remove `private static let priceFormatter: NumberFormatter`.
  - Update `formatPrice(_ price: Decimal) -> String`:
    ```swift
    public static func formatPrice(_ price: Decimal) -> String {
        return price.formatted(.currency(code: "AUD"))
    }
    ```

---

## 5. Verification Method

1. **Execute Unit Tests**:
   - `swift test --package-path Packages/SharedUI`
   - `swift test --package-path Packages/Feature.Invoices`
   - `swift test --package-path Packages/Feature.InvoiceTemplateEditor`
   - `swift test --package-path Packages/PersistenceModels`
2. **Architecture Check Script**:
   - Execute `./scripts/architecture-check.sh` from repository root to confirm clean architectural boundaries.
3. **Invalidation Conditions**:
   - Any failure in `CurrencyFormattingTests`, `NDISPriceHandlingTests`, or date formatting assertions.
