// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// Learns a tempo from taps (trackpad or key): the average over the last taps, starting again after a pause.
public struct TapTempo: Equatable, Sendable {
    /// A pause longer than this starts a new series.
    public static let maxGap: TimeInterval = 2.5
    public static let maxTaps = 8
    /// Taps needed before the tempo is considered learned.
    public static let reliableCount = 4

    public private(set) var taps: [TimeInterval] = []

    public init() {}

    /// Records a tap (`time` in seconds, from any steady clock) and returns the tempo so far, `nil` after the first tap.
    @discardableResult
    public mutating func tap(at time: TimeInterval) -> Double? {
        if let last = taps.last, time < last || time - last > Self.maxGap { taps = [] }
        taps.append(time)
        if taps.count > Self.maxTaps { taps.removeFirst() }
        return bpm
    }

    public mutating func reset() { taps = [] }

    public var count: Int { taps.count }

    /// Beats per minute over the taps kept; `nil` until there are two.
    public var bpm: Double? {
        guard let first = taps.first, let last = taps.last, taps.count >= 2, last > first else { return nil }
        return 60 * Double(taps.count - 1) / (last - first)
    }

    public var isReliable: Bool { taps.count >= Self.reliableCount }
}
