// SPDX-License-Identifier: MIT

import SwiftUI

public enum GlassSupport {
    /// Debug builds can force the macOS 15 look on macOS 26 with JACKAPPS_LEGACY=1 (or JACKCAPTURE_LEGACY=1).
    public static let enabled: Bool = {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        return env["JACKAPPS_LEGACY"] == nil && env["JACKCAPTURE_LEGACY"] == nil
        #else
        return true
        #endif
    }()
}

/// Content scrolling under the transparent toolbar or the footer fades and blurs softly (macOS 26);
/// on macOS 15 the footer material and the toolbar's own look do the job.
extension View {
    @ViewBuilder
    public func softScrollEdges() -> some View {
        if #available(macOS 26, *), GlassSupport.enabled {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

/// The look of the blocks (form groups, cards): Liquid Glass over the plain window background on
/// macOS 26, a blurred material with a hairline before. The shadow is cast by a shape behind the
/// block, in the window colour, so that it never reaches the rows themselves.
extension View {
    public func blockBackground(cornerRadius: CGFloat = 12) -> some View {
        modifier(BlockBackground(cornerRadius: cornerRadius))
    }
}

/// The look of a block. The glass is tinted a little in both modes (grey in light mode, where it is also given
/// a hairline since it would otherwise vanish on a pale window; a little lighter in dark mode).
public struct BlockBackground: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var scheme

    public init(cornerRadius: CGFloat) { self.cornerRadius = cornerRadius }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        let light = scheme == .light
        let shadowCaster = shape
            .fill(Color.windowFill)
            .shadow(color: .black.opacity(light ? 0.16 : 0.12), radius: light ? 5 : 4, y: 1)
        if #available(macOS 26, *), GlassSupport.enabled {
            content
                .glassEffect(.regular.tint(light ? Color.lightGlassTint : Color.darkGlassTint), in: shape)
                .background { shadowCaster }
                .overlay { if light { shape.strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5) } }
        } else {
            content
                .background(.thickMaterial, in: shape)
                .background { shadowCaster }
                .overlay(shape.strokeBorder(light ? Color.black.opacity(0.10) : .white.opacity(0.10), lineWidth: 0.5))
        }
    }
}

extension Color {
    /// The background of the windows: the system colour, in light mode as in dark mode.
    public static let windowFill = Color(nsColor: .windowBackgroundColor)

    /// The tint of the glass of the blocks in dark mode: white, a little, to lift the blocks off the dark window.
    public static let darkGlassTint = Color(white: 1).opacity(0.015)

    /// The tint of the glass of the blocks in light mode: a light grey, no hue.
    public static let lightGlassTint = Color(white: 0.5).opacity(0.025)

    /// Warnings: violet. A bright lilac in dark mode (#D8BCFF); in light mode a deeper violet (#7C3AED), which
    /// can be read on a pale background.
    public static let alert = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.847, green: 0.737, blue: 1.0, alpha: 1)
            : NSColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1)
    })
}

extension View {
    /// A faint hairline around text fields, which otherwise melt into the block.
    public func fieldOutline() -> some View {
        overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.18), lineWidth: 0.5))
    }
}

