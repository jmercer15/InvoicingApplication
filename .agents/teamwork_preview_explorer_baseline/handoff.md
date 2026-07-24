# Handoff Report — Baseline Investigation

## 1. Observation
I directly observed the following:
- **Build / Test Logs**:
  - The live `run_command` to execute `bash scripts/refactor-verify.sh` timed out waiting for user approval.
  - A pre-existing clean build log in `/Users/user/Developer/InvoicingApplication/InvoicingApplication/scratch_build5.log` (completed on 2026-06-05) ends with:
    ```
    6111: ** BUILD SUCCEEDED **
    ```
- **Raw `.cornerRadius` literals**:
  - `Packages/WorkspaceUI/Sources/WorkspaceUI/NativeAddressSearchField.swift:153`:
    ```swift
    .cornerRadius(8)
    ```
- **Raw `.font(.system)` size and weight literals**:
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Renderer/InvoiceCanvasView.swift:144`:
    ```swift
    .font(.system(size: 12, weight: .bold))
    ```
  - `Packages/SharedUI/Sources/SharedUI/Components/HierarchySectionCard.swift:137`:
    ```swift
    .font(.system(size: 15, weight: .semibold, design: .rounded))
    ```
  - `Packages/WorkspaceUI/Sources/WorkspaceUI/NativeAddressSearchField.swift:120, 125, 130`:
    ```swift
    .font(.system(size: 12))
    .font(.system(size: 14, weight: .medium))
    ```
- **Raw `.animation` durations & spring properties (violating StyleGuide.Animations tokens)**:
  - *Feature.NDIS (marked Done)*:
    - `NDISCatalogueNavigationView.swift:121-122`: `.animation(.easeInOut(duration: 0.25), value: ...)`
    - `NDISDetailCards.swift:36`: `.animation(.easeInOut(duration: 0.4), value: ...)`
    - `NDISDetailCards.swift:75`: `.animation(.spring(response: 0.3, dampingFraction: 0.7), value: ...)`
  - *Feature.Clients (marked Done)*:
    - `ClientDetailBillingInfoCard.swift:78`: `.animation(Animation.spring(response: 0.6, dampingFraction: 0.7), ...)`
    - `ClientDetailClientInformationCard.swift:86`: `.animation(.easeInOut(duration: 0.3), ...)`
  - *Feature.Calendar*:
    - `CalendarTabView.swift:45`: `.animation(.easeInOut(duration: 0.15), value: ...)`
    - `NativeSessionFormLocationSection.swift:19`: `.animation(.spring(response: 0.6, dampingFraction: 0.7), ...)`
  - *Feature.Settings*:
    - `TravelChargeReviewSheet.swift:75`: `.animation(.spring(response: 0.6, dampingFraction: 0.7), ...)`
  - *AppShell*:
    - `SmartInspectorResolverView.swift:80`: `.animation(.easeInOut(duration: 0.2), ...)`
- **Raw `.padding` literals**:
  - `Packages/Feature.Settings/Sources/Feature_Settings/Views/Calendar/RecurrenceSettingsViews.swift:175, 304`: `.padding(.vertical, 2)`
  - `Packages/Feature.Settings/Sources/Feature_Settings/Views/ImportExport/ImportExportView.swift:363`: `.padding(.vertical, 4)`
- **Raw `NSColor` and custom colors**:
  - `Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/BillableDrafts/BillableDraftDetailView.swift:45, 51, 56`:
    ```swift
    .foregroundColor(Color(NSColor.secondaryLabelColor))
    .foregroundColor(Color(NSColor.tertiaryLabelColor))
    .foregroundColor(issue.severity == .blocking ? Color(NSColor.systemRed) : Color(NSColor.systemOrange))
    ```
- **Layout panel shell standardisation gaps**:
  - `Feature.BillingHub`, `Feature.Calendar`, `Feature.Settings`, and `Feature.InvoiceTemplateEditor` do not use `standardContentPanelListInsets()` or `standardPanelContentPadding()`.

## 2. Logic Chain
1. **Goal**: Identify UI design token refresh state and styling violations (R1-R4) across all feature packages.
2. **Step 1 (Colors)**: Grep search for `Color(red:` and `NSColor`. `Color(red:` is only used in helper mappings. However, `NSColor` is directly used in `Feature.BillingHub` and extensively in `Feature.InvoiceTemplateEditor`, violating the standard `ColorSystem` requirements. `Feature.Invoices` is fully migrated.
3. **Step 2 (Paddings/Margins)**: Grep search for `.padding(`. `Feature.Invoices` and `AppShell` are fully migrated. However, `Feature.Settings` and `Feature.InvoiceTemplateEditor` still use raw numeric padding literals like `.padding(.vertical, 2)` and `.padding(4)`.
4. **Step 3 (Corner Radii)**: Grep search for `.cornerRadius`. `WorkspaceUI/NativeAddressSearchField.swift` uses a raw `.cornerRadius(8)` instead of `StyleGuide.Dimensions.cornerRadiusSmall` or similar. Other packages are clean or use `@ScaledMetric` backed by tokens.
5. **Step 4 (Fonts)**: Grep search for `.font(.system`. Direct size/weight literals remain in `Feature.InvoiceTemplateEditor`, `SharedUI`, and `WorkspaceUI`, violating R1.
6. **Step 5 (Animations)**: Grep search for `.animation(`. Found numerous instances of raw duration/spring values (`0.3`, `0.6`, `0.7`) instead of using `StyleGuide.Animations` tokens, even in features marked "Done" (`Feature.NDIS` and `Feature.Clients`).
7. **Step 6 (Panel Shells)**: Grep search for `standardContentPanelListInsets` / `standardPanelContentPadding`. The completed features (`NDIS`, `Clients`, `Invoices`) correctly apply these modifiers. The uncompleted features (`BillingHub`, `Calendar`, `Settings`, `InvoiceTemplateEditor`) still use ad-hoc layout insets/paddings.

## 3. Caveats
- I did not verify runtime behavior because live builds and tests could not be executed due to the `run_command` user approval timeout.
- Assumed `WorkspaceUI` is within the scope of the visual refresh investigation since it is inside the local `Packages` directory and consumed by the features, although not explicitly named in the priority list.

## 4. Conclusion
- **State of Packages**:
  - `Feature.NDIS` & `Feature.Clients`: Mostly done, but have minor `.animation` token gaps (hardcoded durations/springs).
  - `Feature.Invoices`: Fully complete and conforms to the tokens/shells perfectly.
  - `Feature.BillingHub`, `Feature.Calendar`, `Feature.Settings`, `Feature.InvoiceTemplateEditor`: Still have visual styling violations (raw paddings, raw animation values, direct system `NSColor` calls, and lack of panel shell standardisation).
- **Actionable Recommendations**:
  1. Fix the remaining `.animation` literals in `Feature.NDIS` and `Feature.Clients` using the centralized `StyleGuide.Animations` tokens.
  2. Migrate `Feature.BillingHub`'s custom colors to `ColorSystem`.
  3. Migrate `Feature.Calendar`'s custom animations to `StyleGuide.Animations` tokens.
  4. Standardise settings panel/list margins in `Feature.Settings` using `standardContentPanelListInsets()` / `standardPanelContentPadding()`.
  5. Refactor `Feature.InvoiceTemplateEditor`'s large layout engine to replace direct `NSColor` references and raw paddings/margins.

## 5. Verification Method
1. Run the verification script:
   ```bash
   bash scripts/refactor-verify.sh
   ```
2. Verify token rules using the following searches:
   - Zero raw corner radius:
     ```bash
     grep -rn "cornerRadius([0-9]" Packages/Feature.* Packages/AppShell --include="*.swift"
     ```
   - Zero raw font size/weight literals:
     ```bash
     grep -rn ".font(.system(size:" Packages/Feature.* Packages/AppShell --include="*.swift"
     ```
   - Zero raw color/NSColor calls:
     ```bash
     grep -rn "NSColor\." Packages/Feature.* --include="*.swift"
     ```
