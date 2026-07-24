# BRIEFING — 2026-06-10T13:00:21+10:00

## Mission
Standardise the UI design throughout all of the application's features (Invoices, Calendar, Billing Hub, Settings, Invoice Template Editor, AppShell). Unify spacing, typography, corner radii, and color choices.

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen5
- Original parent: main agent
- Original parent conversation ID: b934de58-d832-4e2a-b100-159fc7657677

## 🔒 My Workflow
- **Pattern**: Project Pattern
- **Scope document**: /Users/user/Developer/InvoicingApplication/InvoicingApplication/PROJECT.md
1. **Decompose**:
   - Decomposed by package boundary into sequential milestones.
2. **Dispatch & Execute**:
   - **Direct (iteration loop)**: Explorer → Worker → Reviewer → Challenger → Auditor → gate
   - **Delegate (sub-orchestrator)**: Spawn a sub-orchestrator for each milestone.
3. **On failure** (in this order):
   - Retry: nudge stuck agent or re-send task
   - Replace: spawn fresh agent with partial progress
   - Skip: proceed without (only if non-critical)
   - Redistribute: split stuck agent's remaining work
   - Redesign: re-partition decomposition
   - Escalate: report to parent (sub-orchestrators only, last resort)
4. **Succession**:
   - When cumulative spawn count reaches 16 and all subagents are complete, write handoff.md, spawn successor, and exit.
- **Work items**:
  1. Feature.Invoices [pending]
  2. Feature.BillingHub & Feature.Calendar [pending]
  3. Feature.Settings & Feature.InvoiceTemplateEditor [pending]
  4. AppShell [pending]
  5. Final Assembly & E2E verification [pending]
- **Current phase**: 2B (Iteration Loop for Feature.Invoices)
- **Current focus**: Feature.Invoices

## 🔒 Key Constraints
- Never reuse a subagent after it has delivered its handoff — always spawn fresh
- Hard veto on forensic audit failure

## Current Parent
- Conversation ID: b934de58-d832-4e2a-b100-159fc7657677
- Updated: not yet

## Key Decisions Made
- Resuming work from Feature.Invoices token unification.

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| worker_invoices_1 | teamwork_preview_worker | Migrate Feature.Invoices design tokens | failed | b893b727-040c-4bec-aacb-1e322f2831b6 |
| worker_invoices_2 | teamwork_preview_worker | Migrate Feature.Invoices design tokens | failed | 997fae3d-a217-4d86-8e0a-402f7678bbb2 |
| worker_invoices_3 | teamwork_preview_worker | Migrate Feature.Invoices design tokens | failed | feb977c0-73bc-48e6-8c2b-940b99666ea1 |
| worker_invoices_4 | teamwork_preview_worker | Migrate Feature.Invoices design tokens | in-progress | 2b9876af-6776-4eb6-9494-a30306a5cf8c |

## Succession Status
- Succession required: no
- Spawn count: 10 / 16
- Pending subagents: 2b9876af-6776-4eb6-9494-a30306a5cf8c
- Predecessor: orchestrator_gen4
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: task-21
- Safety timer: task-155
- On succession: kill all timers before spawning successor
- On context truncation: run `manage_task(Action="list")` — re-create if missing

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/PROJECT.md — Global project plan and status
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen5/progress.md — Internal heartbeat progress
