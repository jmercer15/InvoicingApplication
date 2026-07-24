# BRIEFING — 2026-06-15T09:38:00+10:00

## Mission
Clean up custom non-native styling in Feature.Invoices views, restoring macOS native UI behaviors.

## 🔒 My Identity
- Archetype: worker_invoices_cleanup
- Roles: implementer, qa, specialist
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_cleanup
- Original parent: bed756d0-0480-4f5d-a410-79dbdf864303
- Milestone: Invoices styling cleanup

## 🔒 Key Constraints
- Avoid non-native hover states, custom highlights, and manual opacity transitions.
- Restore standard native macOS buttons/modifiers.
- No cheating, no dummy implementations.

## Current Parent
- Conversation ID: bed756d0-0480-4f5d-a410-79dbdf864303
- Updated: not yet

## Task Summary
- **What to build**:
  - Remove `isHovered`/`onHover` logic from `InvoiceFilterPopoverContent.swift`. Use flat/constant background and overlay colors.
  - Remove hover state/modifiers from "Add Line Item", edit, and delete buttons in `InvoiceLineItemsSection.swift`. Use flat/constant colors.
  - Remove custom plain buttons and `onHover` from multi-select action toolbar in `InvoicesView.swift`. Use native button styles and tints (e.g. `.buttonStyle(.bordered)`, `.borderedProminent`, `.tint`).
- **Success criteria**: Code compiles with zero warnings/errors, tests pass, visual styles follow native macOS look-and-feel.
- **Interface contracts**: Feature.Invoices target.
- **Code layout**: Packages/Feature.Invoices/Sources/Feature_Invoices/Views/

## Key Decisions Made
- Removed custom hover states (isHovered, isAddHovered, hoveredButton, hoveredButtonId) to eliminate non-native UI behavior.
- Replaced custom background/border hover transitions with flat colors and native macOS button styles (e.g. .buttonStyle(.bordered), .buttonStyle(.borderedProminent), .tint).

## Artifact Index
- Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift — popover content filtering buttons styling cleanup
- Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift — line items list and inline action buttons styling cleanup
- Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift — bottom action toolbar buttons styling cleanup

