import XCTest
@testable import ProductionReliability

final class LatestRequestGateTests: XCTestCase {
    func testOnlyNewestRequestRemainsCurrent() async {
        let gate = LatestRequestGate()
        let first = await gate.begin()
        let second = await gate.begin()

        let firstIsCurrent = await gate.isCurrent(first)
        let secondIsCurrent = await gate.isCurrent(second)

        XCTAssertFalse(firstIsCurrent)
        XCTAssertTrue(secondIsCurrent)
    }

    func testInvalidateMakesCurrentRequestStale() async {
        let gate = LatestRequestGate()
        let token = await gate.begin()

        await gate.invalidate()

        let isCurrent = await gate.isCurrent(token)
        XCTAssertFalse(isCurrent)
    }
}
