# Scope: Sizing Modes in Nested Splits

## Architecture
- Nested split layouts (`LinearSplitView`, `GridSplitView`) inside the invoice template editor.
- Sizing modes (`TableSizingMode` or similar) mapping to flexible, fit, fixed, or shrink.
- Interaction context creation and propagation in canvas views.
- Secondary axis frame sizing and alignment.

## Milestones
| # | Name | Scope | Dependencies | Status | Conversation ID |
|---|------|-------|-------------|--------|-----------------|
| 1 | Exploration | Codebase analysis of split views, layout views, context propagation | none | IN_PROGRESS | b2f683d9-73fb-4cde-9770-7a2e0cf729fd, d2edc7aa-2a83-47e7-a172-b1d36e4abe03, 62db437a-b816-43a6-8d99-8a997c26ee4b |
| 2 | Implementation | Fix context propagation (Bug 1) and secondary sizing resolution (Bug 2) | M1 | PLANNED | |
| 3 | Testing | Add/run automated tests in template editor package | M2 | PLANNED | |
| 4 | Review & Audit | Code review and forensic integrity audit | M3 | PLANNED | |

## Interface Contracts
- Width and height sizing modes must propagate correctly down nested levels.
- Shrunken containers must respect alignment settings and shrink to intrinsic content sizes without stretching.
