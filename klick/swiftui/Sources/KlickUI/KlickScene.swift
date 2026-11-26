// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import KlickKit
import AppearanceKit
import UpdateKit

/// The window of the application and its menus. An application of the family is this scene and its configuration.
public struct KlickScene: Scene {
    private let application: KlickApplication

    public init(application: KlickApplication) {
        self.application = application
    }

    private var model: AppModel { application.model }

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(application)
                .environment(application.model)
                .environment(application.appearance)
                .appAccent(application.appearance)
                .frame(minWidth: 1100, minHeight: 740)
        }
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .importExport) {}
            CommandGroup(replacing: .printItem) {}
            CommandGroup(replacing: .textEditing) {}
            CommandGroup(replacing: .textFormatting) {}
            CommandGroup(replacing: .toolbar) {
                Button("Métronome") { model.show(.metronome) }.keyboardShortcut("1", modifiers: .command)
                Button("Carte de tempo") { model.show(.map) }.keyboardShortcut("2", modifiers: .command)
                Divider()
                Button("Sons") { model.show(.sounds) }.keyboardShortcut("3", modifiers: .command)
                Button("Sortie") { model.show(.output) }.keyboardShortcut("4", modifiers: .command)
                Button("Exporter") { model.show(.export) }.keyboardShortcut("5", modifiers: .command)
                Button("Affichage") { model.show(.appearance) }.keyboardShortcut("6", modifiers: .command)
            }
            // The settings of the system convention (command comma) are the page "Affichage".
            CommandGroup(replacing: .appSettings) {
                Button("Réglages…") { model.show(.appearance) }.keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Lecture") {
                Button(LocalizedStringKey(model.isPlaying ? "Arrêter" : "Démarrer")) { model.togglePlayback() }.keyboardShortcut("r", modifiers: .command)
                Button(LocalizedStringKey(model.showsLiveView ? "Configuration" : "Vue simplifiée")) {
                    if model.showsLiveView { model.leaveLiveView() } else { model.enterLiveView() }
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(!model.isPlaying)
                Toggle("Silencieux", isOn: Binding(get: { model.settings.isQuiet }, set: { model.settings.isQuiet = $0 })).keyboardShortcut("m", modifiers: [.command, .option])
            }
        }
        .commands {
            CollectionMenus(about: application.configuration.about, appearance: application.appearance,
                            documentationTitle: application.configuration.documentationTitle,
                            documentationURL: application.configuration.documentationURL)
            // After the "About" group that the menus of the collection replace, so that it stays.
            UpdateCommands(controller: application.updates)
        }
    }
}
