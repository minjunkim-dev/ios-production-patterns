import XCTest
@testable import ProductionReliability

final class StartupCoordinatorTests: XCTestCase {
    struct Services: Equatable, Sendable {
        let sessionID: String?
    }

    struct TransientError: Error, Equatable {}
    struct PermanentError: Error, Equatable {}

    func testConcurrentStartsShareOneBuild() async throws {
        let counter = CallCounter()
        let latch = Latch()
        let expected = Services(sessionID: "fixture")
        let coordinator = StartupCoordinator<Services> {
            await counter.increment()
            await latch.wait()
            return expected
        }

        async let first = coordinator.start()
        async let second = coordinator.start()
        async let third = coordinator.start()

        // Give every caller a chance to enter `start()` while the build is held open.
        for _ in 0..<10 { await Task.yield() }
        await latch.open()

        let results = try await [first, second, third]

        XCTAssertEqual(results, [expected, expected, expected])
        let builds = await counter.value
        XCTAssertEqual(builds, 1)
    }

    func testReadyValueIsReusedWithoutRebuilding() async throws {
        let counter = CallCounter()
        let coordinator = StartupCoordinator<Services> {
            await counter.increment()
            return Services(sessionID: nil)
        }

        _ = try await coordinator.start()
        _ = try await coordinator.start()

        let builds = await counter.value
        XCTAssertEqual(builds, 1)
    }

    func testTransientFailureReturnsToIdleAndRetries() async throws {
        let plan = AttemptPlan(failuresBeforeSuccess: 1)
        let coordinator = StartupCoordinator<Services> {
            try await plan.next()
        }

        do {
            _ = try await coordinator.start()
            XCTFail("Expected TransientError")
        } catch is TransientError {
            // Expected: the first attempt fails and the coordinator returns to idle.
        }

        let services = try await coordinator.start()
        XCTAssertEqual(services, Services(sessionID: "retried"))
    }

    func testPermanentFailureIsKeptAndNotRetried() async throws {
        let counter = CallCounter()
        let coordinator = StartupCoordinator<Services>(
            isPermanentFailure: { $0 is PermanentError }
        ) {
            await counter.increment()
            throw PermanentError()
        }

        for _ in 0..<2 {
            do {
                _ = try await coordinator.start()
                XCTFail("Expected PermanentError")
            } catch is PermanentError {
                // Expected on every call.
            }
        }

        let builds = await counter.value
        XCTAssertEqual(builds, 1)
    }

    // MARK: - Helpers

    actor CallCounter {
        private(set) var value = 0

        func increment() {
            value += 1
        }
    }

    /// Holds builders open until the test releases them.
    actor Latch {
        private var isOpen = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            if isOpen { return }
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        func open() {
            isOpen = true
            let pending = waiters
            waiters.removeAll()
            for continuation in pending {
                continuation.resume()
            }
        }
    }

    actor AttemptPlan {
        private let failuresBeforeSuccess: Int
        private var attempt = 0

        init(failuresBeforeSuccess: Int) {
            self.failuresBeforeSuccess = failuresBeforeSuccess
        }

        func next() throws -> Services {
            attempt += 1
            if attempt <= failuresBeforeSuccess {
                throw TransientError()
            }
            return Services(sessionID: "retried")
        }
    }
}
