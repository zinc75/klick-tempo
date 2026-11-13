// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
@testable import KlickKit

final class TempoMapTests: XCTestCase {
    func testParsesTheFormatOfKlick() throws {
        let text = """
        # a comment
        intro: 8 4/4 120 Xxxx
        verse1: 12 4/4 120 X.x.   # silent second and fourth beats
        4 4/4 120-140
        bridge: 8 3/4 140 Xxx 0.5

        coda: 2 6/8 90 X..X..
        """
        let map = try TempoMapFile.parse(text)
        XCTAssertEqual(map.count, 5)
        XCTAssertEqual(map[0].label, "intro")
        XCTAssertEqual(map[0].bars, 8)
        XCTAssertEqual(map[1].pattern, "X.x.")
        XCTAssertEqual(map[2].label, "")
        XCTAssertEqual(map[2].tempo, 120)
        XCTAssertEqual(map[2].tempoEnd, 140)
        XCTAssertEqual(map[2].pattern, "Xxxx", "no pattern means the default one")
        XCTAssertEqual(map[3].volume, 0.5)
        XCTAssertEqual(map[4].beats, 6)
        XCTAssertEqual(map[4].denominator, 8)
    }

    func testMeterDefaultsToFourFour() throws {
        let map = try TempoMapFile.parse("2 100\n")
        XCTAssertEqual(map[0].beats, 4)
        XCTAssertEqual(map[0].denominator, 4)
    }

    func testVolumeZeroIsASilentSection() throws {
        let map = try TempoMapFile.parse("solo: 8 4/4 120 Xxxx 0\n")
        XCTAssertTrue(map[0].muted)
        XCTAssertEqual(map[0].volume, 1, "the volume to come back to when it is not silent any more")
        XCTAssertEqual(map[0].engineSection.volume, 0)
    }

    func testErrorsHaveTheLineNumber() {
        func error(_ text: String) -> TempoMapFile.ParseError? {
            do { _ = try TempoMapFile.parse(text); return nil } catch { return error as? TempoMapFile.ParseError }
        }
        XCTAssertEqual(error("4 4/4 120\n0 4/4 120\n")?.line, 2)
        XCTAssertNotNil(error("4 4/4 5"))                 // tempo out of range
        XCTAssertNotNil(error("4 4/4 120 Xx"))            // pattern too short
        XCTAssertNotNil(error("4 0/4 120"))               // invalid meter
        XCTAssertNotNil(error("4 4/4 120,121,122,123"))   // four bars need sixteen tempos, not four
        XCTAssertNotNil(error("two 4/4 120"))
        XCTAssertNotNil(error("4 4/4 120 Xxxx 1 extra"))
        XCTAssertNotNil(error("in tro: 4 4/4 120"))        // a label has no spaces
        XCTAssertNotNil(error("4 4/4"))
    }

    func testFormatWritesTheMinimum() {
        let sections = [
            MapSection(label: "intro", bars: 8, tempo: 120),
            MapSection(bars: 4, beats: 3, tempo: 90, tempoEnd: 120, pattern: "X.x", volume: 0.5),
            MapSection(label: "solo", bars: 2, beats: 5, denominator: 8, tempo: 140.5, muted: true),
        ]
        XCTAssertEqual(TempoMapFile.format(sections), """
        intro: 8 4/4 120
        4 3/4 90-120 X.x 0.5
        solo: 2 5/8 140.5 0

        """)
    }

    func testWhatIsWrittenIsReadBack() throws {
        let sections = [
            MapSection(label: "a", bars: 8, tempo: 120),
            MapSection(bars: 4, beats: 3, tempo: 90, tempoEnd: 120, pattern: "X.x", volume: 0.65),
            MapSection(label: "b-2_x", bars: 2, beats: 7, denominator: 16, tempo: 133.333, muted: true),
        ]
        XCTAssertEqual(try TempoMapFile.parse(TempoMapFile.format(sections)), sections)
    }

