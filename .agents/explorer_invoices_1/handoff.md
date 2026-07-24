# Handoff Report: Feature.Invoices UI Refinement

## 1. Observation
We analyzed the views in `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/` and identified the following specific states and implementations:
- In `InvoicesColumns.swift` (lines 65–73), when the asynchronous list projection (`cachedProjection`) is nil, it falls back to a raw `ProgressView` without styling or container:
  ```swift
  @ViewBuilder
  private var content: some View {
      if let projection = cachedProjection {
          invoiceList(projection: projection)
      } else {
          ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
  }
  ```
- In `InvoicesContainerViewModel+List.swift` (lines 45–51), when a database fetch error is caught, it prints to the console but does not set any user-facing error message property in the view model, causing the view to show a default `"No Invoices Found"` empty state instead of an error message:
  ```swift
  } catch {
      invoiceEntities = []
      updateVisibleInvoices([])
      print("❌ [InvoicesContainerViewModel] Failed loading invoices: \(error)")
  }
  ```
- In `InvoiceEditorViewModel.swift` (lines 164–169), the view model tracks template/items loading via `public var isLoading: Bool = false`, but this is not monitored or represented inside `InvoiceEditor.swift` (lines 23–79), leaving the user without loading indication while templates are fetched on invoice selection.
- In `InvoiceLineItemsSection.swift` (lines 19–23), when there are no items added to the invoice, it renders a plain italic label without card elevation/visual hierarchy standard styling:
  ```swift
  if viewModel.invoiceItems.isEmpty {
      Text("No items added")
          .foregroundStyle(StyleGuide.Colors.textSecondary)
          .italic()
          .frame(maxWidth: .infinity, alignment: .leading)
  }
  ```
- Conversely, `InvoiceInspectorFormView.swift` section cards and `InvoicesView.swift` list rows (which delegate to `NavigationListRow`) correctly implement standard `EnhancedGroupBoxStyle` (with `.regularMaterial`, `0.5` stroke, and `0.04` shadow) and `.glassEffect(.regular.interactive(true))` visual treatments respectively.

---

## 2. Logic Chain
- **Point 1 (List loading state)**: A raw `ProgressView()` in `InvoicesColumns.swift` violates the visual polish guidelines for loading states since `SharedUI` exposes `LoadingView`, which provides a styled glass-morphic panel and shadow.
- **Point 2 (Swallowed List Errors)**: Swallowing query errors in `reloadInvoices` and defaulting to an empty list means database access issues show up as a misleading `"No Invoices Found"` empty state, violating the "user-readable error states" rule. Surfacing this via a `listLoadError` property enables `InvoicesContentColumn` to display an error state.
- **Point 3 (Unrepresented Editor Loading)**: Although `InvoiceEditorViewModel` correctly sets `isLoading` during template fetching, omitting the `loadingOverlay` modifier in `InvoiceEditor` means the UI stays interactive and unpolished during async load.
- **Point 4 (List Row & Card Elevation)**: Since list rows are rendered via `FoldPaperContainer` using `NavigationListRow`, they inherit standard elevated glass backgrounds. Inspector sections also inherit correct elevation properties via `EnhancedGroupBoxStyle`. Hence, card structures and list rows are already visually consistent, except for inline/empty placeholders.

---

## 3. Caveats
- The list-level blocking `loadingOverlay` modifier was deliberately not added during search queries in `InvoicesView` because search typing triggers debounced reloads; disabling the UI on every keystroke would break real-time search responsiveness. Instead, background updates are preferred.
- The `ReferenceDataWorkflowActor` database fetches in the detail column are expected to load near-instantly, so we did not add a separate full-pane loader for reference data, relying instead on the editor's initial template loading.

---

## 4. Conclusion
We proposed three specific changes (with code diffs detailed in `analysis.md`):
1. Replace `ProgressView()` with `LoadingView("Loading invoices...")` and surface database/list errors via `EmptyStateView(icon: "exclamationmark.triangle.fill", title: "Failed to Load Invoices", message: error)` in `InvoicesColumns.swift`.
2. Add a `listLoadError` property to `InvoicesContainerViewModel` to track query/fetch failures.
3. Append `.loadingOverlay(isLoading: viewModel.isLoading, message: "Loading template details...")` to the editor root view in `InvoiceEditor.swift` to handle template metadata loading states.

---

## 5. Verification Method
- **Verify build and tests**: Run the unit test suite for the package to ensure that no regressions are introduced:
  ```bash
  swift test --package-path Packages/Feature.Invoices
  ```
- **Inspect UI transitions**: After implementation, trigger list loading by selecting different filters and verify that `LoadingView` is displayed. Simulate a query failure (e.g. invalid query spec or mock database error) to verify that `EmptyStateView` with the error triangle icon is shown instead of `"No Invoices Found"`.
