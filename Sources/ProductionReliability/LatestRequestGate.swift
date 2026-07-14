public actor LatestRequestGate {
    public struct Token: Equatable, Sendable {
        fileprivate let generation: UInt64
    }

    private var generation: UInt64 = 0

    public init() {}

    /// Starts a new logical request and invalidates every previously issued token.
    public func begin() -> Token {
        generation &+= 1
        return Token(generation: generation)
    }

    /// Returns true only when no newer request or explicit invalidation has occurred.
    public func isCurrent(_ token: Token) -> Bool {
        token.generation == generation
    }

    public func invalidate() {
        generation &+= 1
    }
}
