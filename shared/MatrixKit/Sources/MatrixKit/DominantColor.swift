// SPDX-License-Identifier: MIT

import CoreGraphics
import Foundation

/// The main colour of an icon, for the accent bars of the matrix: a hue histogram of the icon, where each pixel
/// weighs its saturation, its brightness and its opacity, so that the white of a background or the grey of a
/// shadow never wins over a colour.
public enum DominantColor {
    private static let side = 32
    private static let bins = 24

    /// The most represented colour of the image, as it is (nil when the image has none: transparent, black,
    /// white or grey).
    public static func raw(of image: CGImage) -> BadgeStyle.RGB? {
        guard let pixels = rgba(of: image) else { return nil }
        var weight = [Double](repeating: 0, count: bins)
        var sum = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: bins)
        var total = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = Double(pixels[i + 3]) / 255
            guard a > 0.5 else { continue }
            // Premultiplied to straight colour.
            let r = min(Double(pixels[i]) / 255 / a, 1), g = min(Double(pixels[i + 1]) / 255 / a, 1), b = min(Double(pixels[i + 2]) / 255 / a, 1)
            let (h, s, v) = hsb(r, g, b)
            guard s >= 0.25, v >= 0.2 else { continue }
            let w = s * v * a
            let bin = min(Int(h * Double(bins)), bins - 1)
            weight[bin] += w
            sum[bin].r += r * w; sum[bin].g += g * w; sum[bin].b += b * w
            total += w
        }
        // A hue spreads over its neighbours (a red icon is never exactly one bin): the bin counts them in.
        var best = -1, bestScore = 0.0
        for bin in 0..<bins {
            let score = weight[bin] + 0.5 * (weight[(bin + 1) % bins] + weight[(bin + bins - 1) % bins])
            if score > bestScore { best = bin; bestScore = score }
        }
        // Less than 2 % of the pixels' worth of colour: the icon has none.
        guard best >= 0, total > Double(side * side) * 0.02, weight[best] > 0 else { return nil }
        let w = weight[best]
        return BadgeStyle.RGB(r: sum[best].r / w, g: sum[best].g / w, b: sum[best].b / w)
    }

    /// The accent: the main colour brought into the range of the other accents (saturation between 0.5 and 0.85,
    /// brightness between 0.62 and 0.9), so that it reads on a light and on a dark window alike.
    public static func accent(of image: CGImage) -> BadgeStyle.RGB? {
        raw(of: image).map(normalized)
    }

    public static func normalized(_ c: BadgeStyle.RGB) -> BadgeStyle.RGB {
        let (h, s, v) = hsb(c.r, c.g, c.b)
        return BadgeStyle.rgb(hue: h, saturation: min(max(s, 0.5), 0.85), brightness: min(max(v, 0.62), 0.9))
    }

    static func hsb(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, v: Double) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        guard d > 0 else { return (0, 0, mx) }
        var h: Double
        if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
        else if mx == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        h /= 6
        if h < 0 { h += 1 }
        return (h, d / mx, mx)
    }

    /// The image scaled to `side` x `side`, as premultiplied RGBA bytes.
    private static func rgba(of image: CGImage) -> [UInt8]? {
        var data = [UInt8](repeating: 0, count: side * side * 4)
        let ok = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return ok ? data : nil
    }
}
