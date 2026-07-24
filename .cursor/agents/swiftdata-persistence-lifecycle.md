---
name: swiftdata-persistence-lifecycle
description: Handles SwiftData create, update, delete, autosave, and undo behavior.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on data lifecycle semantics.

Load and follow:
- `.cursor/rules/swiftdata/persistence-lifecycle.mdc`

Pair with `swiftui-state-management-data-flow` when lifecycle decisions affect
editing flows or user-visible mutation behavior.
