# Handoff Report — Design-Token Unification and Layout Standardization Analysis

This report documents the findings and gaps in the `Feature.Clients` package (under `Packages/Feature.Clients`) regarding compliance with standard design tokens (`StyleGuide`, `ColorSystem`, `PanelShellTokens`) and layout templates.

---

## 1. Observations

### 1.1 Spacing and Padding Gaps
The following files contain raw numeric spacing or padding values instead of design tokens (`StyleGuide.Dimensions`):

1. **`ClientDetailBillingInfoCard.swift`**
   - **Line 113**: `VStack(alignment: .leading, spacing: 2) {`
2. **`ClientDetailServiceAgreementsCard.swift`**
   - **Line 24**: `VStack(alignment: .leading, spacing: 4) {`
3. **`PlanManagerDetailInformationCard.swift`**
   - **Lines 22, 52, 82, 116**: `VStack(alignment: .leading, spacing: 4) {`
4. **`ServiceAssignmentSheetView.swift`**
   - **Line 52**: `.padding()` (default native padding)
   - **Line 204**: `LazyVStack(spacing: 4) {`
   - **Line 214**: `HStack(spacing: 12) {`
   - **Lines 286, 295, 300**: `VStack(alignment: .trailing, spacing: 2) {`
5. **`ServiceBulkEditorView.swift`**
   - **Lines 76, 115, 136**: `.padding()` (default native padding)
   - **Line 70**: `VStack(alignment: .leading, spacing: 4) {`
   - **Line 82**: `LazyVStack(spacing: 16) {`
   - **Lines 85, 185**: `HStack(alignment: .center, spacing: 16) {` (Line 185 is `HStack(alignment: .top, spacing: 16)`)
6. **`ServiceAssignmentFilterBar.swift`**
   - **Line 23**: `VStack(alignment: .leading, spacing: 8) {`
   - **Line 184**: `HStack(spacing: 4) {`
7. **`RelationshipsDetailColumn.swift`**
   - **Line 114**: `.padding()` (default native padding inside empty state)

*Note on Corner-Radius/Padding Literals:*
- Aside from adjustments like `.padding(.vertical, StyleGuide.Dimensions.paddingXSmall - 1)` in `RelationshipsLayouts.swift` (lines 95 and 276) to tweak cell alignments, there are no raw numeric corner-radius or padding literals (e.g. `.padding(16)` or `.cornerRadius(8)`). All custom corner-radius elements reference `StyleGuide.Dimensions` or standard panel tokens.

### 1.2 Color and Hex Gaps
The following files contain hardcoded bundle asset lookups or system colors instead of dynamic `StyleGuide` / `ColorSystem` tokens:

1. **`ClientDetailBillingInfoCard.swift`**
   - **Lines 19, 23, 41, 61, 84, 89, 108**: `Color("Text", bundle: .sharedUI)`
2. **`ClientDetailClientInformationCard.swift`**
   - **Lines 21, 26, 43, 48, 65, 70, 94, 98, 108, 113, 133, 153**: `Color("Text", bundle: .sharedUI)`
3. **`ClientDetailView.swift`**
   - **Line 91**: `.foregroundColor(Color("Text", bundle: .sharedUI))`
4. **`PlanManagerDetailInformationCard.swift`**
   - **Lines 20, 50, 80, 114**: `Color("Text", bundle: .sharedUI)`
   - **Lines 26, 27, 41, 57, 71, 87, 105, 121, 140**: `Color(NSColor.systemRed)` and `Color(NSColor.systemBlue)` (inline validation color states)
   - **Lines 56, 86, 120**: `Color(NSColor.labelColor)`
   - **Lines 32, 62, 96, 130**: `Color(NSColor.secondaryLabelColor)`
5. **`ServiceAssignmentSheetView.swift`**
   - **Lines 154, 224**: `Color("White", bundle: .sharedUI)`
   - **Lines 164, 227, 292, 297, 302**: `Color("TextSecondary", bundle: .sharedUI)`
   - **Line 246**: `Color("Background", bundle: .sharedUI)`
   - **Line 217**: `.foregroundColor(..., : .white.opacity(0.6))`
