// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import KlickUI
import AppearanceKit

/// Klick Tempo, the application with CoreAudio only: its name, its colour (a warm orange, the orange of the system is yellower) and CoreAudio. All the rest is in
/// KlickUI, which an application of the family shares.
@main
struct KlickTempoApp: App {
    @NSApplicationDelegateAdaptor(KlickAppDelegate.self) private var appDelegate
    @State private var application: KlickApplication

    init() {
        let configuration = KlickConfiguration(title: "Klick Tempo", subtitle: "Metronome for macOS", accent: .orange,
                                               accentColor: Color(red: 1.0, green: 0.42, blue: 0.10))
        _application = State(initialValue: KlickApplication(configuration: configuration))
    }

    var body: some Scene {
        KlickScene(application: application)
    }
}
