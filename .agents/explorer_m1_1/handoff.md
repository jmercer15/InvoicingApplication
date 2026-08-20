# Handoff Report — Milestone 1 Investigation (TestTags & DTOMacros)

## 1. Observation

### Item 1: Removal of `Packages/DTOMacros` Empty Directory
- **Path**: `Packages/DTOMacros/`
- **Directory Inspection**:
  - `list_dir` output shows subdirectories `Sources` and `Tests`, plus hidden `.swiftpm` directory and `Package.resolved`.
  - `find_by_name` for `*` within `Packages/DTOMacros` returns 6 items: `Package.resolved`, `Sources`, `Sources/DTOMacros`, `Sources/DTOMacrosImplementation`, `Tests`, `Tests/DTOMacrosTests`.
  - Total `.swift` files present: **0**.
  - `Package.swift` manifest: **Missing**.
- **Grep Workspace Check**:
  - Searching for string `"DTOMacros"` across workspace (`grep_search`) returned matches **only** inside `.agents/` documentation logs and `REFACTOR_PLAN.md`.
  - Zero references in active `Package.swift` files, Xcode `.xcodeproj` target definitions, or build scripts in `scripts/`.

### Item 2: Centralizing `TestTags` into `Packages/Core/Sources/Core/Testing/TestTags.swift`
- **Path**: `Packages/Core/Sources/Core/Testing/`
- **Core Library Target**:
  - `Packages/Core/Package.swift` exports library product `"Core"` pointing to target `"Core"`.
  - `Packages/Core/Sources/Core/Testing/` already exists in the `Core` target and currently contains `NDISBillingTestDoubles.swift`, `TestAsyncHelpers.swift`, and `TestClock.swift`.
- **Target Dependencies in `Package.swift` Manifests**:
  - All 11 test packages (14 test targets) explicitly declare `"Core"` as a dependency in their `testTarget` configurations:
    - `Packages/AppShell/Package.swift` line 54: `AppShellTests` depends on `"Core"`
    - `Packages/Core/Package.swift` line 21: `CoreTests` depends on `"Core"`
    - `Packages/Data/Package.swift` lines 33, 39, 45, 51: `DataUseCaseTests`, `DataServiceTests`, `DataBusinessLogicTests`, `DataValidationTests` depend on `"Core"`
    - `Packages/DataInterfaces/Package.swift` line 27: `DataInterfacesTests` depends on `"Core"`
    - `Packages/Feature.BillingHub/Package.swift` line 35: `Feature_BillingHubTests` depends on `"Core"`
    - `Packages/Feature.Calendar/Package.swift` line 32: `Feature_CalendarTests` depends on `"Core"`
    - `Packages/Feature.Clients/Package.swift` line 32: `Feature_ClientsTests` depends on `"Core"`
    - `Packages/Feature.InvoiceTemplateEditor/Package.swift` line 30: `InvoiceTableLayoutEditorTests` depends on `"Core"`
    - `Packages/Feature.Invoices/Package.swift` line 42: `Feature_InvoicesTests` depends on `"Core"`
    - `Packages/Feature.NDIS/Package.swift` line 30: `Feature_NDISTests` depends on `"Core"`
    - `Packages/SharedUI/Package.swift` line 29: `SharedUITests` depends on `"Core"`

### Item 3: List of Duplicate `TestTags.swift` Files Across Test Targets
- **Find Result**: Exactly 14 `TestTags.swift` files found across package test directories:
  1. `Packages/AppShell/Tests/AppShellTests/TestTags.swift`
  2. `Packages/Core/Tests/CoreTests/TestTags.swift`
  3. `Packages/Data/Tests/DataTests/BusinessLogic/TestTags.swift`
  4. `Packages/Data/Tests/DataTests/Services/TestTags.swift`
  5. `Packages/Data/Tests/DataTests/UseCases/TestTags.swift`
  6. `Packages/Data/Tests/DataTests/Validation/TestTags.swift`
  7. `Packages/DataInterfaces/Tests/DataInterfacesTests/TestTags.swift`
  8. `Packages/Feature.BillingHub/Tests/Feature_BillingHubTests/TestTags.swift`
  9. `Packages/Feature.Calendar/Tests/Feature_CalendarTests/TestTags.swift`
  10. `Packages/Feature.Clients/Tests/Feature_ClientsTests/TestTags.swift`
  11. `Packages/Feature.InvoiceTemplateEditor/Tests/InvoiceTableLayoutEditorTests/TestTags.swift`
  12. `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/TestTags.swift`
  13. `Packages/Feature.NDIS/Tests/Feature_NDISTests/TestTags.swift`
  14. `Packages/SharedUI/Tests/SharedUITests/TestTags.swift`