6. **`ServiceAssignmentSheetContainer.swift`**
   - **Lines 25, 26, 27**: `Color("Background", bundle: .sharedUI)`
7. **`ServiceBulkEditorView.swift`**
   - **Line 74, 230**: `Color("TextSecondary", bundle: .sharedUI)`
   - **Lines 93, 107**: `Color("Text", bundle: .sharedUI)`
   - **Line 181**: `.foregroundColor(Color.white.opacity(0.1))`
   - **Line 252**: `.stroke(Color.white.opacity(StyleGuide.Opacity.light), lineWidth: 1)`
8. **`ServiceAssignmentFilterBar.swift`**
   - **Line 176**: `.foregroundColor(Color("Cancelled", bundle: .sharedUI))`
   - **Line 197**: `.foregroundColor(Color("White", bundle: .sharedUI))`

### 1.3 Typography and Font Gaps
No raw numeric font-size literals (e.g. `.font(.system(size: 16))`) were found in the views. However, multiple native SwiftUI semantic font styles and modifiers are used instead of `StyleGuide.Typography` tokens:

1. **`ClientDetailBillingInfoCard.swift`**
   - **Line 107**: `.font(.title3.weight(.bold))`
2. **`ClientDetailServiceAgreementsCard.swift`**
   - **Line 26**: `.font(.subheadline)`
   - **Line 29**: `.font(.caption)`
   - **Lines 34, 38, 42, 48**: `.font(.caption2)`
3. **`ClientDetailView.swift`**
   - **Line 222**: `.font(.largeTitle.weight(.regular))`
4. **`PlanManagerDetailInformationCard.swift`**
   - **Lines 42, 72, 106, 141**: `.font(.caption)`
5. **`ServiceAgreementEditorSheet.swift`**
   - **Line 109**: `.font(.caption)`
6. **`ServiceAssignmentSheetView.swift`**
   - **Lines 163, 226**: `.font(.subheadline)`
   - **Line 216**: `.font(.title2)`
   - **Line 222**: `.font(.headline)`
   - **Lines 292, 297, 301, 302**: `.font(.caption)`
7. **`ServiceBulkEditorView.swift`**
   - **Line 72**: `.font(.largeTitle.bold())`
   - **Lines 87, 101**: `.font(.title2.bold())`
   - **Line 231**: `.font(.caption)`
8. **`RelationshipsLayouts.swift`**
   - **Line 100**: `.font(.caption2.weight(.bold))`
   - **Line 124**: `.font(.system(.title3, design: .rounded).weight(.bold))`
   - **Line 136**: `.font(.title3.weight(.bold))`
   - **Lines 140, 284**: `.font(.subheadline)`
   - **Line 146**: `.font(.caption.weight(.medium))`
   - **Line 152**: `.font(.caption.weight(.bold))`
   - **Line 249**: `.font(.body.weight(.medium))`
   - **Lines 255, 301**: `.font(.caption)`
   - **Lines 272, 325**: `.font(.caption2.weight(.medium))`
   - **Line 295**: `.font(.headline)`

### 1.4 Panel Shell Adoption Gaps
The detail screen layout files bypass the layout helpers defined in `PanelShellModifiers.swift`:

1. **`ClientDetailView.swift`** (line 90): Sets `.background(.clear)`. Should adopt `.standardPanelShell(role: .detailPanel)` which also enforces the correct frame sizing.
2. **`PayeeDetailView.swift`** (line 98): Sets `.background(.clear)`. Should adopt `.standardPanelShell(role: .detailPanel)`.
3. **`PlanManagerDetailView.swift`** (line 102): Sets `.background(.clear)`. Should adopt `.standardPanelShell(role: .detailPanel)`.
4. **`RelationshipsDetailColumn.swift`**: Lacks standard background panel treatment, but since it acts as a switcher/container for the three detail views above (which draw their own card columns), the panel shell should be adopted directly by those child views.

---

## 2. Logic Chain

