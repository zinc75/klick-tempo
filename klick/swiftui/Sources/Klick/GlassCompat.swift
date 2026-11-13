// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit

/// Liquid Glass on macOS 26, a close material look on macOS 15. The only place where the two differ,
/// so that no view has to test the system version.
extension View {
    /// An accent glass disc, for the round button.
    @ViewBuilder
    func accentGlassDisc() -> some View {
        if #available(macOS 26, *), GlassSupport.enabled {
            self
                .glassEffect(.regular.tint(.accentColor), in: .circle)   // not interactive: that glass would take the click from the button
                .overlay { Circle().inset(by: 0.5).strokeBorder(.white.opacity(0.4), lineWidth: 0.75) }
                .overlay { Circle().strokeBorder(.black.opacity(0.4), lineWidth: 0.5) }
        } else {
            self.background {
                Circle()
                    .fill(LinearGradient(colors: [Color.accentColor.opacity(0.8), Color.accentColor, Color.accentColor.opacity(0.7)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().inset(by: 0.5).strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                    .overlay(Circle().strokeBorder(.black.opacity(0.4), lineWidth: 0.5))
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 4)
            }
        }
    }
}
