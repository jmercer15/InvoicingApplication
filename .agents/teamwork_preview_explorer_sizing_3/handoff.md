# Handoff Report — Nested Split Layout Sizing Bug Investigation

## 1. Observation

Direct observations from the `Feature_InvoiceTemplateEditor` codebase:

### Context Propagation Sizing Loss (Bug 1)
- **`LinearSplitView.swift`** (lines 222-223):
  ```swift
  currentWidthSizingMode: direction == .horizontal && split.childWidthSizingModes.indices.contains(index) ? split.childWidthSizingModes[index] : nil,
  currentHeightSizingMode: direction == .vertical && split.childHeightSizingModes.indices.contains(index) ? split.childHeightSizingModes[index] : nil,
  ```
  When the direction is `.horizontal`, `currentHeightSizingMode` is set to `nil`, losing parent sizing contexts. Conversely, when the direction is `.vertical`, `currentWidthSizingMode` is set to `nil`.

- **`GridSplitView.swift`** (lines 236-237):
  ```swift
  currentWidthSizingMode: nil,
  currentHeightSizingMode: nil,
  ```
  Both width and height sizing modes are discarded and set to `nil` for grid cells, losing column/row modes.

- **`ModernCanvasView.swift`** (lines 381-382):
  ```swift
  currentWidthSizingMode: nil,
  currentHeightSizingMode: nil,
  ```
  At the root level context creation, the section's actual height sizing mode is discarded and replaced with `nil`.

- **`InvoiceCanvasView.swift`** (lines 136-137):
  ```swift
  currentWidthSizingMode: nil,
  currentHeightSizingMode: nil,
  ```
  The computed `readOnlyContext` property hardcodes `nil` for both sizing modes because it lacks context about which section is being rendered.

### Missing Secondary Sizing Resolution & Alignment (Bug 2)
- **`SplittableRectangleView.swift`** (lines 56-75):
  ```swift
  let innerSize = CGSize(
      width: max(0, containerSize.width - childPadding.leading - childPadding.trailing),
      height: max(0, containerSize.height - childPadding.top - childPadding.bottom)
  )
  
  Group {
      if let split {
          splitContent(for: split, size: innerSize)
      } else {
          leafContent(size: innerSize)
      }
  }
  .frame(width: innerSize.width, height: innerSize.height)
  .padding(EdgeInsets(
      top: childPadding.top,
      leading: childPadding.leading,
      bottom: childPadding.bottom,
      trailing: childPadding.trailing
  ))
  .frame(width: containerSize.width, height: containerSize.height)
  ```
  This recursively sizes nested split or leaf views to the full `innerSize` and `containerSize` regardless of `.shrink` secondary sizing modes, and does not apply alignment settings from the parent layout to position shrunken items.

---

## 2. Logic Chain

1. **Nested Layout Loss**: Because linear and grid splits hardcode secondary or both sizing modes to `nil` when building child contexts, nested sub-splits and leaves lose visibility of their grandparent-inherited sizing modes along the secondary axis (Observation 1, Observation 2, Observation 3).
2. **Missing Resolution**: When a leaf or sub-split is configured with a `.shrink` sizing mode, it is expected to size down to its intrinsic content limits rather than stretching to the full parent boundary.
3. **Stretching Fallback**: However, `SplittableRectangleView` (Observation 4) sizes both child splits and leaves directly to the parent's full allocated `innerSize` and `containerSize`, ignoring sizing modes and alignment.
4. **Availability of Helpers**: Standard intrinsic sizing APIs exist on the model layer (`SectionSplit.intrinsicSize(along:document:)` in `SectionSplit+Operations.swift`) and on the leaf sizing layer (`LeafComponentFrameSizing` methods) that are capable of calculating correct intrinsic dimensions (Observation 5).
5. **Resolution**: By correctly propagating width/height modes through `makeChildContext(for:)` / `makeReadOnlyContext(for:)`, and implementing shrunken axis layout resolution inside `SplittableRectangleView`'s body (clamping size using the intrinsic size APIs and aligning using `parentAlignment`), we can achieve deterministic, non-stretching nested split rendering.

---

## 3. Caveats

- **Asynchronous ideal size updates**: If a layout's ideal size is calculated asynchronously, the first rendering pass uses intrinsic size estimation APIs, which may differ slightly from the settled layout pass. However, using `LeafComponentFrameSizing` and `SectionSplit+Operations` ensures consistent fallbacks.
- **Divider resizing**: When user resizes a split, it switches to `.fixed` mode. The propagation logic must still maintain this mode correctly to avoid reset.

---

## 4. Conclusion

- **Sizing loss** (Bug 1) is located in `LinearSplitView.swift`, `GridSplitView.swift`, `ModernCanvasView.swift`, and `InvoiceCanvasView.swift` where contexts are created with `nil` sizing modes.
- **Missing secondary resolution** (Bug 2) is located in `SplittableRectangleView.swift` where `containerSize` and `innerSize` are forced without considering the `.shrink` mode and parent alignment.
- **Fix Recommendation**:
  - Propagate parent width/height modes in `LinearSplitView.swift`, map grid row/column sizing to width/height modes in `GridSplitView.swift`, and pass section heights at root level.
  - Dynamically calculate shrunken widths/heights inside `SplittableRectangleView.swift` using `split.intrinsicSize` and `LeafComponentFrameSizing.intrinsicSize`, framing the inner content to the shrunken bounds and aligning it inside the allocated container space via `parentAlignment`'s SwiftUI `Alignment`.

---

## 5. Verification Method

### Automated Tests
1. Run the existing template editor tests:
   ```bash
   swift test --package-path Packages/Feature.InvoiceTemplateEditor
   ```
2. Add a new unit test class (e.g. `LayoutAdversarialTests` in `Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests`) verifying:
   - propagation of sizing modes through nested splits resolves to the correct context.
   - sizing resolution correctly shrinks nested split widths/heights to their content intrinsic size and respects parent alignments.
