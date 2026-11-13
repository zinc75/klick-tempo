// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
@testable import KlickKit

@MainActor
final class AudioExportTests: XCTestCase {
    private func temporaryFile(_ name: String = "klick-export.wav") -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("klick-test-\(UUID().uuidString)-\(name)")
    }

    private func settings() -> ClickSettings {
        var s = ClickSettings()
        s.tempo = 120
        s.beats = 4; s.denominator = 4; s.pattern = "Xxxx"
        return s
    }

    /// Reads the header of a WAV file: format tag, channels, rate, bits, bytes of data.
    private func header(_ data: Data) -> (format: Int, channels: Int, rate: Int, bits: Int, bytes: Int) {
        func u16(_ o: Int) -> Int { Int(data[o]) | Int(data[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }
        XCTAssertEqual(String(decoding: data[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
        XCTAssertEqual(u32(4), data.count - 8)
        return (u16(20), u16(22), u32(24), u16(34), u32(40))
    }

    func testTwoBarsOfTheMetronomeLastExactlyTwoBars() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        var options = AudioExportOptions()
        options.bitDepth = .int16
        var last = 0.0
        try AudioExporter.export(source: .metronome(bars: 2), settings: settings(), map: [], options: options,
                                 soundsDirectory: PlayerTests.sounds, to: url, progress: { last = $0 })
        let data = try Data(contentsOf: url)
        let h = header(data)
        XCTAssertEqual(h.format, 1)
        XCTAssertEqual(h.channels, 1)
        XCTAssertEqual(h.rate, 48000)
        XCTAssertEqual(h.bits, 16)
        XCTAssertEqual(h.bytes, 2 * 4 * 24000 * 2, "two bars of four beats at 120: four seconds, 16 bits")
        XCTAssertEqual(last, 1)
        // a click at the start, and a quiet moment between two clicks
        func sample(_ i: Int) -> Int { Int(Int16(bitPattern: UInt16(data[44 + 2 * i]) | UInt16(data[45 + 2 * i]) << 8)) }
        XCTAssertGreaterThan((0..<2000).map { abs(sample($0)) }.max() ?? 0, 3000)
        XCTAssertLessThan((20000..<23000).map { abs(sample($0)) }.max() ?? 0, 50, "the click is over before the next beat")
    }

    func testTheDepthsAndTheRate() throws {
        for (depth, bytes) in [(AudioExportOptions.BitDepth.int24, 3), (.float32, 4)] {
            let url = temporaryFile()
            defer { try? FileManager.default.removeItem(at: url) }
            var options = AudioExportOptions()
            options.rate = 44100
            options.bitDepth = depth
            try AudioExporter.export(source: .metronome(bars: 1), settings: settings(), map: [], options: options,
                                     soundsDirectory: PlayerTests.sounds, to: url)
            let h = header(try Data(contentsOf: url))
            XCTAssertEqual(h.rate, 44100)
            XCTAssertEqual(h.format, depth == .float32 ? 3 : 1)
            XCTAssertEqual(h.bytes, 2 * 44100 * bytes, "one bar of four beats at 120 is two seconds")
        }
    }

    func testTheMapIsWrittenToItsEndFromAChosenBar() throws {
        let map = [MapSection(label: "a", bars: 1, tempo: 120), MapSection(label: "b", bars: 1, beats: 3, tempo: 120)]
        var options = AudioExportOptions()
        options.bitDepth = .int16
        var lengths: [Int] = []
        for from in [0, 1] {
            let url = temporaryFile()
            defer { try? FileManager.default.removeItem(at: url) }
            try AudioExporter.export(source: .map(fromBar: from), settings: settings(), map: map, options: options,
                                     soundsDirectory: PlayerTests.sounds, to: url)
            lengths.append(header(try Data(contentsOf: url)).bytes / 2)
        }
        XCTAssertEqual(Double(lengths[0]) / 48000, 3.5, accuracy: 0.5)
        XCTAssertEqual(Double(lengths[1]) / 48000, 1.5, accuracy: 0.5, "from the second bar: only the section in 3/4")
    }

    func testACancelledExportLeavesNoFile() throws {
        let url = temporaryFile()
        var calls = 0
        XCTAssertThrowsError(try AudioExporter.export(source: .metronome(bars: 8), settings: settings(), map: [], options: AudioExportOptions(),
                                                      soundsDirectory: PlayerTests.sounds, to: url, isCancelled: { calls += 1; return calls > 3 })) {
            XCTAssertTrue($0 is CancellationError)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testTheCountInIsWrittenWhenAsked() throws {
        var s = settings()
        s.countIn = .oneBar
        var options = AudioExportOptions()
        options.bitDepth = .int16
        var sizes: [Int] = []
        for include in [false, true] {
            let url = temporaryFile()
            defer { try? FileManager.default.removeItem(at: url) }
            options.includeCountIn = include
            try AudioExporter.export(source: .metronome(bars: 1), settings: s, map: [], options: options, soundsDirectory: PlayerTests.sounds, to: url)
            sizes.append(header(try Data(contentsOf: url)).bytes / 2)
        }
        XCTAssertEqual(sizes[0], 2 * 48000)
        XCTAssertEqual(sizes[1], 4 * 48000, "one more bar of four beats")
    }
}
