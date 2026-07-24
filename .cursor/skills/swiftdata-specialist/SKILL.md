Skill: swiftdata-specialist

Handles broad SwiftData tasks spanning storage, models, queries, lifecycle, concurrency, and sync.

## When To Use This Skill

- The task primarily concerns broad SwiftData tasks spanning storage, models, queries, lifecycle, concurrency, and sync.
- Multiple concerns inside one domain are active at the same time.
- You need baseline domain guidance before narrowing to a one-to-one specialist.

## Primary References

- Subagent: `.cursor/agents/swiftdata-specialist.md`
- Rule: `.cursor/rules/swiftdata/storage-infrastructure.mdc`
- Rule: `.cursor/rules/swiftdata/model-definition.mdc`
- Rule: `.cursor/rules/swiftdata/relationships.mdc`
- Rule: `.cursor/rules/swiftdata/query-system.mdc`
- Rule: `.cursor/rules/swiftdata/persistence-lifecycle.mdc`
- Rule: `.cursor/rules/swiftdata/concurrency-model.mdc`

## Likely File Scope

- `Packages/Data/Sources/Data/Persistence/**/*.swift`
- `Packages/Data/Sources/Data/Actors/**/*.swift`
- `InvoicingApplication/App/Composition/AppWorkspaceBootstrap.swift`
- `InvoicingApplication/App/Composition/**/*.swift`

## Workflow

1. Load the baseline rules listed in the subagent brief and identify the dominant concern in the requested change.
2. Narrow to one focused one-to-one skill as soon as the main concern becomes clear.
3. Keep only the baseline rules that still materially constrain the change.
4. Add a cross-domain pairing only when the change truly crosses architecture or persistence boundaries.
5. End with the smallest rule and skill set that still explains the task correctly.

## Validation Checklist

- The dominant concern inside the domain is named.
- Any one-to-one follow-on skill is identified when appropriate.
- Cross-domain pairings are explicit rather than implied.
- The remaining baseline rules still matter to the task.

## Expected Output

- Dominant concern within the specialist domain
- One-to-one skill to narrow to next, if applicable
- Baseline rules that remain in scope
- Cross-domain pairing that must be preserved, if any

## Current Subagent Brief

> You are the broad SwiftData subagent for this repository.
>
> Use this subagent when a task spans multiple persistence concerns or when the
> correct one-to-one data specialist is not obvious yet.
>
> Load and follow:
>
> - `.cursor/rules/swiftdata/storage-infrastructure.mdc`
> - `.cursor/rules/swiftdata/model-definition.mdc`
> - `.cursor/rules/swiftdata/relationships.mdc`
> - `.cursor/rules/swiftdata/query-system.mdc`
> - `.cursor/rules/swiftdata/persistence-lifecycle.mdc`
> - `.cursor/rules/swiftdata/concurrency-model.mdc`
>
> Escalate to a one-to-one SwiftData subagent when the dominant concern becomes
> clear. Pair with `swiftui-specialist` when the change alters user-facing flow or
> UI state semantics.
