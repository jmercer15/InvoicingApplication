# BRIEFING — 2026-06-10T13:00:00+10:00

## Mission
Unify spacing, typography, corner radii, and color choices in the SwiftUI InvoicingApplication codebase using token systems, following the prioritized sequence 1 to 6.

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen3_5605b009
- Original parent: main agent
- Original parent conversation ID: b934de58-d832-4e2a-b100-159fc7657677

## 🔒 My Workflow
- **Pattern**: Project
- **Scope document**: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen3_5605b009/PROJECT.md
1. **Decompose**: Decomposed by feature packages to inspect and clean up token compliance sequentially, then run full verification.
2. **Dispatch & Execute**:
   - **Direct (iteration loop)**: Explorer → Worker → Reviewer → Forensic Auditor → gate.
   - **Delegate (sub-orchestrator)**: N/A (sequential execution in a single orchestrator context is sufficient).
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
- **Current phase**: 3
- **Current focus**: Audit & standardize Feature.Invoices

## 🔒 Key Constraints
- Never write, modify, or create source code files directly.
- Never run build/test commands yourself — require workers to do so.
- Use file-editing tools only for metadata/state files (.md) in your .agents/ folder.
- Never reuse a subagent after it has delivered its handoff — always spawn fresh.

## Current Parent
- Conversation ID: b934de58-d832-4e2a-b100-159fc7657677
- Updated: not yet

## Key Decisions Made
- Resuming work at Milestone 4 (Feature.Invoices) using the state from orchestrator_gen2.

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| explorer_invoices_1 | teamwork_preview_explorer | Audit Invoices compliance | failed | 8b5260d9-ec40-45e5-b44c-dc8730fcadd6 |
| explorer_invoices_2 | teamwork_preview_explorer | Audit Invoices compliance | failed | 4751dbd4-c5e8-48be-8919-c8e4ab7a4d67 |
| explorer_invoices_3 | teamwork_preview_explorer | Audit Invoices compliance | failed | 08b81efe-3b20-4993-b057-71c4a08e8a4a |
| explorer_invoices_3_rep | teamwork_preview_explorer | Audit Invoices compliance | failed | 75d0b6dc-65f8-4f35-a6b3-1050f3cfa952 |
| explorer_invoices_1_gen2 | teamwork_preview_explorer | Audit Invoices dimensions | completed | 8d540dfc-5c2c-491d-872b-c862be775a77 |
| explorer_invoices_2_gen2 | teamwork_preview_explorer | Audit Invoices colors/fonts | completed | e4c12ff5-d682-4d35-bbc4-4f7e020cd78f |
| explorer_invoices_3_gen3 | teamwork_preview_explorer | Audit Invoices components/shells | failed | fb6ac193-fc0e-43e7-9be9-7df69f47536b |
| worker_invoices_1 | teamwork_preview_worker | Implement Invoices token changes | failed | 655e3212-5c11-424c-a2e3-5d48d0c42d78 |
| worker_invoices_2 | teamwork_preview_worker | Implement Invoices token changes | in-progress | 149a5a34-35e5-4d27-a9df-747d62c89c38 |

## Succession Status
- Succession required: no
- Spawn count: 9 / 16
- Pending subagents: [149a5a34-35e5-4d27-a9df-747d62c89c38]
- Predecessor: orchestrator_gen2
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: 5605b009-141e-4813-8e31-fa7d9cf7e707/task-47
- Safety timer: 5605b009-141e-4813-8e31-fa7d9cf7e707/task-59
- On succession: kill all timers before spawning successor
- On context truncation: run `manage_task(Action="list")` — re-create if missing

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen3_5605b009/progress.md — progress tracking
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen3_5605b009/original_prompt.md — copy of original user request
