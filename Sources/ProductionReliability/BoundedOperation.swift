public struct OperationTimedOut: Error, Equatable, Sendable {
    public init() {}
}

/// Races an operation against a bounded timeout and cancels the losing task.
public func withTimeout<Value: Sendable>(
    nanoseconds: UInt64,
    operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            try Task.checkCancellation()
            throw OperationTimedOut()
        }

        guard let first = try await group.next() else {
            throw CancellationError()
        }
        group.cancelAll()
        return first
    }
}
