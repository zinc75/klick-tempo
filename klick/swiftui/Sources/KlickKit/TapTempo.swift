// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// Learns a tempo from taps (trackpad or key): the mean of the last intervals, without the ones that are far off, and how
/// regular the taps are. A pause starts a new series.
public struct TapTempo: Equatable, Sendable {
    /// A pause longer than this starts a new series.
    public static let maxGap: TimeInterval = 2.5
    /// Taps kept: the last eight intervals.
    public static let maxTaps = 9
    /// Taps from which the tempo can be taken, and from which the regularity is meaningful.
    public static let applicableCount = 3
    public static let reliableCount = 4
    /// An interval that differs from the median by more than this part of it is left out (a tap that slipped).
    static let outlierLimit = 0.35

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

    /// The intervals that count: those within a third of the median.
    private var usableIntervals: [Double] {
        let all = zip(taps.dropFirst(), taps).map { $0 - $1 }
        guard !all.isEmpty else { return [] }
        let median = all.sorted()[all.count / 2]
        let good = all.filter { abs($0 - median) < median * Self.outlierLimit }
        return good.isEmpty ? all : good
    }

    private var meanInterval: Double? {
        let good = usableIntervals
        guard !good.isEmpty else { return nil }
        let m = good.reduce(0, +) / Double(good.count)
        return m > 0 ? m : nil
    }

    /// Beats per minute; `nil` until there are two taps.
    public var bpm: Double? { meanInterval.map { 60 / $0 } }

    /// From 0 (all over the place) to 1 (a metronome): one minus four times the spread of the intervals over their mean.
    public var regularity: Double? {
        let good = usableIntervals
        guard good.count >= 1, let m = meanInterval else { return nil }
        let variance = good.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(good.count)
        return max(0, 1 - variance.squareRoot() / m * 4)
    }

    /// The tempo can be taken (three taps).
    public var canApply: Bool { taps.count >= Self.applicableCount }

    /// The regularity is worth showing (four taps).
    public var isReliable: Bool { taps.count >= Self.reliableCount }
}
