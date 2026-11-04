// SPDX-License-Identifier: MIT

import XCTest
import CoreGraphics
@testable import MatrixKit

final class DominantColorTests: XCTestCase {
    /// An image of 64 x 64 drawn by `draw`, on a transparent background.
    private func image(_ draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(context)
        return context.makeImage()!
    }

    private func fill(_ c: CGContext, _ r: Double, _ g: Double, _ b: Double, _ rect: CGRect) {
        c.setFillColor(red: r, green: g, blue: b, alpha: 1)
        c.fill(rect)
    }

    private func hue(_ c: BadgeStyle.RGB) -> Double { DominantColor.hsb(c.r, c.g, c.b).h }

    func testARedSquareOnATransparentBackgroundIsRed() throws {
        let img = image { fill($0, 0.9, 0.1, 0.1, CGRect(x: 12, y: 12, width: 40, height: 40)) }
        let c = try XCTUnwrap(DominantColor.raw(of: img))
        XCTAssertTrue(hue(c) < 0.03 || hue(c) > 0.97)
    }

    func testTheWhiteOfABackgroundDoesNotWin() throws {
        let img = image {
            fill($0, 1, 1, 1, CGRect(x: 0, y: 0, width: 64, height: 64))
            fill($0, 0.1, 0.4, 0.9, CGRect(x: 20, y: 20, width: 24, height: 24))
        }
        let c = try XCTUnwrap(DominantColor.raw(of: img))
        XCTAssertEqual(hue(c), 0.6, accuracy: 0.05)   // blue
    }

    func testTheLargestAreaOfColourWins() throws {
        let img = image {
            fill($0, 0.1, 0.8, 0.2, CGRect(x: 0, y: 0, width: 64, height: 22))    // green, a third
            fill($0, 0.1, 0.2, 0.9, CGRect(x: 0, y: 22, width: 64, height: 42))   // blue
        }
        let c = try XCTUnwrap(DominantColor.raw(of: img))
        XCTAssertEqual(hue(c), 0.65, accuracy: 0.06)
    }

    func testAnImageWithoutColourHasNone() {
        XCTAssertNil(DominantColor.raw(of: image { _ in }))                                       // transparent
        XCTAssertNil(DominantColor.raw(of: image { self.fill($0, 0.5, 0.5, 0.5, CGRect(x: 0, y: 0, width: 64, height: 64)) }))   // grey
        XCTAssertNil(DominantColor.raw(of: image { self.fill($0, 0.05, 0.05, 0.05, CGRect(x: 0, y: 0, width: 64, height: 64)) })) // black
    }

    func testTheAccentIsBroughtIntoTheRangeOfTheOthers() throws {
        let img = image { fill($0, 0.35, 0.05, 0.05, CGRect(x: 0, y: 0, width: 64, height: 64)) }   // a very dark red
        let a = try XCTUnwrap(DominantColor.accent(of: img))
        let (_, s, v) = DominantColor.hsb(a.r, a.g, a.b)
        XCTAssertGreaterThanOrEqual(v, 0.62 - 1e-9)
        XCTAssertGreaterThanOrEqual(s, 0.5 - 1e-9)
    }
}
