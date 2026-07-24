## Baseline Metrics Capture

Capture these values on a clean baseline run before further refactors in this phase:

- `AppSession.bootstrap()` duration from scene launch to first render (ms)
  - Instrument with `os_signpost` around the bootstrap phases in `AppSession.bootstrap()`.
- Invoice filter throughput
  - Time from each `invoiceQuery` state mutation (`search`, `status`, `date`, `amount`, `client`) to first refreshed row count in `InvoicesContentColumn`.
- NDIS catalogue rebuild duration
  - Time from filter mutation (`quote/category/feature/unit`) to `catalogueProjection.filteredItems.count` change.
- Actor queue latency
  - `BillingDraftBuilderService.buildDraft`
  - `NDISContainerViewModel` projection worker
  - `TravelChargeAutomationActor.runAutomation`

## Baseline collection notes

- Run each probe on:
  - Small dataset (approx. 100 records)
  - Large dataset (approx. 2000+ records)
- Record results with timestamp and environment.
- Re-run after each implementation phase and fail any regression if >20% drift on primary flows.

## Refactor verification command

Run the local verification gate before handing off a refactor slice:

```sh
./scripts/refactor-verify.sh
```

The first step runs `./scripts/swift-repo-metrics.sh` (Swift file count, largest sources by LOC, and coarse `@Query` / `@Model` / `ModelContext` pattern counts) so hotspot lists stay reproducible.

The script currently covers:

- `SharedUI` tests, including navigation history and inspector fallback coverage.
- `Feature.Settings` tests, including calendar session clear autosave policy.
- `Feature.Calendar` build, covering the session form hotspot extraction.
- Main `InvoicingApplication` Debug build for macOS.

Capture the script duration output alongside any manual Instruments measurements so build/test time changes are visible during the refactor rollout.
