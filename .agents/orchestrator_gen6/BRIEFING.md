# BRIEFING — 2026-06-10T17:35:00+10:00

## Mission
Unify spacing, typography, corner radii, and color choices in the SwiftUI InvoicingApplication codebase using token systems, following the prioritized sequence 1 to 6.

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen6
- Original parent: main agent
- Original parent conversation ID: b934de58-d832-4e2a-b100-159fc7657677

## 🔒 My Workflow
- **Pattern**: Project
- **Scope document**: /Users/user/Developer/InvoicingApplication/InvoicingApplication/PROJECT.md
1. **Decompose**: Decomposed by feature packages to inspect and clean up token compliance sequentially, then run full verification.
2. **Dispatch & Execute**:
   - **Direct (iteration loop)**: Explorer → Worker → Reviewer → Forensic Auditor → gate.
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
  4. Audit & standardize Feature.Invoices [pending]
  5. Audit & standardize Feature.BillingHub & Feature.Calendar [pending]
  6. Audit & standardize Feature.Settings & Feature.InvoiceTemplateEditor [pending]
  7. Audit & standardize AppShell [pending]
  8. Final verification and report [pending]
- **Current phase**: 2B (Iteration Loop for Feature.Invoices)
- **Current focus**: Feature.Invoices

## 🔒 Key Constraints
- Never write, modify, or create source code files directly.
- Never run build/test commands yourself — require workers to do so.
- Use file-editing tools only for metadata/state files (.md) in your .agents/ folder.
- Never reuse a subagent after it has delivered its handoff — always spawn fresh.

## Current Parent
- Conversation ID: b934de58-d832-4e2a-b100-159fc7657677
- Updated: not yet

## Key Decisions Made
- Resuming work from Feature.Invoices token unification using a fresh worker (worker_invoices_gen6_1) armed with the findings of explorer_invoices_3_3.

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| worker_invoices_gen6_1 | teamwork_preview_worker | Migrate Feature.Invoices design tokens | failed | b0e5d8ce-3546-4a10-8b8f-3cdd3b60321d |
| worker_invoices_gen6_2 | teamwork_preview_worker | Migrate Feature.Invoices design tokens | failed | 87bee485-d414-48f9-8d33-efcca2922f66 |
| worker_invoices_gen6_3 | teamwork_preview_worker | Migrate Feature.Invoices design tokens | failed | 6e894d37-020a-4f64-9fe0-1488e8ef71d6 |
| worker_invoices_gen6_4 | teamwork_preview_worker | Migrate Feature.Invoices design tokens | in-progress | 25e7b02e-f579-447a-b2c0-add2eb0d4e91 |
| reviewer_invoices_gen6_1 | teamwork_preview_reviewer | Verify Feature.Invoices design tokens | in-progress | 14c43e60-ff8d-4fa1-9ecb-860f077aa136 |

## Succession Status
- Succession required: no
- Spawn count: 5 / 16
- Pending subagents: 25e7b02e-f579-447a-b2c0-add2eb0d4e91, 14c43e60-ff8d-4fa1-9ecb-860f077aa136
- Predecessor: orchestrator_gen5
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: task-25
- Safety timer: task-77
- On succession: kill all timers before spawning successor
- On context truncation: run manage_task(Action="list") — re-create if missing

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen6/progress.md — progress tracking
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen6/original_prompt.md — copy of original user request
