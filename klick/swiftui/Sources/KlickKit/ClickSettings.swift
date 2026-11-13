// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// The sound of the clicks: one of the four built in klick, or two files.
public enum ClickSound: Codable, Equatable, Sendable {
    case builtIn(BuiltIn)
    case files(accent: String, normal: String)

    /// The numbers are those of `klick -s`.
    public enum BuiltIn: Int, Codable, CaseIterable, Sendable {
        case square = 0, sine = 1, noise = 2, click = 3

        /// Base name of the files in the sounds directory.
        public var fileName: String {
            switch self {
            case .square: return "square"
            case .sine: return "sine"
            case .noise: return "noise"
            case .click: return "click"
            }
        }
    }
}

/// The speed trainer: the tempo rises by `step` every `everyBars` bars, up to `target`.
public struct SpeedTrainer: Codable, Equatable, Sendable {
    public var isEnabled = false
    public var target = 140.0
    public var step = 1.0
    public var everyBars = 8

    public init() {}

    /// For the engine: increment in quarter notes per bar, and limit (both 0 when off).
    public var engineIncrement: Double { isEnabled && everyBars > 0 ? step / Double(everyBars) : 0 }
    public var engineLimit: Double { isEnabled ? target : 0 }

    /// Seconds to get from `tempo` to the target, `nil` when the trainer is off or never gets there.
    public func duration(from tempo: Double, beats: Int, denominator: Int) -> Double? {
        guard isEnabled, step > 0, everyBars > 0, target > tempo else { return nil }
        var seconds = 0.0, current = tempo
        while current < target {
            seconds += Double(everyBars * beats) * 60 / current * 4 / Double(denominator)
            current += step
        }
        return seconds
    }
}

/// Everything the user sets for the simple metronome and for the sounds, kept between launches.
public struct ClickSettings: Codable, Equatable, Sendable {
    public var tempo = 120.0
    public var beats = 4
    public var denominator = 4
    public var pattern = "Xxxx"
    public var sound = ClickSound.builtIn(.square)
    public var accentVolume = 0.9
    public var normalVolume = 0.65
    /// Pitch of the sounds, in semitones.
    public var pitch = 0.0
    public var masterVolume = 0.8
    public var countIn = CountIn.none
    /// The count-in is heard (about two thirds of the volume of the clicks) or only seen.
    public var isCountInAudible = false
    /// Visual only: no click is heard.
    public var isQuiet = false
    public var trainer = SpeedTrainer()
    /// Delay of the display, in milliseconds, by name of output device: some outputs (Bluetooth) delay the sound more than they
    /// say, and the lamps then wait for it. Adjusted by ear.
    public var displayOffsets: [String: Double] = [:]
    /// The output device chosen in the application, by its identifier; `nil` follows the output of the system.
    public var outputDeviceUID: String?
    /// The backend chosen (`AudioBackend.id`); `nil` is the first one the application offers.
    public var backendID: String?
    /// The settings of the backends, by backend id and key: what a backend that comes from another library keeps (for JACK: the
    /// port to connect to, the connection at start, ...). The application does not know the keys.
    public var backendOptions: [String: [String: String]] = [:]

    public init() {}

    /// Settings written by an older version lack the keys of what was added since: those keep their default value.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tempo = try c.decodeIfPresent(Double.self, forKey: .tempo) ?? tempo
        beats = try c.decodeIfPresent(Int.self, forKey: .beats) ?? beats
        denominator = try c.decodeIfPresent(Int.self, forKey: .denominator) ?? denominator
        pattern = try c.decodeIfPresent(String.self, forKey: .pattern) ?? pattern
        sound = try c.decodeIfPresent(ClickSound.self, forKey: .sound) ?? sound
        accentVolume = try c.decodeIfPresent(Double.self, forKey: .accentVolume) ?? accentVolume
        normalVolume = try c.decodeIfPresent(Double.self, forKey: .normalVolume) ?? normalVolume
        pitch = try c.decodeIfPresent(Double.self, forKey: .pitch) ?? pitch
        masterVolume = try c.decodeIfPresent(Double.self, forKey: .masterVolume) ?? masterVolume
        countIn = try c.decodeIfPresent(CountIn.self, forKey: .countIn) ?? countIn
        isCountInAudible = try c.decodeIfPresent(Bool.self, forKey: .isCountInAudible) ?? isCountInAudible
        isQuiet = try c.decodeIfPresent(Bool.self, forKey: .isQuiet) ?? isQuiet
        trainer = try c.decodeIfPresent(SpeedTrainer.self, forKey: .trainer) ?? trainer
        displayOffsets = try c.decodeIfPresent([String: Double].self, forKey: .displayOffsets) ?? displayOffsets
        outputDeviceUID = try c.decodeIfPresent(String.self, forKey: .outputDeviceUID)
        backendID = try c.decodeIfPresent(String.self, forKey: .backendID)
        backendOptions = try c.decodeIfPresent([String: [String: String]].self, forKey: .backendOptions) ?? backendOptions
    }

    /// One setting of a backend; `nil` when it was never set.
    public func option(_ key: String, backend: String) -> String? { backendOptions[backend]?[key] }

    /// Sets one setting of a backend, or removes it with `nil`.
    public mutating func setOption(_ key: String, _ value: String?, backend: String) {
        var options = backendOptions[backend] ?? [:]
        options[key] = value
        backendOptions[backend] = options.isEmpty ? nil : options
    }

    /// Changes the number of beats and keeps the pattern valid.
    public mutating func setBeats(_ n: Int) {
        beats = n
        pattern = MapSection.resized(pattern: pattern, to: n)
    }

    /// Changes the beat unit; the number of beats follows the rules of `MeterRules`.
    public mutating func setDenominator(_ d: Int) {
        denominator = d
        setBeats(MeterRules.numerator(beats, for: d))
    }

    /// The two files of the sound, in the folder of the sounds of klick for a built-in one.
    public func soundFiles(in directory: URL) -> (accent: URL, normal: URL) {
        switch sound {
        case .builtIn(let built):
            return (directory.appendingPathComponent("\(built.fileName)_emphasis.wav"), directory.appendingPathComponent("\(built.fileName)_normal.wav"))
        case .files(let accent, let normal):
            return (URL(fileURLWithPath: accent), URL(fileURLWithPath: normal))
        }
    }

    /// Pitch as the factor klick takes (`-w`).
    public var pitchFactor: Double { pow(2, pitch / 12) }
}
