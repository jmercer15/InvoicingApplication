# Orchestration Plan — Core Capabilities Expansion

## Objectives
1. Feature.Invoices Capability Enhancements:
   - Revenue & Status Analytics Summary (Total Billed, Total Received, Outstanding/Overdue, Draft count per currency).
   - Invoice Duplication Workflow (duplicate/clone invoice, auto-increment invoice number, refresh dates).
   - Batch Data Export (export invoice summary projections to CSV or JSON formats).
2. Feature.InvoiceTemplateEditor Capability Enhancements:
   - Template Preset Management (loading/saving layout presets: margins, font scale, accent color, header layout).
   - Brand Accent & Logo Customization (controls for accent color and header branding layout).
   - Page Margin & Pagination Controls (interactive page margin adjustments & pagination breakpoint markers in preview).
3. Comprehensive Verification & Testing:
   - Unit test coverage for analytics calculations, cloning, export, preset serialization.
   - All unit tests pass in Feature.Invoices & Feature.InvoiceTemplateEditor.
   - `xcodebuild test -scheme InvoicingApplication -destination 'platform=macOS'` passes.
   - `./scripts/architecture-check.sh` passes cleanly.

## Execution Strategy & Phasing
- Phase 1: Exploration & Codebase Analysis (3 parallel Explorers).
- Phase 2: Feature.Invoices Implementation & Verification.
- Phase 3: Feature.InvoiceTemplateEditor Implementation & Verification.
- Phase 4: Full E2E & Architecture Verification (Reviewers + Forensic Auditor).