1. **Centralized Definition vs Local Implementation**: The design guidelines state that the `SharedUI` module provides central tokens for colors (`ColorSystem` and `StyleGuide.Colors`), typography (`StyleGuide.Typography`), and dimension spacing (`StyleGuide.Dimensions`).
2. **Analysis of Codebase**: By running search commands and reading views inside `Packages/Feature.Clients`, we verified several places where dynamic asset string colors (like `Color("Text", bundle: .sharedUI)`) or raw NSColor mappings are evaluated inline rather than referencing the compiled tokens.
3. **Inconsistency Verification**: For instance, in `ClientDetailBillingInfoCard.swift`, line 135 uses `StyleGuide.Dimensions.paddingXXSmall` for stack spacing, while line 113 uses raw `spacing: 2`. This demonstrates inconsistent token adoption within the exact same component files.
4. **Layout Wrapper Absence**: Checking the navigation bar structures, headers, and container views in `ClientDetailView`, `PayeeDetailView`, and `PlanManagerDetailView` confirmed they currently rely on `.background(.clear)` and structural parent containers rather than using `.standardPanelShell(role:)` and `.standardPanelContentPadding()`.
5. **Conclusion Formulation**: These observations point to explicit, actionable lines where spacing, colors, fonts, and panel modifiers must be substituted.

---

## 3. Caveats

- **Scope Limit**: As an explorer agent, I performed no code execution or replacement tasks. All changes are proposals.
- **Dynamic Assets**: Some components use specific colors like `Color.clientDefault` or `Color.payeeDefault`. These are defined as extension properties in `SharedUI` and map to localized assets, which is a correct and unified architectural choice.
- **Vertical vs Horizontal Form Components**:
  - The shared `FormField` component places the text label *vertically above* the input field. This is adopted correctly in vertical editor layouts (e.g. `ServiceBulkEditorView.swift`).
  - In detail cards (e.g. `PlanManagerDetailInformationCard.swift`), forms are structured as horizontal `HStack` rows aligning the label to a fixed left width and the input to the right. This layout is incompatible with `FormField`'s vertical design. Therefore, they should continue to use `HStack` layouts but must be refactored to use standard color and typography tokens.
- **Sheets Layouts**: Modal sheets (e.g. `ServiceAssignmentSheetView` and `ServiceAgreementEditorSheet`) typically implement standard margins using `.padding()` without an explicit panel shell. These might not require `standardPanelShell` (which is meant for split-view layout columns), but their inner spacing should still align with `StyleGuide.Dimensions` and typography tokens.

---

## 4. Conclusion

The `Feature.Clients` package features partial adoption of design tokens. Newly created components (such as rows and cards in `PayeeDetailInformationCard.swift`) are highly compliant, but legacy views (such as `PlanManagerDetailInformationCard.swift`, `ClientDetailBillingInfoCard.swift`, and bulk sheets) retain raw metrics, asset colors, and standard font calls.

### 4.1 Shared Components Adoption Analysis
- **`StatusBadge`**: Fully adopted in entity status rows and toolbar headers. No custom badge implementations exist.
- **`EnhancedGroupBoxStyle`**: 100% adopted on all Detail Card groups across all detail views.
- **`FormField`**: Used in `ServiceBulkEditorView.swift`.
  - *Recommendation*: Adopt `FormField` in `ServiceAgreementEditorSheet.swift` (which is a vertical sheet layout).
  - *Detail Cards*: Maintain `HStack` row structures due to horizontal layout constraints, but replace raw color/font parameters.
- **`SidebarItemRow`**: Not adopted. The left/master columns in this package use custom, interactive tinted group cards (`RelationshipGroupCard` and `RelationshipCard`) in a adaptive grid layout rather than standard sidebar tree items. This matches the custom layouts required by client relationships.

### 4.2 Recommendations and Code Patterns

#### A. Spacing & Padding Standardization
- Replace raw literal values with StyleGuide equivalents:
  - `spacing: 2` $\rightarrow$ `spacing: StyleGuide.Dimensions.paddingXXSmall` (2.0)
  - `spacing: 4` $\rightarrow$ `spacing: StyleGuide.Dimensions.paddingXSmall` (4.0)
  - `spacing: 8` $\rightarrow$ `spacing: StyleGuide.Dimensions.paddingMedium` (8.0)
  - `spacing: 12` $\rightarrow$ `spacing: StyleGuide.Dimensions.paddingMediumLarge` (12.0)
  - `spacing: 16` $\rightarrow$ `spacing: StyleGuide.Dimensions.paddingLarge` (16.0)
  - `.padding()` $\rightarrow$ `.padding(StyleGuide.Dimensions.paddingMedium)` or `.standardPanelContentPadding()` for main panel frames.

