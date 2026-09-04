import XCTest
@testable import KeyMaster

final class WindowManagementTests: XCTestCase {
    func testOperationInvocationRoundTrip() {
        for operation in WindowManagementOperation.allCases {
            XCTAssertEqual(WindowManagementOperation(invocation: operation.invocation), operation)
        }

        XCTAssertNil(
            WindowManagementOperation(
                invocation: ToolInvocation(toolID: WindowManagementOperation.toolID, displayName: "Invalid")
            )
        )
    }

    func testPlacementFramesUseVisibleBounds() {
        let visibleFrame = CGRect(x: 100, y: 40, width: 1200, height: 800)
        let windowFrame = CGRect(x: 300, y: 200, width: 500, height: 400)

        XCTAssertEqual(
            WindowManagementGeometry.frame(for: .leftHalf, windowFrame: windowFrame, visibleFrame: visibleFrame),
            CGRect(x: 100, y: 40, width: 600, height: 800)
        )
        XCTAssertEqual(
            WindowManagementGeometry.frame(for: .rightHalf, windowFrame: windowFrame, visibleFrame: visibleFrame),
            CGRect(x: 700, y: 40, width: 600, height: 800)
        )
        XCTAssertEqual(
            WindowManagementGeometry.frame(for: .fill, windowFrame: windowFrame, visibleFrame: visibleFrame),
            visibleFrame
        )
        XCTAssertEqual(
            WindowManagementGeometry.frame(for: .center, windowFrame: windowFrame, visibleFrame: visibleFrame),
            CGRect(x: 450, y: 240, width: 500, height: 400)
        )
    }

    func testNextDisplayPreservesRelativePlacementAndClampsSize() {
        let source = CGRect(x: 0, y: 20, width: 1000, height: 800)
        let destination = CGRect(x: 1000, y: 40, width: 600, height: 500)
        let window = CGRect(x: 400, y: 220, width: 500, height: 400)

        XCTAssertEqual(
            WindowManagementGeometry.movedFrame(window, from: source, to: destination),
            CGRect(x: 1080, y: 90, width: 500, height: 400)
        )

        let oversized = CGRect(x: 0, y: 20, width: 1200, height: 900)
        XCTAssertEqual(
            WindowManagementGeometry.movedFrame(oversized, from: source, to: destination),
            destination
        )
    }
}
