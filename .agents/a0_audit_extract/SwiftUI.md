# SwiftUI Read-Only Audit — InvoicingApplication

Sampled: **AppShell**, **SharedUI**, **Feature.BillingHub**, **Feature.Calendar**, **Feature.Clients**, **Feature.Invoices**, **Feature.InvoiceTemplateEditor**, **Feature.Settings**, **WorkspaceUI**.  
Project skills consulted: `swiftui-navigation-presentation`, `swiftui-state-management-data-flow`, `swiftui-scroll-views`, `swiftui-focus`, `swiftui-visual-components`, `swiftui-layout-system`.

---

## 1. swiftui-pro (`swiftui-pro/SKILL.md` + references)

**SkillCoverage: 71%**

Modern Observation stack, navigation APIs, and accessibility in BillingHub/InvoiceRootView are solid. Widespread legacy styling (`foregroundColor`, `cornerRadius`), concurrency leftovers (`DispatchQueue`), and monolithic template-editor files drag score down.

### Strengths
- `@Observable` + `@MainActor` on core VMs (`BillingHubViewModel`, `CalendarViewModel`, `InvoicesContainerViewModel`, `AppNavigationManager`)
- `NavigationSplitView` / `NavigationStack` + typed routing (`AppNavigationManager`, `BillableDraftsHomeView`)
- Reduce Motion respected in `InvoiceRootView`, `InvoicesView`, `FoldPaperContainer` (via `.appRespectsReduceMotion()`)
- Rich accessibility in BillingHub workflow panels (`PaymentReceivedPanel`, `PendingPaymentPanel`, `BillingHubBoardSectionViews`)
- `ContentUnavailableView` for empty/error states (BillingHub, Calendar, InvoiceRootView)
- Central `StyleGuide` tokens; `@ScaledMetric` in `DayColumnView`, `HierarchySectionCard`, `CalendarRowView`
- `.task(id:)` for cancellable async (`CalendarView`, `BillingHubView`, `InvoicesView`)

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P0** | `ServiceAssignmentSheetView.swift:401-403` | accessibility.md — no `onTapGesture` for tappable UI | Row selection uses `onTapGesture`; VoiceOver/keyboard miss native button semantics despite labels | Replace with `Button(action:onToggle) { rowContent }.buttonStyle(.plain)` |
| **P1** | `InvoiceDocumentSections.swift:1-1903` | views.md / hygiene.md — extract subviews | 1903-line file; entire invoice renderer in one unit; hot recomposition risk | Split header/line-items/footer into dedicated `View` types + files |
| **P1** | Calendar module (~115 `foregroundColor` hits) e.g. `DayColumnView.swift:66-67`, `TravelChargeView+StandardForm.swift:14+` | api.md — use `foregroundStyle()` | Deprecated API across session editor + week views | Bulk migrate to `.foregroundStyle()` |
| **P1** | `InvoicesViewList.swift:43-59`, `FoldPaperComponents.swift:44` | performance.md — avoid `AnyView` | Type erasure in list context menus hurts diffing/perf | Generic `@ViewBuilder` closure or dedicated context-menu builder struct |
| **P1** | `FoldPaperComponents.swift:296`, `DayColumnView.swift:250,270,302`, `CalendarItemBlockView.swift:337` | swift.md — no GCD | `DispatchQueue.main.async` in views; race with SwiftUI updates | Use `Task { @MainActor in ... }` or `@MainActor` helper |
| **P2** | `DayColumnView.swift:67`, `RevenueAnalyticsSummaryView.swift:65`, `NativeAddressSearchField.swift:275` | api.md — `clipShape(.rect(cornerRadius:))` | `.cornerRadius()` deprecated | Replace with `.clipShape(.rect(cornerRadius:))` |
| **P2** | `ClaimBatchDetailView.swift:33,39`, `AddressEditingSheet.swift:195+` | design.md — no UIKit colors in SwiftUI | `Color(NSColor.*)` bypasses semantic/adaptive styling | Asset catalog semantic colors or `StyleGuide.Colors` |
| **P2** | `TravelChargeAutomationTestView.swift:296-298` | accessibility.md — prefer `Button` | List row tap via gesture; no button traits | Wrap row in `Button { toggle } label: { ... }.buttonStyle(.plain)` |
| **P2** | Settings/Invoices (~20 hits) e.g. `TravelChargeAutomationTestView.swift:260-272`, `ImportExportView+Claims.swift:185+` | design.md — avoid `.caption2` | Extremely small at large Dynamic Type | `.caption` or semantic styles |
| **P2** | `WorkspaceFeatureColumns.swift:168-178`, `CalendarView.swift:60-78`, `InvoicesView.swift:32-37` | data.md — avoid `Binding(get:set:)` in body | Manual bindings harder to trace; re-created each render | Move to `@Bindable` VM properties or small coordinator type |
| **P2** | Status-only color cues e.g. `ImportExportView+Claims.swift:86,98,215` | accessibility.md — differentiate without color | Red/green-only validity; no icon/shape fallback | Add icons/strokes; respect `@Environment(\.accessibilityDifferentiateWithoutColor)` |
| **P3** | `InvoiceDocumentPreview.swift:638` | accessibility.md — `onTapGesture` | Preview tap target; mitigated by `.accessibilityAddTraits(.isButton)` + action | Prefer `Button` with `.buttonStyle(.plain)` for consistency |
| **P3** | `AppMeshBackdrop.swift:40` | api.md — avoid `GeometryReader` | Used for glow layout; fallback path only | Acceptable here; document why |
| **P3** | `ServiceAssignmentSheetView.swift:373`, Clients layouts | design.md — limit `fontWeight()` | Scattered `.fontWeight(.medium)` | Prefer `.bold()` or semantic fonts |
| **P3** | `ClientDetailView.swift:119`, `FoldPaperComponents.swift:85` | views.md — value-driven animation | Some animations omit reduceMotion guard | Gate with `@Environment(\.accessibilityReduceMotion)` |

