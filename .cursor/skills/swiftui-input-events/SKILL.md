Skill: swiftui-input-events

Handles SwiftUI keyboard, hover, command, and hardware input events.

## When To Use This Skill
- The task primarily concerns SwiftUI keyboard, hover, command, and hardware input events.
- A single rule concern is dominant and should drive the implementation.
- You want a focused workflow instead of loading a broad specialist by default.

## Primary References
- Subagent: `.cursor/agents/swiftui-input-events.md`
- Rule: `.cursor/rules/swiftui/input-events.mdc`

## Workflow
1. Read the matching subagent brief and load the backing rule file before changing code.
2. Inspect the files in scope and confirm that this concern is the main driver of the task.
3. Apply the rule's implementation guidance, anti-patterns, and checklist to the concrete change.
4. Pull in a pairing only if the task crosses into another concern in a concrete way.
5. Validate the result against the project-specific reference before handoff or merge.

## Cross-Domain Pairings
- Pair with `swiftui-focus` or `swiftui-toolbars-commands-menus` when event routing crosses focus and command systems.

## Validation Checklist
- The dominant concern still matches this one-to-one skill.
- File scope is limited to the rule's real area of responsibility.
- Any paired concern is explicit and justified.
- The highest-risk regression was checked.

## Expected Output
- Files or modules that are in scope for this concern
- The rule constraints that shaped the implementation
- Any paired concern that had to be loaded
- The highest-risk regression or boundary to verify

## Detailed Project Guidance
- Use `.cursor/rules/swiftui/input-events.mdc` for project-specific intent, anti-patterns, and checklist.
## Current Subagent Brief
> Use this subagent when the task centers on keyboard, hover, or hardware input.
>
> Load and follow:
> - `.cursor/rules/swiftui/input-events.mdc`
>
> Pair with `swiftui-focus` or `swiftui-toolbars-commands-menus` when event
> routing crosses focus and command systems.
