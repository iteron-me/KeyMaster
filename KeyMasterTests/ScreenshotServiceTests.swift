import AppKit
import CoreGraphics
import XCTest
@testable import KeyMaster

final class ScreenshotServiceTests: XCTestCase {
    func testCaptureCropsFrozenRetinaPixelsWithoutVerticalFlip() throws {
        let screenImage = try makeImage(
            width: 4,
            height: 4,
            pixels: [
                red, red, green, green,
                red, red, green, green,
                blue, blue, white, white,
                blue, blue, white, white
            ]
        )

        let capture = try ScreenshotService.capture(
            rect: CGRect(x: 0, y: 0, width: 1, height: 1),
            from: screenImage,
            displaySize: CGSize(width: 2, height: 2)
        )
        let capturedImage = try XCTUnwrap(capture.cgImage(forProposedRect: nil, context: nil, hints: nil))

        XCTAssertEqual(capturedImage.width, 2)
        XCTAssertEqual(capturedImage.height, 2)
        XCTAssertEqual(try pixel(atX: 0, y: 0, in: capturedImage), red)
        XCTAssertEqual(try pixel(atX: 1, y: 1, in: capturedImage), red)
    }

    func testCaptureClampsSelectionAndExpandsToPixelEdges() throws {
        let screenImage = try makeImage(
            width: 6,
            height: 4,
            pixels: Array(repeating: green, count: 24)
        )

        let capture = try ScreenshotService.capture(
            rect: CGRect(x: 1.25, y: -1, width: 5, height: 2.25),
            from: screenImage,
            displaySize: CGSize(width: 3, height: 2)
        )
        let capturedImage = try XCTUnwrap(capture.cgImage(forProposedRect: nil, context: nil, hints: nil))

        XCTAssertEqual(capturedImage.width, 4)
        XCTAssertEqual(capturedImage.height, 3)
    }

    func testCaptureRejectsEmptySelection() throws {
        let screenImage = try makeImage(width: 1, height: 1, pixels: [white])

        XCTAssertThrowsError(
            try ScreenshotService.capture(
                rect: .zero,
                from: screenImage,
                displaySize: CGSize(width: 1, height: 1)
            )
        ) { error in
            guard let screenshotError = error as? ScreenshotError, case .emptySelection = screenshotError else {
                return XCTFail("Expected empty selection error, got \(error)")
            }
        }
    }

    private func makeImage(width: Int, height: Int, pixels: [Pixel]) throws -> CGImage {
        let data = Data(pixels.flatMap(\.components))
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        return try XCTUnwrap(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
    }

    private func pixel(atX x: Int, y: Int, in image: CGImage) throws -> Pixel {
        let data = try XCTUnwrap(image.dataProvider?.data)
        let bytes = CFDataGetBytePtr(data)
        let offset = y * image.bytesPerRow + x * 4
        return Pixel(
            red: bytes?[offset] ?? 0,
            green: bytes?[offset + 1] ?? 0,
            blue: bytes?[offset + 2] ?? 0,
            alpha: bytes?[offset + 3] ?? 0
        )
    }

    private let red = Pixel(red: 255, green: 0, blue: 0, alpha: 255)
    private let green = Pixel(red: 0, green: 255, blue: 0, alpha: 255)
    private let blue = Pixel(red: 0, green: 0, blue: 255, alpha: 255)
    private let white = Pixel(red: 255, green: 255, blue: 255, alpha: 255)
}

private struct Pixel: Equatable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var alpha: UInt8

    var components: [UInt8] {
        [red, green, blue, alpha]
    }
}
