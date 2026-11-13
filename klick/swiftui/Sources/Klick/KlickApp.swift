// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import KlickEngine
import KlickKit

/// Removes the menus that the system adds by itself and that have nothing left in them.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pending = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run from the build folder, without a bundle, the application is not a regular one: make it so, and active.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        AppearanceChoice.saved.apply()
        prune()
        NotificationCenter.default.addObserver(forName: NSMenu.didAddItemNotification, object: nil, queue: .main) { [weak self] _ in
            self?.schedule()
        }
    }

    private func schedule() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.async { [self] in
            pending = false
            prune()
        }
    }

    private func prune() {
        guard let main = NSApp.mainMenu else { return }
        for item in main.items.dropFirst() {
            guard let submenu = item.submenu else { continue }
            if submenu.items.allSatisfy({ $0.isSeparatorItem || $0.isHidden }) { main.removeItem(item) }
        }
    }
}

@main
struct KlickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    /// The sounds of klick: in the application bundle; in a development run, where the build scripts put them.
    static var soundsDirectory: URL {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("klick/samples"),
           FileManager.default.fileExists(atPath: bundled.path) { return bundled }
        if let path = ProcessInfo.processInfo.environment["KLICK_SOUNDS"] { return URL(fileURLWithPath: path) }
        // .../klick/swiftui/Sources/Klick/KlickApp.swift -> .../klick/build/samples
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/samples")
    }

    /// The settings of the last session come back; a development run can ask for a fresh start.
    private static var keepsSettings: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["KLICK_FRESH"] == nil
        #else
        return true
        #endif
    }

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
        var failure: String?
        let engine: Engine
        do {
            engine = try Engine()
        } catch {
            // No output device: the window opens, silent, with the reason on top.
            failure = error.localizedDescription
            engine = try! Engine(offline: true)
        }
        let player = Player(engine: engine, soundsDirectory: Self.soundsDirectory)
        let model = AppModel(player: player, store: Self.keepsSettings ? UserDefaultsStore() : nil)
        model.errorMessage = failure
        #if DEBUG
        // Development aids: KLICK_METER=5/8 and KLICK_PATTERN=X.xxx set the meter and the pattern of the run.
        if let meter = ProcessInfo.processInfo.environment["KLICK_METER"]?.split(separator: "/").compactMap({ Int($0) }), meter.count == 2 {
            model.settings.setDenominator(meter[1]); model.settings.setBeats(meter[0])
        }
        if let pattern = ProcessInfo.processInfo.environment["KLICK_PATTERN"], MapSection.isValid(pattern: pattern, beats: model.settings.beats) {
            model.settings.pattern = pattern
        }
        #endif
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 940, minHeight: 700)
        }
        .defaultSize(width: 1120, height: 780)
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
            }
            CommandGroup(replacing: .help) {}
            CommandMenu("Lecture") {
                Button(model.isPlaying ? "Arrêter" : "Démarrer") { model.togglePlayback() }.keyboardShortcut("r", modifiers: .command)
                Toggle("Silencieux", isOn: Binding(get: { model.settings.isQuiet }, set: { model.settings.isQuiet = $0 })).keyboardShortcut("m", modifiers: [.command, .option])
            }
        }
    }
}
