Skill: swiftui-specialist

Handles broad SwiftUI tasks spanning app structure, navigation, state, layout, and interaction.

## When To Use This Skill
- The task primarily concerns broad SwiftUI tasks spanning app structure, navigation, state, layout, and interaction.
- Multiple concerns inside one domain are active at the same time.
- You need baseline domain guidance before narrowing to a one-to-one specialist.

## Primary References
- Subagent: `.cursor/agents/swiftui-specialist.md`
- Rule: `.cursor/rules/swiftui/application-architecture.mdc`
- Rule: `.cursor/rules/swiftui/view-hierarchy-composition.mdc`
- Rule: `.cursor/rules/swiftui/state-management-data-flow.mdc`
- Rule: `.cursor/rules/swiftui/navigation-presentation.mdc`
- Rule: `.cursor/rules/swiftui/layout-system.mdc`
- Rule: `.cursor/rules/swiftui/visual-components.mdc`

## Likely File Scope
- `InvoicingApplication/App/**/*.swift`
- `InvoicingApplication/App/Scenes/**/*.swift`
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
> You are the broad SwiftUI subagent for this repository.
>
> Use this subagent when a task spans multiple SwiftUI concerns or when the
> correct one-to-one UI specialist is not obvious yet.
>
> Load and follow:
> - `.cursor/rules/swiftui/application-architecture.mdc`
> - `.cursor/rules/swiftui/view-hierarchy-composition.mdc`
> - `.cursor/rules/swiftui/state-management-data-flow.mdc`
> - `.cursor/rules/swiftui/navigation-presentation.mdc`
> - `.cursor/rules/swiftui/layout-system.mdc`
> - `.cursor/rules/swiftui/visual-components.mdc`
>
> Escalate to a one-to-one SwiftUI subagent when the dominant concern becomes
> clear. Pair with `swiftdata-specialist` only when persistence semantics are
> part of the change.
