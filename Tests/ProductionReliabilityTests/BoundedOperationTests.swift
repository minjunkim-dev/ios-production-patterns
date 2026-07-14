import XCTest
@testable import ProductionReliability

final class BoundedOperationTests: XCTestCase {
    func testFastOperationReturnsValue() async throws {
        let value = try await withTimeout(nanoseconds: 200_000_000) {
            "ready"
        }

        XCTAssertEqual(value, "ready")
    }

    func testSlowOperationThrowsTimeout() async {
        do {
            _ = try await withTimeout(nanoseconds: 10_000_000) {
                try await Task.sleep(nanoseconds: 200_000_000)
                return "too late"
            }
            XCTFail("Expected OperationTimedOut")
        } catch is OperationTimedOut {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