*Example (Bulk Editor spacing change):*
```swift
// BEFORE (ServiceBulkEditorView.swift:70)
VStack(alignment: .leading, spacing: 4) {

// AFTER
VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
```

#### B. Color System Standardization
- Replace string asset lookups and system colors with tokens:
  - `Color("Text", bundle: .sharedUI)` $\rightarrow$ `StyleGuide.Colors.text`
  - `Color("TextSecondary", bundle: .sharedUI)` $\rightarrow$ `StyleGuide.Colors.textSecondary`
  - `Color("Background", bundle: .sharedUI)` $\rightarrow$ `StyleGuide.Colors.background`
  - `Color(NSColor.systemRed)` $\rightarrow$ `ColorSystem.Status.error`
  - `Color(NSColor.systemBlue)` $\rightarrow$ `ColorSystem.Status.info`
  - `Color(NSColor.secondaryLabelColor)` $\rightarrow$ `StyleGuide.Colors.textSecondary`
  - `Color(NSColor.labelColor)` $\rightarrow$ `StyleGuide.Colors.text`
  - `Color.white` or `.white` (used as background elements) $\rightarrow$ `StyleGuide.Colors.white` or `ColorSystem.Neutral.white`.

*Example (Plan Manager detail text change):*
```swift
// BEFORE (PlanManagerDetailInformationCard.swift:20)
Text("Name:")
    .foregroundColor(Color("Text", bundle: .sharedUI))

// AFTER
Text("Name:")
    .foregroundColor(StyleGuide.Colors.text)
```

#### C. Typography Standardization
- Map semantic fonts to typography design tokens:
  - `.font(.largeTitle)` $\rightarrow$ `.font(StyleGuide.Typography.hero)`
  - `.font(.title2)` $\rightarrow$ `.font(StyleGuide.Typography.sectionTitle)`
  - `.font(.title3)` $\rightarrow$ `.font(StyleGuide.Typography.itemTitle)`
  - `.font(.headline)` $\rightarrow$ `.font(StyleGuide.Typography.itemTitle)`
  - `.font(.subheadline)` $\rightarrow$ `.font(StyleGuide.Typography.itemSubtitle)`
  - `.font(.caption)` $\rightarrow$ `.font(StyleGuide.Typography.caption)`
  - `.font(.caption2)` $\rightarrow$ `.font(StyleGuide.Typography.micro)`

*Example (Caption font change):*
```swift
// BEFORE (ServiceAgreementEditorSheet.swift:109)
Text(error)
    .font(.caption)

// AFTER
Text(error)
    .font(StyleGuide.Typography.caption)
```

#### D. Panel Shell Adaptation
- Apply standard panel wrappers to column screens:

*Example (ClientDetailView panel standardization):*
```swift
// BEFORE (ClientDetailView.swift:89-90)
.frame(maxWidth: .infinity, maxHeight: .infinity)
.background(.clear)

// AFTER
.standardPanelShell(role: .detailPanel)
```

---

## 5. Verification Method

To verify these issues and confirm the gaps:
1. Run target scans:
   - Check raw color references: `grep -rn "Color(\"Text" Packages/Feature.Clients`
   - Check raw font references: `grep -rn "\.font(\.[a-zA-Z]*)" Packages/Feature.Clients`
   - Check layout panel background calls: `grep -rn "\.background(\.clear)" Packages/Feature.Clients`
2. Validate compiler integrity by building the `Feature_Clients` target before and after refactoring:
   ```bash
   swift build --package-path Packages/Feature.Clients
   ```
3. Run the existing tests to ensure layout structural updates do not break functionality:
   ```bash
   swift test --package-path Packages/Feature.Clients
   ```
