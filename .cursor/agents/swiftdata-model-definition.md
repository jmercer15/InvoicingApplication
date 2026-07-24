---
name: swiftdata-model-definition
description: Handles SwiftData @Model types, attributes, indexes, transients, and inheritance.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on persistent model definitions.

Load and follow:
- `.cursor/rules/swiftdata/model-definition.mdc`

Pair with `swiftdata-relationships` when schema changes alter links, inverses,
or delete-rule behavior.
