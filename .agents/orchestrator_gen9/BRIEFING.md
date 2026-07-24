# BRIEFING — 2026-06-11T11:03:06+10:00

## Mission
Complete visual design token standardization and verification across Feature.Invoices, Feature.BillingHub/Calendar, Feature.Settings/InvoiceTemplateEditor, and AppShell.

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen9
- Original parent: main agent
- Original parent conversation ID: b934de58-d832-4e2a-b100-159fc7657677

## 🔒 My Workflow
- **Pattern**: Project
- **Scope document**: /Users/user/Developer/InvoicingApplication/InvoicingApplication/PROJECT.md
1. **Decompose**: Decomposed by feature packages to inspect and clean up token compliance sequentially, then run full verification.
2. **Dispatch & Execute**:
   - **Direct (iteration loop)**: Explorer -> Worker -> Reviewer -> Forensic Auditor -> gate.
   - **Delegate (sub-orchestrator)**: N/A (single conversation context sufficient for sequential passes).
3. **On failure** (in this order):
   - Retry: nudge stuck agent or re-send task
   - Replace: spawn fresh agent with partial progress
   - Skip: proceed without (only if non-critical)
   - Redistribute: split stuck agent's remaining work
   - Redesign: re-partition decomposition
   - Escalate: report to parent (sub-orchestrators only, last resort)
4. **Succession**: Self-succeed at 16 spawns, write handoff.md, spawn successor.
- **Work items**:
  1. Initialize and run baseline verification [done]
  2. Audit & standardize Feature.NDIS [done]
  3. Audit & standardize Feature.Clients [done]
  4. Audit & standardize Feature.Invoices [in-progress]
  5. Audit & standardize Feature.BillingHub & Feature.Calendar [pending]
  6. Audit & standardize Feature.Settings & Feature.InvoiceTemplateEditor [pending]
  7. Audit & standardize AppShell [pending]
  8. Final verification and report [pending]
- **Current phase**: 2B (Iteration Loop for Feature.Invoices)
- **Current focus**: Feature.Invoices

## 🔒 Key Constraints
- Never write, modify, or create source code files directly.
- Never run build/test commands yourself — require workers to do so.
- You MAY use file-editing tools ONLY for metadata/state files (.md) in your .agents/ folder.
- Never reuse a subagent after it has delivered its handoff — always spawn fresh

## Current Parent
- Conversation ID: b934de58-d832-4e2a-b100-159fc7657677
- Updated: not yet

## Key Decisions Made
- Resuming execution starting with Feature.Invoices token unification and verification.

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| explorer_invoices_1 | teamwork_preview_explorer | Style token violations in Invoices | completed | 6ccd9566-f3ae-49ec-9bc1-55d8cf7f6a58 |
| explorer_invoices_2 | teamwork_preview_explorer | Layout & panel issues in Invoices | completed | 2f72d630-080d-426a-b02e-e3db2cf21743 |
| explorer_invoices_3 | teamwork_preview_explorer | Typography & components in Invoices | completed | 12e0144c-72fd-4e58-9c8d-529ff24597d7 |
| worker_invoices_1 | teamwork_preview_worker | Migrate & implement Invoices tokens | in-progress | c1e62ba9-7ac1-4797-a78d-1ddf830ccb5f |

## Succession Status
- Succession required: no
- Spawn count: 16 / 16
- Pending subagents: c1e62ba9-7ac1-4797-a78d-1ddf830ccb5f
- Predecessor: orchestrator_gen8
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: task-33
- Safety timer: none
- On succession: kill all timers before spawning successor
- On context truncation: run `manage_task(Action="list")` — re-create if missing

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen9/progress.md — progress tracking
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen9/original_prompt.md — copy of original user request
