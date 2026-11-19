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
        var about = AboutInfo(
            name: "Klick Tempo",
            // The version shown is the one of klick, then "macOS Edition"; the build number is not shown.
            version: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") macOS Edition",
            summary: String(localized: "Interface non officielle de klick, de Dominic Sacré."),
            lines: [String(localized: "Portage macOS et interface : Éric Bavu."), String(localized: "Licence GPL, version 2 ou ultérieure.")],
            copyright: "© 2026 Éric Bavu",
            sourceURL: URL(string: "https://github.com/zinc75/klick-tempo"),
            supportURL: URL(string: "https://buymeacoffee.com/zinc75"),
            licenseFile: "klick-COPYING.txt",
            licenseURL: URL(string: "https://www.gnu.org/licenses/old-licenses/gpl-2.0.html"))
        // Klick Tempo has its own repository and is not an application of the collection.
        about.collection = nil
        about.collectionURL = nil
        let configuration = KlickConfiguration(title: "Klick Tempo", subtitle: "Metronome for macOS", about: about,
                                               documentationTitle: String(localized: "Documentation Klick Tempo"),
                                               documentationURL: URL(string: "https://github.com/zinc75/klick-tempo")!,
                                               accent: .orange, accentColor: Color(red: 1.0, green: 0.42, blue: 0.10))
        _application = State(initialValue: KlickApplication(configuration: configuration))
    }

    var body: some Scene {
        KlickScene(application: application)
    }
}
