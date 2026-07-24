---
name: swiftdata-storage-infrastructure
description: Handles SwiftData model containers, model contexts, store configuration, and composition wiring.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on storage bootstrap or container
configuration.

Load and follow:
- `.cursor/rules/swiftdata/storage-infrastructure.mdc`

Pair with `swiftui-application-architecture` when app assembly also changes.
