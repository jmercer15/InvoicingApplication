#if canImport(Testing)
import Testing

public extension Tag {
    /// Fast, isolated tests with no shared external state.
    @Tag static var unit: Self

    /// Tests spanning persistence, actors, or multiple components.
    @Tag static var integration: Self
}
#endif
