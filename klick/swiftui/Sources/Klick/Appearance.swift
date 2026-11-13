// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import AppearanceKit

/// A sun or a moon in the toolbar of the live view: it shows the look a click goes to. The choice itself, with the accent,
/// is in the settings window (the same for every application of the collection, see AppearanceKit).
struct AppearanceButton: View {
    /// On macOS 26 the button draws the glass disc itself, as it is kept out of the capsule of its neighbours.
    var ownGlass = false
    @Environment(AppearanceSettings.self) private var appearance
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            appearance.mode = appearance.toggled(currentlyDark: scheme == .dark)
        } label: {
            Image(systemName: scheme == .dark ? "sun.max" : "moon")
                .frame(width: ownGlass ? 30 : nil, height: ownGlass ? 30 : nil)
                .modifier(OwnGlass(enabled: ownGlass))
        }
        .buttonStyle(.plain)
        .help(LocalizedStringKey(scheme == .dark ? "Passer en mode clair" : "Passer en mode sombre"))
        .accessibilityLabel("Clair ou sombre")
    }
}

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
