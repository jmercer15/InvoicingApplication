# Analysis Report: Style & Layout Token Standardization for Feature.Invoices

## Executive Summary
An analysis of the views in `Packages/Feature.Invoices` has identified multiple layout and styling inconsistencies in `InvoicesView.swift`, including the use of deprecated modifiers (`.cornerRadius`, `.foregroundColor`), inconsistent scaling of layout paddings, and a raw numeric animation duration. Other views in the package successfully follow `StyleGuide` and `ColorSystem` conventions.

---

## 1. Styling & Layout Observations

The following files under `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/` were scanned:

### InvoicesView.swift
| Line | Code | Type | Severity | Description / Recommendation |
|---|---|---|---|---|
| 28 | `@ScaledMetric(relativeTo: .body) private var cornerRadiusSmall = StyleGuide.Dimensions.cornerRadiusSmall` | Token Scaling | Minor | Corner radii should not be scaled as they are static design system variables. Use the token directly. |
| 29-30 | Local `@ScaledMetric` padding declarations | Redundancy | Minor | Local alias for tokens that could be referenced directly to maintain consistency. |
| 171 | `withAnimation(.easeOut(duration: 0.2)) {` | Raw Literal | Moderate | Magic number `0.2` used for animation duration. Replace with `StyleGuide.Animations.durationMedium` or `durationShort`. |
| 212, 229, 245, 262, 279 | `.foregroundColor(Color.white)` | Deprecated | Minor | Use of deprecated `.foregroundColor(_:)` modifier instead of `.foregroundStyle(_:)`. |
| 230-231 | `.padding(.horizontal, paddingMediumLarge)`<br>`.padding(.vertical, paddingSmall)` | Inconsistency | Minor | Uses local scaled variables, while subsequent buttons on lines 246-247, 263-264, and 280-281 use raw, unscaled tokens `StyleGuide.Dimensions.paddingMediumLarge` and `StyleGuide.Dimensions.paddingSmall` directly. All buttons in the HStack should be aligned. |
| 233, 249, 266, 283 | `.cornerRadius(cornerRadiusSmall)` | Deprecated | Moderate | Use of deprecated `.cornerRadius(_:)` modifier. Buttons can use `.background(..., in: actionButtonShape)` directly to set background shape and clip, removing the need for both `.cornerRadius(...)` and `.contentShape(...)`. |

---

## 2. Hardcoded Layout Sentinels (Not Padding/Spacing/Radius)
Some local metrics are defined in form structures but are layout constraints rather than margin spacing:
- **`InvoiceFilterPopoverContent.swift:10`**: `@ScaledMetric private var clientListMaxHeight: CGFloat = 120`
- **`InvoiceInspectorFormView.swift:14`**: `@ScaledMetric private var notesMinHeight: CGFloat = 60`

*Recommendation: These can remain local as they dictate custom component boundaries, but should be documented.*

---

## 3. Proposed Fix Strategy

### Recommended Token Replacements
1. **Animation Duration**:
   Replace `.easeOut(duration: 0.2)` with `.easeOut(duration: StyleGuide.Animations.durationShort)` (or `durationMedium` for standard feel).
2. **Button Corner Radius**:
   Use modern `.background(ColorSystem.Primary.blue, in: actionButtonShape)` which eliminates `.cornerRadius(...)` and `.contentShape(actionButtonShape)`.
3. **Scaled Padding**:
   Align button padding by using direct, unscaled tokens `StyleGuide.Dimensions.paddingMediumLarge` and `StyleGuide.Dimensions.paddingSmall` consistently, or apply `@ScaledMetric` uniformly across all sibling buttons.

### Proposed Code Diff (before -> after)

#### InvoicesView.swift
```diff
--- InvoicesView.swift (Original)
+++ InvoicesView.swift (Proposed)
@@ -28,5 +28,4 @@
-    @ScaledMetric(relativeTo: .body) private var cornerRadiusSmall = StyleGuide.Dimensions.cornerRadiusSmall
-    @ScaledMetric(relativeTo: .body) private var paddingMediumLarge = StyleGuide.Dimensions.paddingMediumLarge
-    @ScaledMetric(relativeTo: .body) private var paddingSmall = StyleGuide.Dimensions.paddingSmall
+    private var cornerRadiusSmall: CGFloat { StyleGuide.Dimensions.cornerRadiusSmall }
 
@@ -169,3 +168,3 @@
         } else {
             // Normal mode, select the invoice
-            withAnimation(.easeOut(duration: 0.2)) {
+            withAnimation(.easeOut(duration: StyleGuide.Animations.durationShort)) {
                 containerViewModel.requestSelectInvoice(invoice)
             }
         @@ -207,2 +206,2 @@
             if isMultiSelectMode {
-                let actionButtonShape = RoundedRectangle(cornerRadius: cornerRadiusSmall, style: .continuous)
+                let actionButtonShape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous)
                 HStack {
@@ -211,4 +210,4 @@
                         Text("\(selectedInvoices.count) selected")
-                            .foregroundColor(Color.white)
+                            .foregroundStyle(Color.white)
                             .font(StyleGuide.Typography.bodyMedium)
                         Text("Press Esc or click Cancel to exit")
-                            .foregroundColor(Color.white.opacity(0.8))
+                            .foregroundStyle(Color.white.opacity(0.8))
                             .font(StyleGuide.Typography.caption)
@@ -228,7 +227,5 @@
                         Text("Cancel")
-                            .foregroundColor(Color.white)
-                            .padding(.horizontal, paddingMediumLarge)
-                            .padding(.vertical, paddingSmall)
-                            .background(StyleGuide.Colors.secondary)
-                            .cornerRadius(cornerRadiusSmall)
-                            .contentShape(actionButtonShape)
+                            .foregroundStyle(Color.white)
+                            .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
+                            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
+                            .background(StyleGuide.Colors.secondary, in: actionButtonShape)
                     }
@@ -244,7 +241,5 @@
                         }
-                        .foregroundColor(Color.white)
+                        .foregroundStyle(Color.white)
                         .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                         .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
-                        .background(ColorSystem.Status.error)
-                        .cornerRadius(cornerRadiusSmall)
-                        .contentShape(actionButtonShape)
+                        .background(ColorSystem.Status.error, in: actionButtonShape)
                     }
@@ -261,7 +256,5 @@
                         }
-                        .foregroundColor(Color.white)
+                        .foregroundStyle(Color.white)
                         .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                         .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
-                        .background(ColorSystem.Primary.blue)
-                        .cornerRadius(cornerRadiusSmall)
-                        .contentShape(actionButtonShape)
+                        .background(ColorSystem.Primary.blue, in: actionButtonShape)
                     }
@@ -278,7 +271,5 @@
                         }
-                        .foregroundColor(Color.white)
+                        .foregroundStyle(Color.white)
                         .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                         .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
-                        .background(ColorSystem.Primary.blue)
-                        .cornerRadius(cornerRadiusSmall)
-                        .contentShape(actionButtonShape)
+                        .background(ColorSystem.Primary.blue, in: actionButtonShape)
                     }
```
