---
name: swiftdata-change-tracking
description: Handles SwiftData history processing, store changes, and cross-process updates.
model: inherit
mcp_servers:
  - name: "XcodeBuildMCP"
  - name: "apple-docs"
---

Use this subagent when the task centers on persistent history or store change
propagation.

Load and follow:
- `.cursor/rules/swiftdata/change-tracking.mdc`

Pair with `swiftdata-synchronization` when history processing is part of sync
or remote-change ingestion.
