// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
@testable import KlickKit

final class MidiExportTests: XCTestCase {
    /// The events of a track: absolute tick, status byte and data.
    private struct Event { var tick: Int; var bytes: [UInt8] }

    private func tracks(_ data: Data) -> (format: Int, division: Int, tracks: [[Event]]) {
        let b = [UInt8](data)
        func u32(_ o: Int) -> Int { Int(b[o]) << 24 | Int(b[o + 1]) << 16 | Int(b[o + 2]) << 8 | Int(b[o + 3]) }
        func u16(_ o: Int) -> Int { Int(b[o]) << 8 | Int(b[o + 1]) }
        XCTAssertEqual(String(decoding: b[0..<4], as: UTF8.self), "MThd")
        let count = u16(10)
        var offset = 14
        var result: [[Event]] = []
        for _ in 0..<count {
            XCTAssertEqual(String(decoding: b[offset..<offset + 4], as: UTF8.self), "MTrk")
            let length = u32(offset + 4)
            var i = offset + 8
            let end = i + length
            var tick = 0
            var events: [Event] = []
            while i < end {
                var delta = 0
                while true { let byte = Int(b[i]); i += 1; delta = delta << 7 | (byte & 0x7F); if byte & 0x80 == 0 { break } }
                tick += delta
                let status = b[i]
                var size = 0
                if status == 0xFF { size = 2 + Int(b[i + 2]) + 0; events.append(Event(tick: tick, bytes: Array(b[i..<i + 3 + Int(b[i + 2])]))); i += 3 + Int(b[i + 2]); continue }
                size = 3
                events.append(Event(tick: tick, bytes: Array(b[i..<i + size])))
                i += size
            }
            result.append(events)
            offset = end
        }
        return (u16(8), u16(12), result)
    }

    func testTheFileIsATempoMapAndAClickTrack() {
        let map = [
            MapSection(label: "a", bars: 2, tempo: 120),
            MapSection(label: "b", bars: 1, beats: 3, tempo: 90, pattern: "X.x"),
        ]
        let parsed = tracks(MidiExport.data(sections: map))
        XCTAssertEqual(parsed.format, 1)
        XCTAssertEqual(parsed.division, 480)
        XCTAssertEqual(parsed.tracks.count, 2)

        let tempos = parsed.tracks[0].filter { $0.bytes.starts(with: [0xFF, 0x51]) }
        XCTAssertEqual(tempos.map(\.tick), [0, 8 * 480], "a tempo where it changes")
        XCTAssertEqual(tempos.map { Int($0.bytes[3]) << 16 | Int($0.bytes[4]) << 8 | Int($0.bytes[5]) }, [500_000, 666_667])
        let meters = parsed.tracks[0].filter { $0.bytes.starts(with: [0xFF, 0x58]) }
        XCTAssertEqual(meters.map(\.tick), [0, 8 * 480])
        XCTAssertEqual(meters.map { Array($0.bytes[3...4]) }, [[4, 2], [3, 2]])

        let notes = parsed.tracks[1].filter { $0.bytes[0] == 0x99 && $0.bytes[2] > 0 }
        XCTAssertEqual(notes.count, 8 + 2, "eight beats, then X.x: two notes, the second beat is silent")
        XCTAssertEqual(notes.first?.bytes[1], MidiExport.accentNote)
        XCTAssertEqual(notes[1].bytes[1], MidiExport.normalNote)
        XCTAssertEqual(notes.last?.tick, 8 * 480 + 2 * 480, "the third beat of the last bar")
    }

    func testARampIsOneTempoPerBeatAndASilentSectionHasNoNote() {
        let map = [MapSection(label: "up", bars: 1, tempo: 100, tempoEnd: 130), MapSection(label: "quiet", bars: 1, tempo: 120, muted: true)]
        let parsed = tracks(MidiExport.data(sections: map))
        let tempos = parsed.tracks[0].filter { $0.bytes.starts(with: [0xFF, 0x51]) }
        XCTAssertEqual(tempos.count, 4 + 1, "four beats of the ramp, then the tempo of the next section")
        XCTAssertEqual(parsed.tracks[1].filter { $0.bytes[0] == 0x99 && $0.bytes[2] > 0 }.count, 4)
    }

    func testStartingFromABarAndTheTempoTrackAlone() {
        let map = [MapSection(label: "a", bars: 2, tempo: 120), MapSection(label: "b", bars: 2, tempo: 90)]
        let parsed = tracks(MidiExport.data(sections: map, fromBar: 3, withClicks: false))
        XCTAssertEqual(parsed.tracks.count, 1)
        let tempos = parsed.tracks[0].filter { $0.bytes.starts(with: [0xFF, 0x51]) }
        XCTAssertEqual(tempos.count, 1)
        XCTAssertEqual(tempos.first?.tick, 0)
        let end = parsed.tracks[0].last
        XCTAssertEqual(end?.tick, 4 * 480, "one bar left")
    }
}
