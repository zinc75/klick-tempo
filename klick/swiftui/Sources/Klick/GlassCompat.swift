// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit

/// Liquid Glass on macOS 26, a close material look on macOS 15. The only place where the two differ,
/// so that no view has to test the system version.
extension View {
    /// An accent glass disc, for the round button.
    @ViewBuilder
    func accentGlassDisc(_ accent: Color) -> some View {
        if #available(macOS 26, *), GlassSupport.enabled {
            self
                .glassEffect(.regular.tint(accent), in: .circle)   // not interactive: that glass would take the click from the button
                .overlay { Circle().inset(by: 0.5).strokeBorder(.white.opacity(0.4), lineWidth: 0.75) }
                .overlay { Circle().strokeBorder(.black.opacity(0.5), lineWidth: 0.5) }
                .overlay(alignment: .top) {
                    Ellipse().fill(.white.opacity(0.28)).frame(width: 32, height: 12).offset(y: 5).blur(radius: 2.5)
                }
        } else {
            self.background {
                Circle()
                    .fill(LinearGradient(colors: [accent.opacity(0.78), accent, accent.opacity(0.62)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().inset(by: 0.5).strokeBorder(.white.opacity(0.55), lineWidth: 0.5))
                    .overlay(Circle().strokeBorder(.black.opacity(0.5), lineWidth: 0.5))
                    .overlay(alignment: .top) {
                        Ellipse().fill(.white.opacity(0.35)).frame(width: 30, height: 14).offset(y: 5).blur(radius: 3)
                    }
                    .shadow(color: accent.opacity(0.4), radius: 8, y: 4)
            }
        }
    }
}
