# Cursor Skills

These project-level skills are derived from the current `.cursor/agents/` and
`.cursor/rules/` materials in this repository.

## Usage

- Use one-to-one skills when a single rule concern clearly dominates the task.
- Use `cursor-rule-router` when the task is ambiguous or cross-cutting.
- Use `swiftui-specialist` or `swiftdata-specialist` when the work spans multiple concerns inside one domain.
- Keep `.cursor/rules/` as the scoped rule source of truth.

## Available Skills

- `cursor-rule-router`: Routes a task to the right SwiftUI or SwiftData subagent and backing project rules
- `swiftdata-change-tracking`: Handles SwiftData history processing, store changes, and cross-process updates
- `swiftdata-concurrency-model`: Handles SwiftData ModelActor use, executors, and context isolation
- `swiftdata-model-definition`: Handles SwiftData @Model types, attributes, indexes, transients, and inheritance
- `swiftdata-persistence-lifecycle`: Handles SwiftData create, update, delete, autosave, and undo behavior
- `swiftdata-query-system`: Handles SwiftData predicates, sorting, Query usage, and fetch descriptor design
- `swiftdata-relationships`: Handles SwiftData relationship modeling, inverse links, delete rules, and optionality
- `swiftdata-specialist`: Handles broad SwiftData tasks spanning storage, models, queries, lifecycle, concurrency, and sync
- `swiftdata-storage-infrastructure`: Handles SwiftData model containers, model contexts, store configuration, and composition wiring
- `swiftdata-synchronization`: Handles SwiftData CloudKit synchronization, schema compatibility, and sync configuration
- `swiftui-animations`: Handles SwiftUI state-driven animation, transitions, and motion behavior
- `swiftui-application-architecture`: Handles SwiftUI app entry points, scenes, windows, and root-view composition
- `swiftui-clipboard`: Handles SwiftUI copy, cut, paste, and pasteboard-backed data exchange
- `swiftui-drag-and-drop`: Handles SwiftUI drag sources, drop targets, and Transferable-based movement
- `swiftui-environment-system`: Handles SwiftUI environment values, environment objects, and dependency propagation
- `swiftui-focus`: Handles SwiftUI focus chains, keyboard-first workflows, and focus synchronization
- `swiftui-gestures`: Handles SwiftUI gesture composition, precedence, and gesture-driven state
- `swiftui-input-events`: Handles SwiftUI keyboard, hover, command, and hardware input events
- `swiftui-layout-system`: Handles SwiftUI layout strategy, alignment, measurement, and adaptive sizing
- `swiftui-lists`: Handles SwiftUI List architecture, identity, sections, and editing behavior
- `swiftui-navigation-presentation`: Handles SwiftUI navigation stacks, destinations, sheets, and presentation flow
- `swiftui-persistent-storage`: Handles SwiftUI persisted UI state such as AppStorage and SceneStorage
- `swiftui-preferences-system`: Handles SwiftUI PreferenceKey-based upward communication and measurement propagation
- `swiftui-scroll-views`: Handles SwiftUI scroll positioning, scrolling behavior, and viewport coordination
- `swiftui-search`: Handles SwiftUI searchable UIs, query binding, and search activation behavior
- `swiftui-specialist`: Handles broad SwiftUI tasks spanning app structure, navigation, state, layout, and interaction
- `swiftui-state-management-data-flow`: Handles SwiftUI state ownership, bindings, observation, and data flow
- `swiftui-system-events`: Handles SwiftUI URLs, activities, background tasks, and external system events
- `swiftui-tables`: Handles SwiftUI Table-based multicolumn views, sorting, and table support types
- `swiftui-toolbars-commands-menus`: Handles SwiftUI toolbar content, commands, menus, and action routing
- `swiftui-view-hierarchy-composition`: Handles SwiftUI hierarchy design, layering, decomposition, and composition boundaries
- `swiftui-visual-components`: Handles SwiftUI text, images, controls, shapes, graphics, and styling choices
