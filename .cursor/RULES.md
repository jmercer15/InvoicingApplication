# Cursor Rules Documentation

## Overview

This directory contains Cursor rules that provide persistent context and guidance for AI assistance in this codebase. Rules are organized by type and scope to ensure appropriate application.

## Rule Organization

### Tier 1: Core Foundation (Always Applied)

These rules are always included in the AI context, providing fundamental patterns that must always be considered:

- **architecture.mdc** - Clean architecture patterns, package structure, repository pattern, dependency injection
- **swiftdata-core.mdc** - Fundamental SwiftData patterns: entities, relationships, queries, context management
- **color-system.mdc** - System color usage enforcement, preventing hard-coded colors
- **coding-standards.mdc** - Swift naming conventions, access control, documentation, error handling

**When to Use**: Always applied automatically - no configuration needed.

### Tier 2: Context-Specific (Auto Attached)

These rules automatically attach when working with specific file patterns:

- **domain-entity-mapping.mdc** - Mapping patterns between domain models and entities
  - Triggers: `**/*Mapping.swift`, `**/Data/Mapping/**/*.swift`, `**/Data/Repositories/**/*.swift`
  
- **repository-pattern.mdc** - Repository pattern implementation guidelines
  - Triggers: `**/*Repository*.swift`, `**/Ports/**/*.swift`, `**/Repositories/**/*.swift`
  
- **swiftui-views.mdc** - SwiftUI view patterns and state management
  - Triggers: `**/*View*.swift`, `**/Feature.*/**/Views/**/*.swift`, `**/SharedUI/**/Views/**/*.swift`
  
- **viewmodels.mdc** - ViewModel patterns with dependency injection
  - Triggers: `**/*ViewModel*.swift`, `**/Feature.*/**/ViewModels/**/*.swift`
  
- **swiftdata-entities.mdc** - Entity-specific patterns for definition and relationships
  - Triggers: `**/*Entity.swift`, `**/Data/Persistence/**/*.swift`

**When to Use**: Automatically applied based on file globs - no configuration needed.

### Tier 3: Specialized Knowledge (Agent Requested)

These rules are available when the AI determines they're relevant:

- **use-cases.mdc** - Use case patterns for business logic
- **testing-patterns.mdc** - Testing patterns for unit, integration, and round-trip tests
- **migrations.mdc** - SwiftData migration patterns and strategies

**When to Use**: Mentioned explicitly in chat or when AI determines relevance.

## Rule Type Selection Guide

### When to Create an "Always" Rule

Create an Always rule when:
- The pattern is fundamental and always relevant
- The pattern prevents common mistakes
- The pattern applies across all file types
- The pattern is critical for codebase consistency

Examples: Architecture patterns, core SwiftData patterns, color system enforcement.

### When to Create an "Auto Attached" Rule

Create an Auto Attached rule when:
- The pattern is specific to certain file types
- The pattern should appear when working with related files
- The pattern has clear file name patterns (globs)

Examples: Mapping patterns, repository patterns, view patterns, ViewModel patterns.

### When to Create an "Agent Requested" Rule

Create an Agent Requested rule when:
- The pattern is specialized and not always needed
- The pattern is used infrequently
- The pattern has clear use cases where it becomes relevant

Examples: Testing patterns, migration patterns, specialized feature patterns.

## When to Create New Rules

Create a new rule when:

1. **You find yourself repeating the same guidance** in multiple chat sessions
2. **A pattern is important but not obvious** from the codebase alone
3. **A pattern prevents common mistakes** or enforces critical requirements
4. **A pattern needs to be discoverable** by the AI when relevant

### Rule Creation Checklist

- [ ] Rule has clear, specific purpose
- [ ] Rule is under 500 lines (split if needed)
- [ ] Rule includes concrete code examples (✅ correct, ❌ incorrect)
- [ ] Rule references actual codebase files
- [ ] Rule has appropriate type (Always/Auto Attached/Agent Requested)
- [ ] Rule has proper metadata (description, globs, alwaysApply)
- [ ] Rule cross-references related rules

## Maintenance Guidelines

### Regular Reviews

- **Quarterly**: Review all rules for accuracy and relevance
- **After major refactors**: Update rules to reflect new patterns
- **When patterns evolve**: Update rules to match current codebase

### Content Updates

When updating rules:
1. Verify examples still match current codebase
2. Update file references if files moved
3. Add new patterns discovered in codebase
4. Remove deprecated patterns
5. Update cross-references to other rules

### Quality Standards

All rules should:
- Be actionable (specific guidance, not vague principles)
- Include code examples (both correct and incorrect patterns)
- Reference actual codebase files
- Be under 500 lines
- Have clear, focused purpose

## Quick Reference

### Rule Types

| Type | When Applied | Configuration |
|------|--------------|---------------|
| Always | Always | `alwaysApply: true` |
| Auto Attached | When globs match | `globs: ["**/pattern/**/*.swift"]`, `alwaysApply: false` |
| Agent Requested | When AI determines relevant | `description: "..."`, `alwaysApply: false` |

### File Naming

- Use kebab-case: `domain-entity-mapping.mdc`
- Be descriptive: `swiftdata-core.mdc` not `swiftdata.mdc`
- Match content scope: One focused pattern per rule

### Metadata Template

```yaml
---
description: Clear description (required for Agent Requested)
globs:
  - "**/pattern/**/*.swift"  # Only for Auto Attached
alwaysApply: true  # true for Always, false otherwise
---
```

## Current Rules Inventory

### Always Applied (4)
1. architecture.mdc
2. swiftdata-core.mdc
3. color-system.mdc
4. coding-standards.mdc

### Auto Attached (5)
1. domain-entity-mapping.mdc
2. repository-pattern.mdc
3. swiftui-views.mdc
4. viewmodels.mdc
5. swiftdata-entities.mdc

### Agent Requested (3)
1. use-cases.mdc
2. testing-patterns.mdc
3. migrations.mdc

## Related Documentation

- `README.md` - Architecture overview
- `COLOR_SYSTEM_GUIDE.md` - Color system documentation
- `Packages/Data/Sources/Data/Mapping/Architectural_Patterns_and_Conventions.md` - Mapping conventions
- `Packages/Data/Sources/Data/Mapping/Relationship_Delete_Rules_Audit.md` - Delete rules guidelines

## Support

For questions about rules or to suggest new rules, review the codebase patterns and create rules following the guidelines in this document.