### PrioritizedFixes (top 3)
1. **Replace `onTapGesture` selection rows with `Button`** — `ServiceAssignmentSheetView`, `TravelChargeAutomationTestView` (P0 accessibility).
2. **Migrate `foregroundColor` → `foregroundStyle` in Calendar + Clients** — highest-volume deprecated API debt.
3. **Split `InvoiceDocumentSections.swift`** — largest perf/maintainability risk in sampled code.

---

## 2. swiftui-ui-patterns (`swiftui-ui-patterns/SKILL.md`)

**SkillCoverage: 69%**

Root wiring and enum-driven presentation in Calendar/Clients are strong patterns. Sheet routing still mixes boolean flags; several screens remain monolithic.

### Strengths
- Per-window scene ownership (`WorkspaceWindowRoot` → `WorkspaceSceneSession`)
- Central navigation (`AppNavigationManager`) with typed deep links + history
- Enum-driven modal state: `CalendarView.ActivePresentation` + `.sheet(item:)` (`CalendarView.swift:51-98`)
- Enum-driven sheets in `ClientDetailView` (`sheet(item: activeSheetBinding)`)
- `@Environment` services + explicit init injection (`CalendarView`, `WorkspaceWindowRoot`)
- Async via `.task` / `.task(id:)` with explicit loading/error UI
- `LazyVStack` + hidden scroll indicators in `FoldPaperContainer` (`scroll-reveal` / scroll-views alignment)

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P1** | `BillableDraftsHomeView.swift:77-79,126` | sheets.md — prefer `sheet(item:)` | Boolean `showGenerateDrafts` + computed `generateDraftsSheet` body | `enum GenerateSheet: Identifiable`; `.sheet(item: $presentedSheet)` |
| **P1** | `ClaimBatchDetailView.swift:17-18,95-99` | Anti-pattern — multiple boolean sheet flags | `showBPRFImport` + `showReconciliation` can overlap | Single `SheetDestination` enum |
| **P1** | `InvoiceEditorInspector.swift` (1391 lines), `InvoiceTemplateRibbon.swift` (1106) | Anti-pattern — giant mixed-responsibility views | Layout + routing + formatting + actions in one file | Feature-local subviews per inspector section |
| **P2** | `PayeeDetailView.swift:126-131`, `PlanManagerDetailView.swift:125-130` | sheets.md — item over isPresented | Duplicate map/address boolean pairs | Shared `DetailSheet` enum + `sheet(item:)` |
| **P2** | `ImportExportView.swift:471-474` | sheets.md — centralized routing | Two independent `isPresented` sheets on one screen | Enum router at feature root |
| **P2** | `BillingHubAddTravelPanel.swift:147-154` | async-state.md — debounce in lifecycle | Seven `onChange` → `Task { refresh }`; no coalescing | Single `.task(id: travelInputFingerprint)` |
| **P2** | `InvoicesViewList.swift:37-59` | Anti-pattern — `AnyView` for composition | Context menu built via type erasure | `@ViewBuilder` menu builder or `@MenuContentBuilder` helper |
| **P2** | `NativeSessionFormLocationSection.swift:43` | sheets.md | Address sheet via `isPresented` | `sheet(item: $editingAddress)` |
| **P2** | `TravelChargeAutomationTestView.swift:110-117` | sheets.md | Two review sheet booleans | One enum case per review mode |
| **P3** | `WorkspaceFeatureColumns.swift:46-82` | app-wiring — keep views thin | Inline `Task` + error handling in column router | Push creation into VM/service; view calls `await features.invoices.createInvoice()` |
| **P3** | `BillingHubView.swift:23-37` | performance.md | Counts derived in view body each pass | Cache in projection or VM when hot |
| **P3** | `BillableDraftsHomeView.swift:85-108` | State ownership — narrow bindings | Manual `Binding(get:set:)` on filter pickers | Expose bindable filter properties on VM |
| **P3** | Missing `#Preview` in several Settings/WorkspaceUI views | previews.md | Harder isolated iteration | Add fixture previews for primary/error states |
| **P3** | `InvoicesView.swift:39-42` | sheets/alerts pattern | `InvoiceDeleteBatch` Identifiable for confirmation — **good** | Replicate this pattern elsewhere |

