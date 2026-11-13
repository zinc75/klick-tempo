// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI

/// A glass disc behind a toolbar button that is kept out of the capsule of its neighbours (macOS 26); nothing before.
struct OwnGlass: ViewModifier {
    let enabled: Bool
    var capsule = false

    func body(content: Content) -> some View {
        if enabled, #available(macOS 26, *) {
            if capsule { content.glassEffect(.regular.interactive(), in: .capsule) } else { content.glassEffect(.regular.interactive(), in: .circle) }
        } else {
            content
        }
    }
}
