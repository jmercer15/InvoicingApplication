import Foundation

/// Converts operation failures into stable, user-facing detail while keeping framework
/// diagnostics out of invoice and template workflows.
public enum InvoiceOperationErrorPresentation {
  public static func detail(
    for error: any Error,
    fallback: String
  ) -> String {
    let normalizedFallback = normalized(fallback)
    let nsError = error as NSError
    let description = normalized(error.localizedDescription)

    guard !containsOpaquePersistenceFailure(nsError),
      !isFrameworkBoilerplate(description)
    else {
      return normalizedFallback
    }

    return description.isEmpty ? normalizedFallback : description
  }

  private static func containsOpaquePersistenceFailure(_ rootError: NSError) -> Bool {
    var pending = [rootError]
    var visited = Set<ObjectIdentifier>()

    while let error = pending.popLast() {
      let identity = ObjectIdentifier(error)
      guard visited.insert(identity).inserted else { continue }

      let domain = error.domain.localizedLowercase
      if domain.contains("swiftdata")
        || domain.contains("coredata")
        || domain.contains("persistentstore")
      {
        return true
      }

      if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
        pending.append(underlyingError)
      }
      if let detailedErrors = error.userInfo["NSDetailedErrors"] as? [NSError] {
        pending.append(contentsOf: detailedErrors)
      }
    }

    return false
  }

  private static func isFrameworkBoilerplate(_ description: String) -> Bool {
    let normalizedDescription = description.localizedLowercase
    return (
      normalizedDescription.hasPrefix("the operation couldn’t be completed. (")
        && normalizedDescription.contains(" error ")
    )
      || (
        normalizedDescription.hasPrefix("the operation couldn't be completed. (")
          && normalizedDescription.contains(" error ")
      )
  }

  private static func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
