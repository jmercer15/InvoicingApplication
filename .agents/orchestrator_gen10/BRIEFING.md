# BRIEFING — 2026-06-11T13:19:06+10:00

## Mission
Complete UI design-token standardization across Feature.Invoices, Feature.BillingHub/Calendar, Feature.Settings/InvoiceTemplateEditor, AppShell (gen10 resumes from Feature.Invoices).

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator (self)
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen10
- Original parent: main agent (sentinel)
- Original parent conversation ID: 475d36b4-1401-4bf3-9e33-479802e6b780

## 🔒 My Workflow
- **Pattern**: Project (iteration loop)
- **Scope document**: /Users/user/Developer/InvoicingApplication/InvoicingApplication/PROJECT.md
1. **Decompose**: By feature package sequentially: Invoices → BillingHub+Calendar → Settings+InvoiceTemplateEditor → AppShell
2. **Dispatch & Execute**:
   - **Direct (iteration loop)**: Worker → Reviewer → gate (Invoices explorer already done)
   - **Delegate (sub-orchestrator)**: N/A
3. **On failure** (in this order):
   - Retry: nudge stuck agent or re-send task
   - Replace: spawn fresh agent with partial progress
   - Skip: proceed without (only if non-critical)
   - Redistribute: split stuck agent's remaining work
   - Redesign: re-partition decomposition
   - Escalate: report to parent (last resort)
4. **Succession**: Self-succeed at 16 spawns, write handoff.md, spawn successor (orchestrator_gen11)
- **Work items**:
  1. Feature.NDIS [done — prior gens]
  2. Feature.Clients [done — prior gens]
  3. Feature.Invoices [in-progress]
  4. Feature.BillingHub & Feature.Calendar [pending]
  5. Feature.Settings & Feature.InvoiceTemplateEditor [pending]
  6. AppShell [pending]
  7. Final verification [pending]
- **Current phase**: 2B (Iteration Loop)
- **Current focus**: Feature.Invoices — Worker phase

## 🔒 Key Constraints
- Never write, modify, or create source code files directly
- Never run build/test commands yourself — require workers to do so
- You MAY use file-editing tools ONLY for metadata/state files (.md) in your .agents/ folder
- Never reuse a subagent after it has delivered its handoff — always spawn fresh
- DO NOT redo NDIS or Clients work (already done)
- worker_invoices_gen9 is stale — spawn fresh worker

## Current Parent
- Conversation ID: 475d36b4-1401-4bf3-9e33-479802e6b780
- Updated: 2026-06-11T13:19:06+10:00

## Key Decisions Made
- Skip Feature.Invoices explorer (complete at explorer_invoices_3_3/handoff.md)
- Spawn fresh worker for Feature.Invoices (gen9 worker stalled before build/test)
- gen9 worker made partial changes to InvoicesView.swift, InvoiceInspectorFormView.swift, container panels

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| worker_invoices_gen10 | teamwork_preview_worker | Invoices build verify + BillingHub/Calendar audit+migrate | in-progress | 6da5af57-962a-4e5a-826a-79ef70c5f200 |

## Succession Status
- Succession required: no
- Spawn count: 1 / 16
- Pending subagents: none
- Predecessor: orchestrator_gen9
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: not started
- Safety timer: none

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen10/BRIEFING.md — this file
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen10/progress.md — progress tracking
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_invoices_3_3/handoff.md — Invoices issue analysis
