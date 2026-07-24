# Context - Nested Splits Sizing Bug Fixes

## Background
Nested splits under-propagate and fail to apply their width/height sizing modes correctly along secondary axes.

### Bug 1: Sizing Mode Loss during Context Propagation
In `LinearSplitView.swift` and `GridSplitView.swift`, the `makeChildContext(for:)` function creates child interaction contexts where the sizing modes are frequently discarded and replaced with `nil`. Specifically:
- Horizontal splits set height mode to `nil`, losing the height mode inherited from a grandparent vertical split.
- Vertical splits set width mode to `nil`, losing the inherited width mode.
- Grid splits set both width and height modes to `nil`.
- `ModernCanvasView` and `InvoiceCanvasView` pass `nil` for `currentHeightSizingMode` at the root level.

### Bug 2: Missing Secondary Sizing Resolution in parent splits & leaves
When a child split or leaf is configured to `.shrink` along its secondary axis:
- `SplittableRectangleView` and `RatioBasedLayout` force the child/leaf to stretch to parent's full allocated secondary size.
- They do not calculate or enforce shrunken size, or align content per alignment settings.

## Files of Interest
- `LinearSplitView.swift`
- `GridSplitView.swift`
- `SplittableRectangleView.swift`
- `RatioBasedLayout` (file name or class/struct)
- `ModernCanvasView.swift`
- `InvoiceCanvasView.swift`
- `LayoutAdversarialTests.swift` or similar test files in `Feature_InvoiceTemplateEditorTests`
