import Testing

public extension Tag {
    /// Fast, isolated coverage with no external service dependency.
    @Tag static var unit: Self

    /// Coverage spanning package, persistence, or service boundaries.
    @Tag static var integration: Self
}
