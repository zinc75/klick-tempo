// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// A tempo map as a Standard MIDI File (format 1, 480 ticks per quarter note): a first track with the tempos and the meters, for a
/// sequencer to take as its tempo map, and a second one with the clicks on the percussion channel (a high wood block for the
/// accents, a low one for the other beats; silent beats and silent sections have no note). A ramp is written as one tempo per beat.
public enum MidiExport {
    public static let ticksPerQuarter = 480
    public static let accentNote: UInt8 = 76, normalNote: UInt8 = 77

    /// The file for the sections of the map from the bar `fromBar` (counted from 0); `withClicks` false writes the tempo track only.
    public static func data(sections: [MapSection], fromBar: Int = 0, withClicks: Bool = true) -> Data {
        let (played, _, _) = MapSection.played(sections, fromBar: fromBar)

        var conductor = Track()
        conductor.meta(0x03, Array("Klick tempo map".utf8))
        var clicks = Track()
        clicks.meta(0x03, Array("Klick".utf8))

        var tick = 0
        var lastMeter: (Int, Int)?
        var lastTempo: Int?
        for section in played {
            let beatTicks = ticksPerQuarter * 4 / max(section.denominator, 1)
            if lastMeter == nil || lastMeter! != (section.beats, section.denominator) {
                let power = Int(log2(Double(max(section.denominator, 1))).rounded())
                // numerator, denominator as a power of two, 24 MIDI clocks per quarter of the beat unit, 8 thirty-seconds per quarter
                conductor.event(delta: tick - conductor.time, [0xFF, 0x58, 4, UInt8(section.beats), UInt8(power), UInt8(24 * 4 / max(section.denominator, 1)), 8])
                conductor.time = tick
                lastMeter = (section.beats, section.denominator)
            }
            let total = section.bars * section.beats
            for beat in 0..<total {
                let position = tick + beat * beatTicks
                // the tempo of this beat, in quarter notes per minute
                let tempo: Double
                if let list = section.tempi, beat < list.count { tempo = list[beat] }
                else if let end = section.tempoEnd, total > 1 { tempo = section.tempo + (end - section.tempo) * Double(beat) / Double(total - 1) }
                else { tempo = section.tempo }
                let micros = Int((60_000_000 / max(tempo, 1)).rounded())
                if micros != lastTempo {
                    conductor.event(delta: position - conductor.time, [0xFF, 0x51, 3, UInt8(micros >> 16 & 0xFF), UInt8(micros >> 8 & 0xFF), UInt8(micros & 0xFF)])
                    conductor.time = position
                    lastTempo = micros
                }
                guard withClicks, !section.muted, section.volume > 0 else { continue }
                let pattern = Array(section.pattern)
                guard beat % section.beats < pattern.count else { continue }
                let kind = pattern[beat % section.beats]
                guard kind != "." else { continue }
                let note = kind == "X" ? accentNote : normalNote
                let velocity = UInt8(max(1, min(127, Int((kind == "X" ? 110.0 : 80.0) * min(section.volume, 1)))))
                clicks.event(delta: position - clicks.time, [0x99, note, velocity])
                clicks.time = position
                clicks.event(delta: beatTicks / 4, [0x99, note, 0])
                clicks.time = position + beatTicks / 4
            }
            tick += total * beatTicks
        }
        conductor.event(delta: tick - conductor.time, [0xFF, 0x2F, 0])
        clicks.event(delta: max(0, tick - clicks.time), [0xFF, 0x2F, 0])

        var file = Data()
        file.append(contentsOf: Array("MThd".utf8) + be32(6) + be16(1) + be16(withClicks ? 2 : 1) + be16(ticksPerQuarter))
        for track in (withClicks ? [conductor, clicks] : [conductor]) {
            file.append(contentsOf: Array("MTrk".utf8) + be32(track.bytes.count))
            file.append(contentsOf: track.bytes)
        }
        return file
    }

    private static func be32(_ v: Int) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: v >> (8 * (3 - $0))) } }
    private static func be16(_ v: Int) -> [UInt8] { (0..<2).map { UInt8(truncatingIfNeeded: v >> (8 * (1 - $0))) } }

    /// The events of a track, with delta times as variable-length quantities.
    private struct Track {
        var bytes: [UInt8] = []
        /// The tick of the last event written.
        var time = 0

        mutating func meta(_ type: UInt8, _ payload: [UInt8]) {
            bytes += [0, 0xFF, type, UInt8(payload.count)] + payload
        }

        mutating func event(delta: Int, _ message: [UInt8]) {
            bytes += Self.variableLength(max(0, delta)) + message
        }

        static func variableLength(_ value: Int) -> [UInt8] {
            var v = value
            var out = [UInt8(v & 0x7F)]
            v >>= 7
            while v > 0 { out.insert(UInt8(v & 0x7F) | 0x80, at: 0); v >>= 7 }
            return out
        }
    }
}
