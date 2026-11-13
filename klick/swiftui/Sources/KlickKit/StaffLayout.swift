// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// Where the signs of one bar go on a single-line percussion staff: a note for each beat (accent mark, rest for a silent beat),
/// beams for the eighth and sixteenth notes grouped as the meter asks. Coordinates in a drawing 74 high (the line at 46) and
/// `width` wide; the view only draws what is listed here.
public struct StaffLayout: Equatable, Sendable {
    public struct Beam: Equatable, Sendable {
        public var x1: Double, x2: Double
        /// 0 for the first beam, 1 for the second (sixteenth notes).
        public var level: Int
    }

    public struct Flag: Equatable, Sendable {
        public var x: Double
        public var level: Int
    }

    public static let height = 74.0
    public static let lineY = 46.0
    public static let stemHeight = 26.0
    public static let beamWidth = 4.0

    public let width: Double
    public let showsSignature: Bool
    public let beats: Int
    public let denominator: Int
    /// Horizontal position of each beat.
    public private(set) var noteX: [Double] = []
    /// Beats that are notes (not rests), with their accent.
    public private(set) var accented: Set<Int> = []
    public private(set) var rests: Set<Int> = []
    public private(set) var beams: [Beam] = []
    public private(set) var flags: [Flag] = []
    /// Half notes (a denominator of 2) have an open head.
    public let hasOpenHeads: Bool
    /// Where the beam of a group ends and a stem is drawn, for each note beamed or not.
    public static func stemX(_ noteX: Double) -> Double { noteX + 5 }

    public init(beats: Int, denominator: Int, pattern: String, width: Double = 360, showsSignature: Bool = true) {
        self.width = width
        self.showsSignature = showsSignature
        self.beats = max(beats, 1)
        self.denominator = denominator
        self.hasOpenHeads = denominator == 2
        let chars = Array(pattern)
        let left = showsSignature ? 46.0 : 14.0
        let step = (width - left - 22) / Double(self.beats)
        noteX = (0..<self.beats).map { left + step * (Double($0) + 0.5) }
        for i in 0..<self.beats {
            let c = i < chars.count ? chars[i] : "x"
            if c == "." { rests.insert(i) } else if c == "X" { accented.insert(i) }
        }
        guard denominator >= 8 else { return }
        var start = 0
        for size in MeterRules.groups(beats: self.beats, denominator: denominator) {
            let notes = (start..<min(start + size, self.beats)).filter { !rests.contains($0) }
            if notes.count > 1 {
                let x1 = Self.stemX(noteX[notes.first!]), x2 = Self.stemX(noteX[notes.last!])
                beams.append(Beam(x1: x1, x2: x2, level: 0))
                if denominator == 16 { beams.append(Beam(x1: x1, x2: x2, level: 1)) }
            } else if let only = notes.first {
                flags.append(Flag(x: Self.stemX(noteX[only]), level: 0))
                if denominator == 16 { flags.append(Flag(x: Self.stemX(noteX[only]), level: 1)) }
            }
            start += size
        }
    }
}
