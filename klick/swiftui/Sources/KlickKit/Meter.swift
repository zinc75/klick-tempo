// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// The meters offered by the interface: the numerators depend on the denominator.
public enum MeterRules {
    public static let denominators = [2, 4, 8, 16]

    private static let numerators: [Int: [Int]] = [
        2: [2, 3, 4],
        4: [2, 3, 4, 5, 6, 7, 8],
        8: [3, 5, 6, 7, 9, 12],
        16: [3, 5, 6, 7, 9, 12],
    ]

    /// Numerators for a denominator, plus `current` if it is not among them (a map may hold any meter).
    public static func numerators(for denominator: Int, including current: Int? = nil) -> [Int] {
        var list = numerators[denominator] ?? Array(1...16)
        if let current, !list.contains(current) { list.append(current); list.sort() }
        return list
    }

    /// The numerator to keep when the denominator changes: the same one if it exists, else the nearest.
    public static func numerator(_ current: Int, for denominator: Int) -> Int {
        let list = numerators(for: denominator)
        if list.contains(current) { return current }
        return list.min { abs($0 - current) < abs($1 - current) } ?? current
    }

    /// Beats of a bar that are counted together in a compound or asymmetric meter on eighth or sixteenth notes:
    /// 3+3 for 6, 9 and 12; 2 and 3 otherwise (5 = 2+3, 7 = 2+2+3).
    public static func groups(beats: Int, denominator: Int) -> [Int] {
        guard denominator >= 8, beats >= 2 else { return [beats] }
        if beats % 3 == 0 { return Array(repeating: 3, count: beats / 3) }
        if beats % 2 == 0 { return Array(repeating: 2, count: beats / 2) }
        return Array(repeating: 2, count: (beats - 3) / 2) + [3]
    }
}

/// The count-in before the metronome or the map starts.
public enum CountIn: String, Codable, CaseIterable, Sendable {
    case none, twoBeats, oneBar, twoBars, fourBars

    /// `bars` bars of `beatsPerBar` beats for the engine.
    public func engineParameters(beatsPerBar: Int) -> (bars: Int, beatsPerBar: Int) {
        switch self {
        case .none: return (0, beatsPerBar)
        case .twoBeats: return (1, 2)
        case .oneBar: return (1, beatsPerBar)
        case .twoBars: return (2, beatsPerBar)
        case .fourBars: return (4, beatsPerBar)
        }
    }

    public func beats(beatsPerBar: Int) -> Int {
        let p = engineParameters(beatsPerBar: beatsPerBar)
        return p.bars * p.beatsPerBar
    }
}
