import Testing

extension Tag {
    /// Fast, isolated tests (pure logic, mocks, in-memory with no cross-suite state).
    @Tag static var unit: Self

    /// Tests touching SwiftData, actors, async workflows, or multi-component wiring.
    @Tag static var integration: Self
}
