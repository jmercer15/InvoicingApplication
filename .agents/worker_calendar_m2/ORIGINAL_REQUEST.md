## 2026-06-14T00:30:04+10:00

You are the Worker for Milestone 2: Calendar UI Refinement.

Your working directory is:
/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_calendar_m2/

Your objective is to implement the Calendar UI Refinement changes specified in the plan file:
/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/sub_orch_billinghub_calendar/plan.md

Specifically, you must modify the following 3 files according to the details in the plan:

1. Packages/Feature.Calendar/Sources/Feature_Calendar/Views/MonthView/MonthView.swift
   - Remove the date selector button wrapper around the cell view inside `dayCellView(date: Date, weekIndex: Int, dayIndex: Int)` to prevent nested buttons. Let the cells render directly and handle their own selection.

2. Packages/Feature.Calendar/Sources/Feature_Calendar/Views/MonthView/MonthDayCellView.swift
   - Add a static `accessibilityDateFormatter` (DateFormatter with dateStyle = .full).
   - Modify the cell body to use a ZStack:
     - The background component should be a plain Button (`.buttonStyle(.plain)`) that sets `viewModel.selectedDate = date` on tap, and has `accessibilityLabel("Select \(date, formatter: Self.accessibilityDateFormatter)")`.
     - The foreground component should be a VStack rendering the day number header, item indicators, and spacer.
     - Make sure `.allowsHitTesting(true)` is applied so overlays/subviews remain interactive.

3. Packages/Feature.Calendar/Sources/Feature_Calendar/Views/WeekView/CalendarItemBlockView.swift
   - Modify the button to use style `.plain`.
   - Apply `.accessibilityElement(children: .combine)`.
   - Set descriptive accessibility labels, e.g., combining `item.title`, `timeRangeText`, client name, status.
   - Add custom accessibility action: `.accessibilityAction(named: "View Details")` triggering the same tap handler.

Please build the project and run all tests for the InvoicingApplication after implementing these changes to verify they compile and succeed.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

When complete, write a detailed handoff.md in your working directory and notify the parent orchestrator.
