import Foundation
import Observation

/// Cached validation output split from draft field storage so typing in the inspector
/// does not force every observer of `InvoiceEditorViewModel` to re-read `draftPayload`.
@Observable
@MainActor
final class InvoiceEditorValidationProjection {
  private(set) var errors: [String] = []
  private(set) var issues: [InvoiceValidationIssue] = []

  func apply(errors: [String], issues: [InvoiceValidationIssue]) {
    if self.errors != errors {
      self.errors = errors
    }
    if self.issues != issues {
      self.issues = issues
    }
  }

  func clear() {
    apply(errors: [], issues: [])
  }
}
