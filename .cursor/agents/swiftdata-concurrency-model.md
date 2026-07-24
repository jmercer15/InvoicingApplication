---
name: swiftdata-concurrency-model
description: Handles SwiftData ModelActor use, executors, and context isolation.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on actor ownership or context isolation.

Load and follow:
- `.cursor/rules/swiftdata/concurrency-model.mdc`

Pair with `swiftdata-storage-infrastructure` when container wiring and actor
ownership change together.
