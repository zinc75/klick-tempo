// SPDX-License-Identifier: MIT

import SwiftUI

/// One point of the matrix. On macOS 26 it is a Liquid Glass disc that gives under the click, tinted
/// as JackMate paints its LEDs; before, the same look drawn flat. Lit: red #ef4444, outline at
/// 50 % (1 pt), glow at 55 % (radius 4). Off: dark grey #2c2c2e, white outline at 6 %, no glow.
public struct LED: View {
    let isOn: Bool
    var onHover: (Bool) -> Void = { _ in }
    let action: () -> Void

    public init(isOn: Bool, onHover: @escaping (Bool) -> Void = { _ in }, action: @escaping () -> Void) {
        self.isOn = isOn
        self.onHover = onHover
        self.action = action
    }

    @Environment(\.colorScheme) private var scheme
    @State private var isHovered = false

    private var isDark: Bool { scheme == .dark }
    /// Dark mode: #2c2c2e. Light mode: a light grey, so that the unlit dot looks like a recess, not a hole.
    private var fill: Color { isOn ? .ledOn : (isDark ? .ledOffFill : Color(white: 0.0, opacity: 0.07)) }
    /// Under the pointer the outline gets stronger and the dot swells a little.
    private var outline: Color {
        if isOn { return Color.ledOn.opacity(isHovered ? 0.9 : 0.5) }
        let base = isDark ? Color.white : Color.black
        return base.opacity(isHovered ? (isDark ? 0.35 : 0.30) : (isDark ? 0.06 : 0.14))
    }
    private var glow: Color { isOn ? Color.ledOn.opacity((isHovered ? 0.8 : 0.55) * (isDark ? 1 : 0.7)) : .clear }

    public var body: some View {
        Button(action: action) {
            dot
                .shadow(color: glow, radius: isHovered ? 5 : 4)
                .scaleEffect(isHovered ? 1.2 : 1)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2, bounce: 0.35)) { isHovered = hovering }
            onHover(hovering)
        }
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? Text("on") : Text("off"))
    }

    @ViewBuilder private var dot: some View {
        if #available(macOS 26, *), GlassSupport.enabled {
            Color.clear
                .frame(width: 16, height: 16)
                .glassEffect(.regular.tint(fill).interactive(), in: .circle)
                .overlay(Circle().strokeBorder(outline, lineWidth: 1))
        } else {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(outline, lineWidth: 1))
                .frame(width: 16, height: 16)
        }
    }
}

extension Color {
    /// The lit colour of the matrix points: red, #ef4444. Lighting a point arms the recording of that source,
    /// as the record button does.
    public static let ledOn = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    /// The unlit fill of the matrix points: #2c2c2e.
    public static let ledOffFill = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
}
