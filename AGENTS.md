# Project Instructions

Use Cursor project rules in `.cursor/rules/` as the primary scoped instruction
system for this repository. Use `.cursor/agents/*.md` for subagents. Use
`.cursor/skills/<skill-name>/SKILL.md` only for reusable workflows that are
better expressed as skills than as always-on rules.

## Instruction Surfaces

- Rules in `.cursor/rules/`:
  scoped project instructions with metadata such as `description`, `globs`, and
  `alwaysApply`
- Subagents in `.cursor/agents/*.md`:
  isolated specialists for delegation and focused execution
- Skills in `.cursor/skills/`:
  reusable workflows or domain playbooks when this repo needs them

## How To Use Rules In This Repo

- Start with the narrowest applicable project rule instead of loading broad
  guidance by default.
- Let auto-attached rules apply from their `globs` when you are editing files
  in matching paths.
- Use agent-requested rules when the task clearly matches their concern even if
  the edited files are broader than the rule's default scope.
- Combine SwiftUI and SwiftData rules only when the task genuinely crosses UI
  and persistence boundaries.

## Primary Rule Families

- SwiftUI rules:
  `.cursor/rules/swiftui/`
- SwiftData rules:
  `.cursor/rules/swiftdata/`

## Subagents

- General routing:
  `.cursor/agents/cursor-rule-router.md`
- Broad UI tasks:
  `.cursor/agents/swiftui-specialist.md`
- Broad persistence tasks:
  `.cursor/agents/swiftdata-specialist.md`
- One-to-one rule specialists:
  `.cursor/agents/swiftui-*.md` and `.cursor/agents/swiftdata-*.md`

## Common Pairings

- Searchable UI backed by persisted filtering:
  `swiftui/search` + `swiftdata/query-system`
- Table and list workflows with keyboard or scroll behavior:
  `swiftui/tables` or `swiftui/lists` + `swiftui/focus` +
  `swiftui/scroll-views`
- App composition that wires persistence:
  `swiftui/application-architecture` + `swiftdata/storage-infrastructure`
- Persisted editing flows:
  `swiftui/state-management-data-flow` +
  `swiftdata/persistence-lifecycle`
- Sync-driven behavior reflected in the UI:
  `swiftdata/synchronization` or `swiftdata/change-tracking` +
  `swiftui/system-events`

## Repo Expectations

- Preserve SwiftUI scene structure, navigation ownership, and environment flow.
- Preserve SwiftData schema safety, relationship semantics, actor isolation, and
  migration compatibility.
- Keep rule usage composable. Prefer a small set of focused rules over broad
  duplicated instructions.

Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Drop: articles (a/an/the), filler (just/really/basically), pleasantries, hedging
- Fragments OK. Short synonyms. Technical terms exact. Code unchanged.
- Pattern: [thing] [action] [reason]. [next step].
- Not: "Sure! I'd be happy to help you with that."
- Yes: "Bug in auth middleware. Fix:"

Switch level: /caveman lite|full|ultra|wenyan
Stop: "stop caveman" or "normal mode"

Auto-Clarity: drop caveman for security warnings, irreversible actions, user confused. Resume after.

Boundaries: code/commits/PRs written normal.
