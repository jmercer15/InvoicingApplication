---
name: swiftdata-relationships
description: Handles SwiftData relationship modeling, inverse links, delete rules, and optionality.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on model relationships.

Load and follow:
- `.cursor/rules/swiftdata/relationships.mdc`

Pair with `swiftdata-model-definition` when relationship changes also alter
schema attributes or migration expectations.
