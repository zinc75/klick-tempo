// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import KlickEngine
import Observation

/// The pages of the window: the metronome and the tempo map first, then the settings.
public enum Page: String, CaseIterable, Sendable {
    case metronome, map, sounds, output, export, appearance
}

/// Where the settings are kept between two launches.
public protocol SettingsStore: AnyObject {
    func load() -> Data?
    func save(_ data: Data)
}

/// The preferences of the application.
public final class UserDefaultsStore: SettingsStore {
    private let defaults: UserDefaults
    private let key: String

    public init(_ defaults: UserDefaults = .standard, key: String = "settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> Data? { defaults.data(forKey: key) }
    public func save(_ data: Data) { defaults.set(data, forKey: key) }
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

    private let store: SettingsStore?

    /// The backends the application offers (CoreAudio; JACK too in the version that has it); the first is the default.
    public let backends: [AudioBackend]
    /// The one the engine plays on.
    public private(set) var backend: AudioBackend

    /// `store` is where the settings are kept (`nil` to keep nothing). `backends` are the outputs on offer (CoreAudio alone when `nil`), the first one by default;
    /// the one that was chosen last time is taken again when it is on offer and the engine of `player` is not on it.
    public init(player: Player, store: SettingsStore?, backends offered: [AudioBackend]? = nil) {
        let backends = offered ?? [CoreAudioBackend()]
        precondition(!backends.isEmpty, "an application needs a backend")
        self.player = player
        self.store = store
        self.backends = backends
        self.backend = backends[0]
        self.document = TempoMapDocument(sections: [MapSection(label: "intro", bars: 8, tempo: 120)])
        if let data = store?.load(), let saved = try? JSONDecoder().decode(ClickSettings.self, from: data) {
            settings = saved
        }
        selectedSection = 0
        // The backend of the player when it is one of those on offer (an application starts on CoreAudio, then moves to the one it
        // kept); else the one that was kept, else the first.
        if let current = backends.first(where: { $0.id == player.backendID }) { backend = current }
        if let kept = settings.backendID, let wanted = backends.first(where: { $0.id == kept }), wanted.id != backend.id {
            switchBackend(to: wanted.id)
        }
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
        liveViewWanted = false
        if page == .metronome { lastMode = .simple } else if page == .map { lastMode = .map }
    }

    // MARK: playback

    /// True while the metronome or the map plays; the short clicks of the sounds page are not playing.
    public var isPlaying: Bool { player.isPlaying && !isPreviewing }

    private var liveViewWanted = false

    /// While it plays, the window can show only what the player needs: the tempo, the beats, the section. It opens by itself
    /// when the metronome or the map starts, and closes when it stops or when a page is chosen.
    public var showsLiveView: Bool { liveViewWanted && isPlaying }

    /// The button "Vue simplifiée".
    public func enterLiveView() { liveViewWanted = isPlaying }

    /// The button "Configuration", the key Escape: back to the page of what plays (the metronome or the map), not to the last page
    /// that was open.
    public func leaveLiveView() {
        show((player.mode ?? lastMode) == .map ? .map : .metronome)
    }

    public func togglePlayback() {
        isPlaying ? stop() : start(mode)
    }

    // MARK: listening to a sound

    public enum Preview: Sendable { case accent, normal, bar }

    public private(set) var isPreviewing = false
    private var previewTask: Task<Void, Never>?

    /// Plays one accent, one normal click or a bar of four with `sound` and the volumes and pitch that are set, then stops. Not
    /// while the metronome plays: its click is heard already.
    public func preview(_ what: Preview, sound: ClickSound) {
        guard !isPlaying else { return }
        endPreview()
        var s = settings
        s.sound = sound
        s.isQuiet = false
        s.countIn = .none
        s.tempo = 120
        s.denominator = 4
        s.trainer = SpeedTrainer()
        let seconds: Double
        switch what {
        case .accent: s.beats = 1; s.pattern = "X"; seconds = 0.45
        case .normal: s.beats = 1; s.pattern = "x"; seconds = 0.45
        case .bar: s.beats = 4; s.pattern = "Xxxx"; seconds = 2.1
        }
        do {
            try player.start(.simple, settings: s)
            isPreviewing = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        previewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.endPreview()
        }
    }

    private func endPreview() {
        previewTask?.cancel(); previewTask = nil
        if isPreviewing { player.stop() }
        isPreviewing = false
    }

    /// The section the map page puts forward: the one that is heard while the map plays (it follows the playing), else the one
    /// the user selected.
    public var activeSection: Int? {
        if isPlaying, player.mode == .map, player.phase == .playing { return player.sectionIndex }
        return selectedSection
    }

    /// Where the tempo map starts, in bars from its beginning: the cursor of the timeline. It stays where the user put it.
    public private(set) var mapStartBar = 0

    /// The first bar of a section, counted from the start of the map.
    public func bar(ofSection index: Int) -> Int {
        document.sections.prefix(index).reduce(0) { $0 + $1.bars }
    }

    /// Puts the cursor on a bar of the map (a map that plays starts again from there).
    public func moveMapCursor(toBar bar: Int) {
        let clamped = min(max(0, bar), max(0, document.totalBars - 1))
        mapStartBar = clamped
        if isPlaying && player.mode == .map { start(.map) }
    }

    /// Starts the tempo map from one of its sections (a map already playing starts again from there).
    public func startMap(from section: Int) {
        mapStartBar = bar(ofSection: section)
        start(.map)
    }

    public func start(_ mode: Mode) {
        endPreview()
        // Only a start from the metronome or the map opens the live view; the settings pages stay, to hear what is changed.
        if !isPlaying { liveViewWanted = page == .metronome || page == .map }
        do {
            if mode == .map { try player.setMap(document.sections, startingAtBar: mapStartBar) }
            try player.start(mode, settings: settings)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func stop() {
        endPreview()
        player.stop()
        liveViewWanted = false
    }

    // MARK: settings and tempo map

    private func settingsChanged() {
        if let store, let data = try? JSONEncoder().encode(settings) { store.save(data) }
        player.displayOffsetMilliseconds = settings.displayOffsets[outputName] ?? 0
        guard isPlaying else { return }
        do { try player.apply(settings) } catch { errorMessage = error.localizedDescription }
    }

    /// Name of the output in use: the key of the display offsets. Set by the application when it knows it.
    public var outputName = "default" {
        didSet { player.displayOffsetMilliseconds = settings.displayOffsets[outputName] ?? 0 }
    }

    /// What the output in use says about itself, read again by `refreshOutput`.
    public private(set) var output = OutputInfo()

    /// The output devices the user can choose (CoreAudio), read again by `refreshOutput`; empty on another backend.
    public var outputDevices: [OutputDevice] { (backend as? CoreAudioBackend)?.devices ?? [] }
    /// The output chosen in the application is not there (unplugged): the output of the system plays meanwhile (CoreAudio).
    public var isChosenOutputMissing: Bool { (backend as? CoreAudioBackend)?.isChosenOutputMissing ?? false }

    /// Chooses an output device by its identifier, or, with `nil`, the output of the system (CoreAudio).
    public func chooseOutput(uid: String?) {
        settings.outputDeviceUID = uid
        refreshOutput()
    }

    /// Asks the backend to put the engine on the output that is wanted, and reads what plays: its name is the key of the display
    /// offset. Called now and then.
    public func refreshOutput() {
        guard let info = backend.refresh(player: player, host: self), info != output else { return }
        output = info
        outputName = backend.displayOffsetKey(for: info)
    }

    /// Plays on another backend: what plays stops, the engine is made again on the new backend and the settings reach it. The
    /// choice is kept. A backend that cannot be used (or whose engine cannot be made) leaves things as they are, with the reason
    /// shown.
    public func switchBackend(to id: String) {
        guard let new = backends.first(where: { $0.id == id }), new.id != backend.id || player.backendID != new.id else { return }
        if case .unavailable(let reason) = new.availability {
            errorMessage = reason
            return
        }
        stop()
        do {
            let engine = try new.makeEngine()
            player.replaceEngine(engine)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        backend = new
        settings.backendID = new.id
        output = OutputInfo()
        errorMessage = nil
        refreshOutput()
    }

    /// The delay of the display for the output in use, in milliseconds (0 when none was set).
    public var displayOffset: Double {
        get { settings.displayOffsets[outputName] ?? 0 }
        set {
            if newValue == 0 { settings.displayOffsets[outputName] = nil } else { settings.displayOffsets[outputName] = newValue }
        }
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

    // MARK: tempo map document

    /// Where the maps are kept unless the user chooses otherwise: `~/Documents/Klick`.
    public static var defaultMapsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Klick", isDirectory: true)
    }

    /// A new map: one section, as at launch.
    public func newMap() {
        document = TempoMapDocument(sections: [MapSection(label: "intro", bars: 8, tempo: 120)])
        selectedSection = 0
        mapStartBar = 0
    }

    /// Opens an example as a new map: it has no file, so saving asks for one and the example itself is never changed.
    public func openExample(_ example: ExampleMap, in directory: URL) throws {
        let sections = try example.sections(in: directory)
        guard !sections.isEmpty else { throw TempoMapFile.ParseError(line: 0, text: "", message: "no section") }
        document = TempoMapDocument(sections: sections, suggestedName: example.title)
        selectedSection = 0
        mapStartBar = 0
    }

    /// Opens a file; the map in use is left alone when it cannot be read.
    public func openMap(at url: URL) throws {
        let opened = try TempoMapDocument(contentsOf: url)
        guard !opened.sections.isEmpty else { throw TempoMapFile.ParseError(line: 0, text: "", message: "no section") }
        document = opened
        selectedSection = 0
        mapStartBar = 0
    }

    /// Saves to the file the map comes from, or to `url`.
    public func saveMap(to url: URL? = nil) throws {
        try document.save(to: url)
    }

    /// Changes one section.
    public func updateSection(at index: Int, _ change: (inout MapSection) -> Void) {
        guard document.sections.indices.contains(index) else { return }
        edit { change(&$0.sections[index]) }
    }

    /// Adds a section after the selected one and selects it.
    public func addSection(_ section: MapSection) {
        edit { selectedSection = $0.insert(section, after: selectedSection) }
    }

    /// Removes a section; the last one cannot be removed.
    public func removeSection(at index: Int) {
        guard document.sections.count > 1, document.sections.indices.contains(index) else { return }
        edit { $0.sections.remove(at: index) }
    }

    /// Replaces the sections of the map; applied to the player at the next start.
    public func edit(_ change: (inout TempoMapDocument) -> Void) {
        change(&document)
        if mapStartBar >= document.totalBars { mapStartBar = 0 }
        if let selected = selectedSection, selected >= document.sections.count { selectedSection = document.sections.indices.last }
    }
}

extension AppModel: BackendHost {}