- **File Content**: All 14 files contain verbatim identical implementation:
  ```swift
  import Testing

  extension Tag {
      /// Fast, isolated tests (pure logic, mocks, in-memory with no cross-suite state).
      @Tag static var unit: Self

      /// Tests touching SwiftData, actors, async workflows, or multi-component wiring.
      @Tag static var integration: Self
  }
  ```

---

## 2. Logic Chain

1. **`Packages/DTOMacros` Removal**:
   - Observation shows `Packages/DTOMacros` contains no `Package.swift` and zero `.swift` files.
   - Grep search confirms no target or package manifest references `DTOMacros`.
   - Therefore, removing `Packages/DTOMacros` will not break any SPM dependency graph or build step.

2. **Centralizing `TestTags` into `Core` Target**:
   - `Packages/Core/Sources/Core/Testing/` is part of the `Core` target product.
   - Creating `Packages/Core/Sources/Core/Testing/TestTags.swift` with `public extension Tag` makes `@Tag public static var unit: Self` and `@Tag public static var integration: Self` visible to any module importing `Core`.
   - Observation confirms every test target across all 11 test packages explicitly depends on `Core` in `Package.swift`.
   - Therefore, when `TestTags.swift` is added to `Core/Sources/Core/Testing/TestTags.swift` as `public extension Tag`, all test targets can access `Tag.unit` and `Tag.integration` via `import Core`.

3. **Eliminating Duplicate Files**:
   - Observation confirms 14 identical `TestTags.swift` copies exist across test target folders.
   - Since `Core` will export `Tag.unit` and `Tag.integration` publicly, all 14 local `TestTags.swift` files are redundant and can be deleted.

4. **Import Adjustments**:
   - Observation showed some individual test files (e.g. `BillingHubDurationParserTests.swift` in `Feature_BillingHubTests` and `WeekDayColumnIdentityTests.swift` in `Feature_CalendarTests`) do not have `import Core` at the top of the file because they previously relied on package-scoped `TestTags.swift`.
   - Therefore, when removing local `TestTags.swift`, any test file using `.tags(.unit)` or `.tags(.integration)` must include `import Core` if it is not already present.

---

## 3. Caveats

- **Access Modifier**: The centralized `Tag` extension in `Packages/Core/Sources/Core/Testing/TestTags.swift` MUST be declared as `public extension Tag` with `public static var unit: Self` and `public static var integration: Self`. If declared `internal`, test targets importing `Core` will not be able to access the tags.
- **Explicit `import Core`**: Any test file using `@Suite(.tags(.unit))` or `@Suite(.tags(.integration))` that does not currently `import Core` will require `import Core` to be added at top of file.
- No other caveats.

---

## 4. Conclusion

1. **Delete `Packages/DTOMacros`**: Safe to execute `rm -rf Packages/DTOMacros`.
2. **Create `Packages/Core/Sources/Core/Testing/TestTags.swift`**:
   ```swift
   import Testing

   public extension Tag {
       /// Fast, isolated tests (pure logic, mocks, in-memory with no cross-suite state).
       @Tag static var unit: Self

       /// Tests touching SwiftData, actors, async workflows, or multi-component wiring.
       @Tag static var integration: Self
   }
   ```
3. **Delete All 14 Duplicate `TestTags.swift` Files**: Remove the 14 files listed in Section 1 Item 3.
4. **Ensure `import Core`**: Add `import Core` to any test file using `.tags(.unit)` or `.tags(.integration)` if `import Core` is absent.

---

## 5. Verification Method

### Automated Commands
Run the following test commands to verify compilation and test execution:

```bash
# 1. Verify Core package compilation and tests
swift test --package-path Packages/Core

# 2. Verify all affected test packages pass 100%
swift test --package-path Packages/AppShell
swift test --package-path Packages/Data
swift test --package-path Packages/DataInterfaces
swift test --package-path Packages/Feature.BillingHub
swift test --package-path Packages/Feature.Calendar
swift test --package-path Packages/Feature.Clients
swift test --package-path Packages/Feature.InvoiceTemplateEditor
swift test --package-path Packages/Feature.Invoices
swift test --package-path Packages/Feature.NDIS
swift test --package-path Packages/SharedUI

# 3. Verify architecture rules pass
./scripts/architecture-check.sh
```

### Invalidation Conditions
- If any test target fails with `cannot find 'unit' in scope` or `value of type 'Tag' has no member 'unit'`, check that `TestTags.swift` in `Core` uses `public extension Tag` and that the failing test file imports `Core`.
