---
name: swiftdata-query-system
description: Handles SwiftData predicates, sorting, Query usage, and fetch descriptor design.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on query shape or fetch behavior.

Load and follow:
- `.cursor/rules/swiftdata/query-system.mdc`

Pair with `swiftui-search` when predicates and sorting are driven by search UI.
