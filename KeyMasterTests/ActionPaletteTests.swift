import XCTest
@testable import KeyMaster

final class ActionPaletteTests: XCTestCase {
    func testSelectedTextRejectsWhitespaceAndTrimsSearchQuery() {
        XCTAssertNil(ActionPaletteSupport.selectedText(from: " \n "))
        XCTAssertEqual(ActionPaletteSupport.selectedText(from: "  KeyMaster \n"), "KeyMaster")
    }

    func testGoogleSearchURLUsesAnEncodedQueryItem() throws {
        let url = try XCTUnwrap(ActionPaletteSupport.googleSearchURL(for: "Swift URL & WebKit"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.path, "/search")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "q", value: "Swift URL & WebKit")])
    }

    func testAccessibilityRectConvertsFromTopLeftToAppKitCoordinates() {
        let rect = ActionPaletteGeometry.appKitRect(
            fromAccessibilityRect: CGRect(x: 2100, y: 150, width: 120, height: 24),
            displayBounds: CGRect(x: 1920, y: 0, width: 1440, height: 900),
            screenFrame: CGRect(x: 1920, y: 0, width: 1440, height: 900)
        )

        XCTAssertEqual(rect, CGRect(x: 2100, y: 726, width: 120, height: 24))
    }

    func testChooserPrefersBelowThenAboveAndClampsHorizontally() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let size = CGSize(width: 188, height: 48)

        XCTAssertEqual(
            ActionPaletteGeometry.chooserFrame(
                selectionFrame: CGRect(x: 400, y: 400, width: 100, height: 20),
                visibleFrame: visibleFrame,
                size: size
            ),
            CGRect(x: 356, y: 344, width: 188, height: 48)
        )
        XCTAssertEqual(
            ActionPaletteGeometry.chooserFrame(
                selectionFrame: CGRect(x: 970, y: 20, width: 20, height: 20),
                visibleFrame: visibleFrame,
                size: size
            ),
            CGRect(x: 800, y: 48, width: 188, height: 48)
        )
    }

    func testChooserFallsBackNearUpperCenterWithoutSelectionBounds() {
        let frame = ActionPaletteGeometry.chooserFrame(
            selectionFrame: nil,
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 700),
            size: CGSize(width: 188, height: 48)
        )

        XCTAssertEqual(frame, CGRect(x: 406, y: 568, width: 188, height: 48))
    }

    func testPaletteKeyCommands() {
        XCTAssertEqual(ActionPaletteKeyCommand(keyCode: 36), .execute)
        XCTAssertEqual(ActionPaletteKeyCommand(keyCode: 76), .execute)
        XCTAssertEqual(ActionPaletteKeyCommand(keyCode: 123), .moveSelection(-1))
        XCTAssertEqual(ActionPaletteKeyCommand(keyCode: 124), .moveSelection(1))
        XCTAssertEqual(ActionPaletteKeyCommand(keyCode: 53), .close)
        XCTAssertNil(ActionPaletteKeyCommand(keyCode: 0))
    }
}
