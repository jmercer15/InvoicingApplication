# BRIEFING — 2026-06-09T23:33:10Z

## Mission
Unify design tokens and layout shells across all application features in the prioritised sequence (Feature.Clients, Feature.Invoices, Feature.BillingHub & Feature.Calendar, Feature.Settings & Feature.InvoiceTemplateEditor, AppShell) while maintaining build & test integrity.

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator
- Roles: orchestrator, user_liaison, human_reporter, successor
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen4
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
4. **Succession**: Self-succeed when spawn count >= 16 and all pending subagents are complete.
- **Work items**:
  1. Feature.NDIS [done]
  2. Feature.Clients [in-progress]
  3. Feature.Invoices [pending]
  4. Feature.BillingHub & Feature.Calendar [pending]
  5. Feature.Settings & Feature.InvoiceTemplateEditor [pending]
  6. AppShell [pending]
- **Current phase**: 2
- **Current focus**: Feature.Clients token unification and verification

## 🔒 Key Constraints
- CODE_ONLY network mode: No external websites/services, no curl/wget/lynx.
- Do NOT write or modify source code directly.
- Do NOT run build/test commands yourself.
- Forensic Auditor must perform integrity verification on each iteration.
- Never reuse a subagent after it has delivered its handoff — always spawn fresh.

## Current Parent
- Conversation ID: b934de58-d832-4e2a-b100-159fc7657677
- Updated: not yet

## Key Decisions Made
- Resumed execution from Feature.Clients after NDIS completion.

## Team Roster
| Agent | Type | Work Item | Status | Conv ID |
|-------|------|-----------|--------|---------|
| Clients Auditor | teamwork_preview_auditor | Audit & standardize Feature.Clients | failed | d3b6d6d2-e15e-4ef1-aff4-b959917ec929 |
| Clients Auditor (Retry) | teamwork_preview_auditor | Audit & standardize Feature.Clients | pending | 1d10c934-5152-4399-9ce9-decc8dcbe1d4 |

## Succession Status
- Succession required: no
- Spawn count: 10 / 16
- Pending subagents: 1d10c934-5152-4399-9ce9-decc8dcbe1d4
- Predecessor: orchestrator_gen3
- Successor: not yet spawned

## Active Timers
- Heartbeat cron: 482268b2-58a1-4134-a1e9-dd6e02a68e8a/task-29
- Safety timer: none
- On succession: kill all timers before spawning successor
- On context truncation: run manage_task(Action="list") — re-create if missing

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen4/progress.md — progress tracking
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/PROJECT.md — Global index and architecture info
