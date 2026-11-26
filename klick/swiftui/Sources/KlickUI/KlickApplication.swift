// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import Observation
import KlickEngine
import KlickKit
import AppearanceKit
import UpdateKit

/// What an application of the family holds while it runs: its configuration, the model of the window and the look the user chose.
/// Made once, before the first window.
@MainActor
@Observable
public final class KlickApplication {
    public let configuration: KlickConfiguration
    let model: AppModel
    let appearance: AppearanceSettings
    /// The search for a newer release; nil for an application that has no releases to look at.
    let updates: UpdateController?

    /// The settings of the last session come back; a development run can ask for a fresh start.
    private static var keepsSettings: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["KLICK_FRESH"] == nil
        #else
        return true
        #endif
    }

    public init(configuration: KlickConfiguration) {
        self.configuration = configuration
        CollectionMenus.disableSystemMenuAdditions()
        var failure: String?
        let engine: Engine
        do {
            engine = try Engine()
        } catch {
            // No output device: the window opens, silent, with the reason on top.
            failure = error.localizedDescription
            engine = try! Engine(offline: true)
        }
        let player = Player(engine: engine, soundsDirectory: KlickResources.soundsDirectory)
        // At the very first launch the map is an example, so that the page is not empty.
        let firstLaunch = Self.keepsSettings && UserDefaultsStore().load() == nil

        // The backends on offer: CoreAudio, then the ones the application adds. A development run can add an offline one to try the
        // choice of the backend (KLICK_TEST_BACKENDS=1): it makes no sound.
        var backends: [AudioBackend] = [CoreAudioBackend()]
        var interfaces: [BackendInterface] = [CoreAudioInterface()]
        for offer in configuration.additionalBackends {
            backends.append(offer.backend)
            interfaces.append(offer.interface)
        }
        #if DEBUG
        if ProcessInfo.processInfo.environment["KLICK_TEST_BACKENDS"] != nil { backends.append(OfflineBackend()) }
        #endif
        BackendRegistry.interfaces = interfaces

        let model = AppModel(player: player, store: Self.keepsSettings ? UserDefaultsStore() : nil, backends: backends)
        if firstLaunch, let first = ExampleMap.all.first { try? model.openExample(first, in: KlickResources.examplesDirectory) }
        model.errorMessage = failure
        #if DEBUG
        // Development aid: KLICK_BACKEND=jack plays on that backend from the start (with KLICK_FRESH=1 nothing is kept).
        if let id = ProcessInfo.processInfo.environment["KLICK_BACKEND"] { model.switchBackend(to: id) }
        // Development aids: KLICK_METER=5/8 and KLICK_PATTERN=X.xxx set the meter and the pattern of the run.
        if let meter = ProcessInfo.processInfo.environment["KLICK_METER"]?.split(separator: "/").compactMap({ Int($0) }), meter.count == 2 {
            model.settings.setDenominator(meter[1]); model.settings.setBeats(meter[0])
        }
        // KLICK_MAP=/path/to/file.klick opens that tempo map.
        if let path = ProcessInfo.processInfo.environment["KLICK_MAP"] { try? model.openMap(at: URL(fileURLWithPath: path)) }
        if let pattern = ProcessInfo.processInfo.environment["KLICK_PATTERN"], MapSection.isValid(pattern: pattern, beats: model.settings.beats) {
            model.settings.pattern = pattern
        }
        #endif
        self.model = model

        // The look is dark until the user says otherwise; the accent is the colour of the application.
        var defaults = UserDefaults.standard
        #if DEBUG
        // Development aids: KLICK_APPEARANCE=dark|system|light and KLICK_ACCENT=app|system|blue|purple|pink|red|orange|green
        // set the look of the run, in a store of their own that is not kept.
        let environment = ProcessInfo.processInfo.environment
        if environment["KLICK_APPEARANCE"] != nil || environment["KLICK_ACCENT"] != nil {
            defaults = UserDefaults(suiteName: "klick.debug.\(UUID().uuidString)") ?? defaults
            if let value = environment["KLICK_APPEARANCE"] { defaults.set(value, forKey: AppearanceSettings.modeKey) }
            if let value = environment["KLICK_ACCENT"] { defaults.set(value, forKey: AppearanceSettings.accentKey) }
        }
        #endif
        let appearance = AppearanceSettings(appAccent: configuration.accent, appColor: configuration.accentColor, defaults: defaults)
        KlickAppDelegate.appearance = appearance
        self.appearance = appearance

        // An installation would stop the metronome: it waits until it is stopped.
        if let repository = configuration.updateRepository, let prefix = configuration.updateTagPrefix {
            let updates = UpdateController(
                configuration: UpdateConfiguration(appName: configuration.title, repository: repository, tagPrefix: prefix, isBusy: { model.isPlaying }),
                appearance: appearance)
            self.updates = updates
            updates.startAutomaticChecks()
        } else {
            self.updates = nil
        }
    }
}
