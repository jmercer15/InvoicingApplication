---
name: swiftdata-synchronization
description: Handles SwiftData CloudKit synchronization, schema compatibility, and sync configuration.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on sync behavior or CloudKit
configuration.

Load and follow:
- `.cursor/rules/swiftdata/synchronization.mdc`

Pair with `swiftdata-change-tracking` or `swiftui-system-events` when sync
depends on history processing or app lifecycle events.
