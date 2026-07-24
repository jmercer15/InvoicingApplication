Skill: cursor-rule-router

Routes a task to the right SwiftUI or SwiftData subagent and backing project rules.

## When To Use This Skill
- The task is broad, ambiguous, or spans both UI and persistence concerns.
- You need to pick the narrowest useful specialist before edits start.
- The correct rule pairing is not obvious from the request alone.

## Primary References
- Subagent: `.cursor/agents/cursor-rule-router.md`
- Rule: `.cursor/rules/**/*.mdc`

## Workflow
1. Start from the files and behaviors being changed, not only the feature label.
2. Choose one primary subagent or skill and add a second only if the task truly crosses domains.
3. Name the backing `.cursor/rules/**/*.mdc` files that should be loaded for the task.
4. Call out the most fragile boundary to preserve before implementation begins.
5. Hand off to the chosen specialist or one-to-one skill once the routing decision is stable.

## Validation Checklist
- A single primary skill or subagent is named.
- Any secondary pairing is justified by the actual file and behavior scope.
- The backing rule files are explicit.
- The riskiest boundary is stated clearly.

## Expected Output
- Primary skill/subagent to use
- Secondary pairing, if any
- Exact rule files to load
- Boundary to preserve during implementation

## Current Subagent Brief
> You are the routing subagent for this repository.
>
> Start from the files and behaviors being changed. Choose the narrowest primary
> subagent and, if needed, one secondary pairing. Name the backing
> `.cursor/rules/**/*.mdc` files before implementation.
>
> Prefer:
> - one primary subagent
> - at most one secondary specialist
> - explicit rule references over vague architectural guidance
>
> Return:
> - primary subagent
> - secondary subagent, if any
> - backing rule files
> - highest-risk boundary to preserve
