## 2026-06-12T15:47:14Z

You are the Explorer agent for Milestone 3 (Feature.Clients UI Refinement).
Your working directory is: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_clients_m3/

OBJECTIVE:
Analyze all SwiftUI views under `Packages/Feature.Clients/Sources/Feature_Clients/Views/` and find UI gaps across four specific UI Refinement (Pass 3) criteria:
1. Component Elevation & Visual Hierarchy:
   - Identify uses of raw backgrounds/borders on cards/sections that should use SharedUI's `.standardCardStyle()`, `standardSectionStyle()`, or HierarchySectionCard.
   - Look for card headers or view section titles that should use `.formSectionTitleStyle()` or HierarchyHeaderStyle.
   - Inspect custom lists or grid rows to see if they should be refactored or standardized using SharedUI's navigation list rows.
2. Empty, Error, and Loading State Polish:
   - Search for lists, details, or dynamic states that lack standard loading indicators (like `LoadingView` or `.loadingOverlay`).
   - Check if there are empty lists or blank states that should be using `EmptyStateView` with a nice icon, message, and action.
   - Check if error states are friendly and readable.
3. Visual Feedback & Interactive Affordances:
   - Find interactive items, buttons, rows, or list elements that lack pressed/hover states or hover scaling/highlight animations.
   - Verify selection highlights exist.
4. Accessibility & Contrast:
   - Check if interactive elements (like buttons with just icons or custom clickable rows) are missing `.accessibilityLabel(_:)` or `.accessibilityHint(_:)`.
   - Identify hardcoded colors that might violate WCAG AA contrast ratios, or verify that we use the standardized `ColorSystem`.

OUTPUT REQUIREMENTS:
- Write a structured gap analysis report named `analysis.md` in `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_clients_m3/`.
- The report must catalogue:
  - Specific files and lines where gaps exist.
  - The type of gap (Visual Hierarchy, State Polish, Interactive Feedback, Accessibility).
  - Recommended fix/refactoring strategy utilizing SharedUI's standardized tokens/components.
- Write handoff.md in your working directory and notify the parent orchestrator via send_message.
