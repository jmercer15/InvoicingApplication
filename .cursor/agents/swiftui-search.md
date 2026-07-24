---
name: swiftui-search
description: Handles SwiftUI searchable UIs, query binding, and search activation behavior.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on SwiftUI search UX.

Load and follow:
- `.cursor/rules/swiftui/search.mdc`

Pair with `swiftdata-query-system` when search behavior is backed by persisted
fetches or predicates.
