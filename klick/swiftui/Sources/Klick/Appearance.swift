// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI

/// The look of the application: dark for everybody, whatever the system says (it is how the Jack apps and JackMate look), and
/// light only by a click on the sun in the toolbar. Kept between two launches and applied to every window, the matrix included.
/// (The same in every application of the collection; to move to shared/ when a third application needs it.)
enum AppearanceChoice: String, CaseIterable {
    case light, dark

    static let key = "appearance"

    static var saved: AppearanceChoice {
        UserDefaults.standard.string(forKey: key).flatMap(AppearanceChoice.init(rawValue:)) ?? .dark
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    func apply() { NSApp.appearance = nsAppearance }
}

/// A sun or a moon in the toolbar: it shows the look a click goes to.
struct AppearanceButton: View {
    /// On macOS 26 the button draws the glass disc itself, as it is kept out of the capsule of its neighbours.
    var ownGlass = false
    @AppStorage(AppearanceChoice.key) private var stored = AppearanceChoice.dark.rawValue
    @Environment(\.colorScheme) private var scheme

    private var choice: Binding<AppearanceChoice> {
        Binding(get: { AppearanceChoice(rawValue: stored) ?? .dark }, set: { stored = $0.rawValue })
    }

    var body: some View {
        Button {
            choice.wrappedValue = scheme == .dark ? .light : .dark
        } label: {
            Image(systemName: scheme == .dark ? "sun.max" : "moon")
                .frame(width: ownGlass ? 30 : nil, height: ownGlass ? 30 : nil)
                .modifier(OwnGlass(enabled: ownGlass))
        }
        .buttonStyle(.plain)
        .help("Passer en mode \(scheme == .dark ? "clair" : "sombre")")
        .accessibilityLabel("Clair ou sombre")
        .onChange(of: stored) { choice.wrappedValue.apply() }
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