    func testDocumentKnowsWhenItIsModified() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("klick-test-\(UUID().uuidString).klick")
        defer { try? FileManager.default.removeItem(at: url) }
        var doc = TempoMapDocument(sections: [MapSection(label: "intro", bars: 4, tempo: 100)])
        XCTAssertEqual(doc.name, "Untitled.klick")
        XCTAssertFalse(doc.isModified)
        try doc.save(to: url)
        XCTAssertEqual(doc.name, url.lastPathComponent)
        doc.sections[0].tempo = 110
        XCTAssertTrue(doc.isModified)
        doc.sections[0].tempo = 100
        XCTAssertFalse(doc.isModified, "back to what is in the file")
        doc.insert(MapSection(label: "outro", bars: 2, tempo: 80), after: 0)
        XCTAssertTrue(doc.isModified)
        XCTAssertEqual(doc.totalBars, 6)
        try doc.save()
        XCTAssertFalse(doc.isModified)
        let reopened = try TempoMapDocument(contentsOf: url)
        XCTAssertEqual(reopened.sections, doc.sections)
        XCTAssertFalse(reopened.isModified)
        var unsaved = TempoMapDocument()
        XCTAssertThrowsError(try unsaved.save())
    }

    func testATempoPerBeat() throws {
        let map = try TempoMapFile.parse("take: 2 4/4 120,121,122,123,124,125,126,127 Xxxx\n")
        XCTAssertEqual(map[0].tempi, [120, 121, 122, 123, 124, 125, 126, 127])
        XCTAssertEqual(map[0].tempo, 120, "the first of them")
        XCTAssertNil(map[0].tempoEnd)
        XCTAssertTrue(map[0].hasTempoPerBeat)
        XCTAssertEqual(map[0].engineSection.tempi?.count, 8)
        XCTAssertEqual(TempoMapFile.format(map), "take: 2 4/4 120,121,122,123,124,125,126,127\n")
        XCTAssertEqual(try TempoMapFile.parse(TempoMapFile.format(map)), map)
        func message(_ text: String) -> String? {
            do { _ = try TempoMapFile.parse(text); return nil } catch { return (error as? TempoMapFile.ParseError)?.message }
        }
        XCTAssertEqual(message("2 4/4 120,121,122"), "number of tempo values doesn't match number of beats")
        XCTAssertEqual(message("1 4/4 120,5,120,120"), "tempo out of range (10 to 1000)")
        XCTAssertNotNil(message("1 4/4 120,,120,120"))
    }

    func testTemposFollowTheBarsAndBeats() {
        var s = MapSection(bars: 1, beats: 4, tempo: 0, tempi: [100, 110, 120, 130])
        s.bars = 2; s.fitTempi()
        XCTAssertEqual(s.tempi, [100, 110, 120, 130, 130, 130, 130, 130], "completed with the last tempo")
        s.bars = 1; s.beats = 3; s.fitTempi()
        XCTAssertEqual(s.tempi, [100, 110, 120])
        var plain = MapSection(bars: 2, tempo: 90)
        plain.fitTempi()
        XCTAssertNil(plain.tempi)
    }

    func testPatternAndLabelRules() {
        XCTAssertEqual(MapSection.resized(pattern: "X.x", to: 5), "X.xxx")
        XCTAssertEqual(MapSection.resized(pattern: "Xxxx", to: 2), "Xx")
        XCTAssertEqual(MapSection.defaultPattern(beats: 3), "Xxx")
        XCTAssertTrue(MapSection.isValid(pattern: "X.x", beats: 3))
        XCTAssertFalse(MapSection.isValid(pattern: "X.x", beats: 4))
        XCTAssertFalse(MapSection.isValid(pattern: "Xyx", beats: 3))
        XCTAssertTrue(MapSection.isValid(label: "verse_2-b"))
        XCTAssertFalse(MapSection.isValid(label: "verse 2"))
        XCTAssertFalse(MapSection.isValid(label: "refrain:"))
    }
}
