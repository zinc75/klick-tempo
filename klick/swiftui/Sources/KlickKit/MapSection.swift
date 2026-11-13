// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import KlickEngine

/// One section of a tempo map, as the application edits it.
public struct MapSection: Identifiable, Equatable, Sendable {
    /// Identity for lists; it plays no part in comparisons.
    public var id = UUID()
    /// Letters, digits, `_` and `-` (what the file format allows); may be empty.
    public var label: String
    public var bars: Int
    public var beats: Int
    public var denominator: Int
    /// Quarter notes per minute.
    public var tempo: Double
    /// Tempo reached at the end of the section for a gradual change.
    public var tempoEnd: Double?
    /// One tempo per beat (`bars * beats` values), for a map that follows a performance; then `tempo` is the first of them
    /// and `tempoEnd` is not used.
    public var tempi: [Double]?
    /// One character per beat: `X` accent, `x` normal, `.` silent.
    public var pattern: String
    public var volume: Double
    /// A silent section keeps counting but makes no sound; in the file it is a volume of 0.
    public var muted: Bool

    public init(label: String = "", bars: Int = 4, beats: Int = 4, denominator: Int = 4, tempo: Double = 120,
                tempoEnd: Double? = nil, tempi: [Double]? = nil, pattern: String? = nil, volume: Double = 1, muted: Bool = false) {
        self.label = label; self.bars = bars; self.beats = beats; self.denominator = denominator
        self.tempi = tempi; self.tempo = tempi?.first ?? tempo
        self.tempoEnd = tempi == nil ? tempoEnd : nil; self.pattern = pattern ?? Self.defaultPattern(beats: beats); self.volume = volume; self.muted = muted
    }

    /// An accent on the first beat, then normal beats.
    public static func defaultPattern(beats: Int) -> String {
        "X" + String(repeating: "x", count: max(0, beats - 1))
    }

    /// The same pattern for another number of beats: kept where it fits, completed with normal beats.
    public static func resized(pattern: String, to beats: Int) -> String {
        let kept = String(pattern.prefix(beats))
        return kept.isEmpty ? defaultPattern(beats: beats) : kept + String(repeating: "x", count: beats - kept.count)
    }

    public static func isValid(pattern: String, beats: Int) -> Bool {
        pattern.count == beats && pattern.allSatisfy { "Xx.".contains($0) }
    }

    public static func isValid(label: String) -> Bool {
        label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }

    /// True when the section has one tempo per beat.
    public var hasTempoPerBeat: Bool { tempi != nil }

    /// Keeps the list of tempos at `bars * beats` values after a change of the number of bars or beats: cut, or completed with
    /// the last tempo. A section without such a list is left alone.
    public mutating func fitTempi() {
        guard var list = tempi, !list.isEmpty else { return }
        let wanted = bars * beats
        if list.count > wanted { list.removeLast(list.count - wanted) }
        while list.count < wanted { list.append(list.last ?? tempo) }
        tempi = list
        tempo = list[0]
    }

    /// What the engine plays.
    public var engineSection: Section {
        Section(label: label, bars: bars, beats: beats, denominator: denominator, tempo: tempo, tempoEnd: tempoEnd,
                pattern: pattern, volume: muted ? 0 : volume, tempi: tempi)
    }

    public static func == (a: MapSection, b: MapSection) -> Bool {
        a.label == b.label && a.bars == b.bars && a.beats == b.beats && a.denominator == b.denominator && a.tempo == b.tempo
            && a.tempoEnd == b.tempoEnd && a.tempi == b.tempi && a.pattern == b.pattern && a.volume == b.volume && a.muted == b.muted
    }
}
