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
///
/// A window without the focus gets its Liquid Glass drawn flat by the system. Then (macOS 26 only) the block is a drawn
/// look that keeps some relief: see `InactiveGlassFill`. The shadow of the glass is soft: 40 % of the one that a block of
/// plain glass would cast, which looked heavy.
public struct BlockBackground: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var scheme
    @Environment(\.appearsActive) private var appearsActive

    public init(cornerRadius: CGFloat) { self.cornerRadius = cornerRadius }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let light = scheme == .light
        if #available(macOS 26, *), GlassSupport.enabled {
            if appearsActive {
                let shadowCaster = shape
                    .fill(Color.windowFill)
                    .shadow(color: .black.opacity((light ? 0.16 : 0.12) * 0.4), radius: (light ? 5 : 4) * 0.4, y: 1)
                content
                    .glassEffect(.regular.tint(light ? Color.lightGlassTint : Color.darkGlassTint), in: shape)
                    .background { shadowCaster }
                    .overlay { if light { shape.strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5) } }
            } else {
                content.background { InactiveGlassFill(shape: shape) }
            }
        } else {
            let shadowCaster = shape
                .fill(Color.windowFill)
                .shadow(color: .black.opacity(light ? 0.16 : 0.12), radius: light ? 5 : 4, y: 1)
            content
                .background(.thickMaterial, in: shape)
                .background { shadowCaster }
                .overlay(shape.strokeBorder(light ? Color.black.opacity(0.10) : .white.opacity(0.10), lineWidth: 0.5))
        }
    }
}

/// What a glass surface looks like in a window without the focus, where the system draws Liquid Glass flat: the colour of the
/// window, darkened by a gradient (a little in light mode, where the glass is tinted grey), and a lit edge. The same for the
/// blocks and for the sidebar, so that they have the same tint.
struct InactiveGlassFill<S: InsettableShape>: View {
    let shape: S
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if scheme == .dark {
            ZStack {
                shape.fill(Color.windowFill)
                shape.fill(LinearGradient(colors: [.black.opacity(0.09), .black.opacity(0.126)], startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
            }
        } else {
            ZStack {
                shape.fill(Color.windowFill)
                shape.fill(LinearGradient(colors: [.black.opacity(0.02), .black.opacity(0.028)], startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(LinearGradient(colors: [.black.opacity(0.12), .black.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
            }
        }
    }
}

private struct SidebarFill: View {
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        if !appearsActive {
            InactiveGlassFill(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)).ignoresSafeArea()
        }
    }
}

extension View {
    /// For the list of a sidebar: when the window has not the focus the sidebar, a glass panel that the system draws flat, gets the
    /// drawn look of the blocks (macOS 26). The list is made transparent for it. Elsewhere the sidebar is left as the system draws it.
    @ViewBuilder
    public func inactiveSidebarFill() -> some View {
        if #available(macOS 26, *), GlassSupport.enabled {
            self.scrollContentBackground(.hidden).background { SidebarFill() }
        } else {
            self
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