### PrioritizedFixes (top 3)
1. **Standardize sheet routing to enum + `sheet(item:)`** — start with Settings (`ClaimBatchDetailView`, `ImportExportView`) and BillingHub drafts.
2. **Collapse BillingHub travel `onChange` storm** into one `.task(id:)` input fingerprint.
3. **Break InvoiceTemplateEditor inspector/ribbon** into component-aligned subviews with local previews.

---

## 3. swiftui-view-refactor (`swiftui-view-refactor/SKILL.md`)

**SkillCoverage: 62%**

MV-first direction visible (`@State` VM init in `InvoiceRootView`, `@Bindable` injection). Sampled code still relies heavily on computed `some View` helpers and a few oversized files.

### Strengths
- `@State private var viewModel` init pattern in `InvoiceRootView`, `ClientDetailView`, `WorkspaceWindowRoot`
- `@Bindable` for injected observables (not stored on external owner — documented in `CalendarColumns.swift:7-8`)
- Client detail cards extracted to separate files (`ClientDetailBillingInfoCard`, etc.)
- BillingHub split across many focused files (Kanban, panels, drag-drop)
- Calendar modularized (WeekView, MonthView, session editor sections)
- Stable overlay loading in `BillingHubView` (opacity + overlay, not root swap)

### Findings

