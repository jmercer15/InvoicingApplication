# DISPATCH — Worker M1 (Package Cleanup, Test Harness & Tooling Modernization)

## Objective
Execute all tasks for Milestone 1:
1. Delete empty directory `Packages/DTOMacros/`.
2. Centralize `TestTags` into `Packages/Core/Sources/Core/Testing/TestTags.swift`:
   ```swift
   import Testing

   public extension Tag {
       /// Fast, isolated tests (pure logic, mocks, in-memory with no cross-suite state).
       @Tag static var unit: Self

       /// Tests touching SwiftData, actors, async workflows, or multi-component wiring.
       @Tag static var integration: Self
   }
   ```
   - Delete all 14 duplicate `TestTags.swift` files listed in Explorer 1 report.
   - Add `import Core` to any test files using `.tags(.unit)` or `.tags(.integration)` if missing.
3. Root & Repository Cleanup:
   - Delete `default.profraw` at project root.
   - Add `*.profraw` to `.gitignore`.
   - Delete `scratch_build.log`, `scratch_build2.log`, `scratch_build3.log`, `scratch_build4.log`, `scratch_build5.log`.
   - Reconcile `Agents/`: Copy `Agents/teamwork_preview_auditor_1/` to `.agents/teamwork_preview_auditor_1/`, `Agents/teamwork_preview_worker_1/` to `.agents/teamwork_preview_worker_1/`, and `Agents/explorer_invoices_3_2_gen2/progress.md` to `.agents/explorer_invoices_3_2_gen2/progress.md`. Delete `Agents/` directory.
4. Legacy Script Cleanup:
   - Delete 13 python migration scripts in `scripts/` and `scripts/__pycache__/`.
5. Modernize `scripts/refactor-verify.sh`:
   - Update `scripts/refactor-verify.sh` to test/build all 14 packages and run root xcodebuild step.
6. Verify changes:
   - Run `swift test --package-path Packages/Core`
   - Run `./scripts/architecture-check.sh`
   - Run `./scripts/refactor-verify.sh`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Reports to Reference
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m1_1/handoff.md`
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m1_2/handoff.md`
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m1_3/handoff.md`
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/ORIGINAL_REQUEST.md`

## Required Output
Write your handoff report to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_m1/handoff.md`. Include full build/test commands executed and results.
