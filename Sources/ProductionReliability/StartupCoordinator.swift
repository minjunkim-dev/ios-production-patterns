/// Shares one in-flight initialization between every caller.
///
/// App delegates, scene connections, push handlers, and deep links all tend to
/// request the same startup work. A plain `isReady` flag cannot stop them from
/// overlapping, because an actor method may be re-entered at every `await`.
/// `StartupCoordinator` stores the running `Task` itself, so later callers wait
/// on the same work instead of starting it again, and a finished value is
/// reused without rebuilding.
public actor StartupCoordinator<Value: Sendable> {
    public typealias Builder = @Sendable () async throws -> Value

    private enum State {
        case idle
        case running(Task<Value, any Error>)
        case ready(Value)
    }

    private var state: State = .idle
    private let build: Builder

    /// - Parameter build: Produces the fully initialized value. It must return
    ///   only after every dependency is ready, so callers never observe a
    ///   partially initialized state.
    public init(build: @escaping Builder) {
        self.build = build
    }

    /// Returns the initialized value, starting the build only when nothing is
    /// running and no result exists yet.
    ///
    /// Concurrent callers share the same build. A failed build returns the
    /// coordinator to `idle`, so the next call retries.
    public func start() async throws -> Value {
        switch state {
        case .ready(let value):
            return value

        case .running(let task):
            return try await task.value

        case .idle:
            let task = Task { try await build() }
            // Record the task before the first suspension point so re-entrant
            // callers observe `.running` instead of starting a second build.
            state = .running(task)

            do {
                let value = try await task.value
                if case .running(let current) = state, current == task {
                    state = .ready(value)
                }
                return value
            } catch {
                if case .running(let current) = state, current == task {
                    state = .idle
                }
                throw error
            }
        }
    }
}
