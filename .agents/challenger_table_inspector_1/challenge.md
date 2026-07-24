# Table & Cell Inspector Layout and Model Logic - Adversarial Review

## Challenge Summary

**Overall risk assessment**: HIGH

Adding new fields to `ComponentStyle` breaks decoding of existing saved templates due to synthesized `Codable` requiring all non-optional fields. Additionally, extreme inputs for padding, font sizes, and invalid table selection ranges do not have proper validation or clamping, leaving the layout engine vulnerable to rendering anomalies or UI failures.

---

## Challenges

### [High] Challenge 1: Lack of Backward Compatibility in synthesized `ComponentStyle` Codable
- **Assumption challenged**: Assumed that adding new styling properties to `ComponentStyle` is safe.
- **Attack scenario**: A user tries to load a document/template saved with an older version of the app that lacks newer fields (e.g., CoreText styling, bottom padding, writing direction).
- **Blast radius**: The `JSONDecoder` throws a `keyNotFound` error, causing the entire template to fail loading, leading to data loss or template corruption for the user.
- **Mitigation**: Implement a custom `init(from decoder: Decoder)` in `ComponentStyle` that decodes fields using `decodeIfPresent` and provides fallback default values for missing keys, rather than relying on synthesized compiler generation.

### [Medium] Challenge 2: Clamping and Validation of Cell Padding & Font Size
- **Assumption challenged**: Cell padding values and cell font sizes will always be reasonable positive numbers.
- **Attack scenario**: A corrupted template JSON or direct modification sets `CellStyle.padding` to a negative value (e.g., `-20.0`), a very large value (e.g., `10000.0`), or `NaN`/`Infinity`. Similarly, setting `CellStyle.fontSize` to negative, zero, or `NaN`/`Infinity`.
- **Blast radius**: Passing negative padding or `NaN` to SwiftUI `.padding()` causes layout rendering anomalies, text overlapping, or rendering engine crashes. Passing `NaN` or `Infinity` to `CTFont` font size generation might crash CoreText or render text invisibly.
- **Mitigation**: Clamp padding to a safe range (e.g. `0...100`) and font size to `8...144` before applying to views or calling CoreText font creator.

### [Low] Challenge 3: Unbounded Axis Indices in Multi-Selection Sizing Updates
- **Assumption challenged**: Sizing updates will only be applied to valid positive indices corresponding to actual rows/columns.
- **Attack scenario**: Selection contains negative indices (e.g., `-5`) or extremely large indices (e.g., `999999`).
- **Blast radius**: Updates are written directly into `columnConfigurations` or `rowConfigurations` dictionaries. While it doesn't crash due to dictionary keys, it could lead to memory bloat or configuration mismatch.
- **Mitigation**: Validate row/column indices against the actual grid dimensions of the table before storing configurations.

---

## Stress Test Results

- **Multi-Selection Sizing Mode Update** → Concurrently updates sizing modes and widths/heights for multiple rows/columns → Handled successfully in model logic, config dictionaries are populated → **PASS**
- **Mixed Sizing Modes Evaluation** → Checks how `SizingMode` resolves for mixed flexible/auto/fixed selections → Resolves to `.fixed` fallback → **PASS**
- **Negative & Extreme Padding Values** → Updates and stores `CellStyle.padding` successfully; `NSAttributedString` generation does not crash → Stored without clamping; CoreText handles large/small numbers but SwiftUI layout may exhibit visual glitches → **PASS (logic level) / WARNING (view level)**
- **Negative & NaN Font Sizes in CoreText** → Checks if `cellTextNSAttributedString` crashes when given negative, zero, NaN, or Infinity font size → CoreText handles gracefully, does not crash → **PASS**
- **Legacy Decoding without CellStyles** → Try to decode partial `ComponentStyle` JSON lacking keys like `fontWeight` → Throws `DecodingError.keyNotFound` → **FAIL (Vulnerability Confirmed)**
- **Legacy Decoding CellStyle missing Padding** → Decodes `CellStyle` without padding from JSON → Decodes correctly with `padding = nil` → **PASS**

---

## Unchallenged Areas

- **Gesture Handlers and Canvas UI Rendering** — Gesture interaction and mouse dragging triggers are out of scope for model-level unit testing.
