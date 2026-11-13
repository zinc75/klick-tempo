// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import KlickEngine
import Observation

/// The pages of the window: the metronome and the tempo map first, then the settings.
public enum Page: String, CaseIterable, Sendable {
    case metronome, map, sounds, output, export
}

/// Everything the window shows and changes: the page, the settings, the tempo map, the player. The views only read it and call it.
@MainActor
@Observable
public final class AppModel {
    public var page = Page.metronome
    /// Kept between two launches; a change reaches the engine at once, also while it plays.
    public var settings = ClickSettings() {
        didSet { if settings != oldValue { settingsChanged() } }
    }
    public private(set) var document: TempoMapDocument
    public private(set) var selectedSection: Int?
    public let player: Player
    /// A failure to start or to apply a setting, shown at the top of the page until it is closed.
    public var errorMessage: String?
    /// What the play button of the settings pages starts: the last of the metronome and the map that was shown.
    public private(set) var lastMode = Mode.simple

    private let defaults: UserDefaults?
    private static let settingsKey = "settings"

    /// `defaults` is where the settings are kept (`nil` to keep nothing).
    public init(player: Player, defaults: UserDefaults?) {
        self.player = player
        self.defaults = defaults
        self.document = TempoMapDocument(sections: [MapSection(label: "intro", bars: 8, tempo: 120)])
        if let data = defaults?.data(forKey: Self.settingsKey), let saved = try? JSONDecoder().decode(ClickSettings.self, from: data) {
            settings = saved
        }
        selectedSection = 0
    }

    // MARK: pages and modes

    /// The metronome or the map: what the play button starts on the current page.
    public var mode: Mode {
        switch page {
        case .metronome: return .simple
        case .map: return .map
        default: return lastMode
        }
    }

    /// The choice of the footer on the settings pages; what plays follows at once.
    public func choose(_ mode: Mode) {
        lastMode = mode
        if isPlaying && player.mode != mode { start(mode) }
    }

    public func show(_ page: Page) {
        self.page = page
        if page == .metronome { lastMode = .simple } else if page == .map { lastMode = .map }
    }

    // MARK: playback

    public var isPlaying: Bool { player.isPlaying }

    public func togglePlayback() {
        isPlaying ? stop() : start(mode)
    }

    public func start(_ mode: Mode) {
        do {
            if mode == .map { try player.setMap(document.sections) }
            try player.start(mode, settings: settings)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func stop() { player.stop() }

    // MARK: settings and tempo map

    private func settingsChanged() {
        if let defaults, let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.settingsKey) }
        player.displayOffsetMilliseconds = settings.displayOffsets[outputName] ?? 0
        guard isPlaying else { return }
        do { try player.apply(settings) } catch { errorMessage = error.localizedDescription }
    }

    /// Name of the output in use: the key of the display offsets. Set by the application when it knows it.
    public var outputName = "default" {
        didSet { player.displayOffsetMilliseconds = settings.displayOffsets[outputName] ?? 0 }
    }

    public func select(section index: Int?) { selectedSection = index }

    // MARK: tempo

    public static let tempoRange = 30.0...260.0

    /// Changes the tempo by `delta`, within the range of the interface.
    public func nudgeTempo(_ delta: Double) { settings.tempo = Self.clamped(settings.tempo + delta) }

    public static func clamped(_ tempo: Double) -> Double { min(tempoRange.upperBound, max(tempoRange.lowerBound, tempo.rounded())) }

    /// Tap tempo: the taps are kept here so that the key T and the pad of the page share them.
    public private(set) var tapTempo = TapTempo()

    public func tap(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) { tapTempo.tap(at: time) }

    public func resetTap() { tapTempo.reset() }

    /// Takes the tempo learned from the taps, from the third tap on.
    public func applyTap() {
        guard tapTempo.canApply, let bpm = tapTempo.bpm else { return }
        settings.tempo = Self.clamped(bpm)
    }

    /// Replaces the sections of the map; applied to the player at the next start.
    public func edit(_ change: (inout TempoMapDocument) -> Void) {
        change(&document)
        if let selected = selectedSection, selected >= document.sections.count { selectedSection = document.sections.indices.last }
    }
}
