---
name: swiftui-state-management-data-flow
description: Handles SwiftUI state ownership, bindings, observation, and data flow.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on source-of-truth and binding design.

Load and follow:
- `.cursor/rules/swiftui/state-management-data-flow.mdc`

Pair with `swiftdata-persistence-lifecycle` when edits must preserve consistent
save, delete, or undo semantics.