| Sev | Location | Rule | Why | Fix |
|-----|----------|------|-----|-----|
| **P1** | `InvoiceDocumentSections.swift` (~1903 lines) | Large-view handling — split >300 lines | Single screen built from inline sections | Extract `InvoiceHeaderSection`, `InvoiceLineItemsSection`, etc. as `View` types |
| **P1** | `InvoiceEditorInspector.swift:202-955` | Prefer dedicated subviews over `private var X: some View` | 10+ section computed properties (`headerSection`, `lineItemsSection`, …) | `private struct HeaderSection: View { ... }` per section |
| **P1** | `InvoiceTemplateRibbon.swift:270-647` | Same | Tab content as computed vars (`templateTab`, `layoutTab`, …) | Dedicated tab view structs |
| **P1** | `BillingHubAddTravelPanel.swift:158-347` | Same | 6 section computed vars in 480-line file | Extract `TravelDetailsSection`, `NDISCalculationSection`, … |
| **P1** | `ClientDetailView.swift:152-199` | Same | 6 card computed vars; cards already partially extracted | Inline cards directly in `body` using extracted structs only |
| **P2** | `WorkspaceWindowRoot.swift:26-37` | Stable view tree — avoid root if/else | `Group { if sceneSession { ContentView } else { Loading } }` causes identity churn | Single shell with `.overlay { if sceneSession == nil { Loading } }` or `.redacted` |
| **P2** | `WorkspaceFeatureColumns.swift:168-178` | Extract side effects from body | `Binding(get:set:)` with navigation side effects inline | Thin `InvoiceSelectionBinding` helper or VM-owned selection |
| **P2** | `WorkspaceFeatureColumns.swift:53-67` | Actions out of body | Inline `Task` + error mapping in `@ViewBuilder content` | `private func createInvoice() async` |
| **P2** | `CalendarViewModel.swift` (~558 lines) | MV over MVVM — VM only when needed | VM holds filtering, bulk ops, EventKit bridge — borderline justified | Incremental extract services; keep VM as coordinator |
| **P2** | `EditingPanel.swift:158-209` | Computed section vars | Cross-feature nav + panel content as computed views | Dedicated `CrossFeatureNavigationSection` struct |
| **P3** | `FoldPaperComponents.swift:6-59` | One type per file (hygiene) | `TreeItem` + `FoldPaperContainer` same file | Split `TreeItem.swift` |
| **P3** | Property ordering inconsistent across views | View ordering guideline | Env/state/init/body/helpers order varies | Normalize during refactors |
| **P3** | `TravelChargeAutomationTestView.swift` (~444 lines) | Large-view handling | Settings debug screen monolith | Split header/session list/results sections |
| **P3** | `InvoicesViewList.swift` — extension on `InvoicesView` | File organization | List logic in extension file OK but mixes concerns | Consider `InvoicesListSection` dedicated view |
| **P3** | `ClientDetailView.swift:134-138` | Side effects in lifecycle | `onAppear { viewModel.dismiss = { ... } }` couples VM to view | Pass dismiss closure via init or environment action |

### PrioritizedFixes (top 3)
1. **Aggressive split of InvoiceTemplateEditor** — `InvoiceDocumentSections`, `InvoiceEditorInspector`, `InvoiceTemplateRibbon` (biggest refactor ROI).
2. **Convert computed section vars → private `View` structs** in BillingHub travel panel + ClientDetailView.
3. **Stabilize `WorkspaceWindowRoot` tree** — avoid root branch swap during session bootstrap.

---

## Cross-Skill Themes

| Theme | Best example | Worst example |
|-------|--------------|---------------|
| Observation / data flow | `AppNavigationManager`, `CalendarColumns` `@Bindable` discipline | Manual `Binding(get:set:)` in columns/filters |
| Navigation | `NavigationSplitView` + typed routes | Boolean sheet pairs in Settings |
| Accessibility | BillingHub panels | `onTapGesture` rows in Clients/Settings |
| Composition | BillingHub file split | InvoiceTemplateEditor monoliths |
| Modern API | `foregroundStyle` in newer BillingHub code | Calendar/Clients `foregroundColor` density |

---

## Module Heat Map (sampled)

| Module | swiftui-pro | ui-patterns | view-refactor | Notes |
|--------|-------------|-------------|---------------|-------|
| AppShell | Good | Good | Fair | Solid shell; minor root-branch + inline Task |
| SharedUI | Fair | Good | Fair | FoldPaper strong; `AnyView` + GCD weak spots |
| BillingHub | **Strong** | Good | Fair | Best accessibility; many computed sections |
| Calendar | Fair | **Strong** | Good | Enum sheets; styling API debt |
| Clients | Fair | Good | Fair | Good sheet enum in ClientDetail; tap gestures |
| Invoices | Good | Good | Good | Reduce motion, delete-batch pattern |
| InvoiceTemplateEditor | **Weak** | **Weak** | **Weak** | Primary refactor target |
| Settings | Fair | Fair | Fair | Boolean sheets, test views monolithic |
| WorkspaceUI | Fair | Fair | Fair | NSColor strings; address field styling debt |

---

Audit read-only. No code changed. Want follow-up scoped to one module (e.g. InvoiceTemplateEditor refactor plan only)?

[REDACTED]