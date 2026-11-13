// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
@testable import KlickKit

final class StaffLayoutTests: XCTestCase {
    func testQuarterNotesHaveNoBeam() {
        let l = StaffLayout(beats: 4, denominator: 4, pattern: "Xxxx")
        XCTAssertEqual(l.noteX.count, 4)
        XCTAssertEqual(l.accented, [0])
        XCTAssertTrue(l.rests.isEmpty)
        XCTAssertTrue(l.beams.isEmpty)
        XCTAssertTrue(l.flags.isEmpty)
        XCTAssertFalse(l.hasOpenHeads)
        XCTAssertEqual(l.noteX, l.noteX.sorted())
        XCTAssertGreaterThan(l.noteX.first!, 46, "room for the time signature")
        XCTAssertLessThan(l.noteX.last!, l.width - 6)
    }

    func testSilentBeatsAreRests() {
        let l = StaffLayout(beats: 4, denominator: 4, pattern: "X.x.")
        XCTAssertEqual(l.rests, [1, 3])
        XCTAssertEqual(l.accented, [0])
    }

    func testFiveEightsAreBeamedTwoThenThree() {
        let l = StaffLayout(beats: 5, denominator: 8, pattern: "Xxxxx")
        XCTAssertEqual(l.beams.count, 2)
        XCTAssertEqual(l.beams[0].x1, StaffLayout.stemX(l.noteX[0]))
        XCTAssertEqual(l.beams[0].x2, StaffLayout.stemX(l.noteX[1]))
        XCTAssertEqual(l.beams[1].x1, StaffLayout.stemX(l.noteX[2]))
        XCTAssertEqual(l.beams[1].x2, StaffLayout.stemX(l.noteX[4]))
        XCTAssertTrue(l.flags.isEmpty, "no eighth note is left alone")
    }

    func testTwelveSixteenthsHaveTwoBeamsPerGroupOfThree() {
        let l = StaffLayout(beats: 12, denominator: 16, pattern: String(repeating: "x", count: 12))
        XCTAssertEqual(l.beams.count, 8)
        XCTAssertEqual(l.beams.filter { $0.level == 1 }.count, 4)
        XCTAssertEqual(l.beams[0].x1, StaffLayout.stemX(l.noteX[0]))
        XCTAssertEqual(l.beams[0].x2, StaffLayout.stemX(l.noteX[2]))
    }

    func testARestInsideAGroupShortensItsBeam() {
        let l = StaffLayout(beats: 6, denominator: 8, pattern: "Xx.Xxx")
        XCTAssertEqual(l.beams.count, 2)
        XCTAssertEqual(l.beams[0].x2, StaffLayout.stemX(l.noteX[1]), "the rest does not carry a beam")
    }

    func testALoneNoteInAGroupGetsAFlag() {
        let l = StaffLayout(beats: 6, denominator: 8, pattern: "X..xxx")
        XCTAssertEqual(l.flags, [StaffLayout.Flag(x: StaffLayout.stemX(l.noteX[0]), level: 0)])
        XCTAssertEqual(l.beams.count, 1)
        let sixteenth = StaffLayout(beats: 3, denominator: 16, pattern: "X..")
        XCTAssertEqual(sixteenth.flags.map(\.level), [0, 1], "a lone sixteenth note has two flags")
    }

    func testHalfNotesHaveOpenHeads() {
        XCTAssertTrue(StaffLayout(beats: 3, denominator: 2, pattern: "Xxx").hasOpenHeads)
    }

    func testTheSignatureMakesRoom() {
        let with = StaffLayout(beats: 4, denominator: 4, pattern: "Xxxx", showsSignature: true)
        let without = StaffLayout(beats: 4, denominator: 4, pattern: "Xxxx", showsSignature: false)
        XCTAssertGreaterThan(with.noteX[0], without.noteX[0])
    }

    func testAShortPatternIsCompletedWithNormalBeats() {
        let l = StaffLayout(beats: 4, denominator: 4, pattern: "X")
        XCTAssertEqual(l.accented, [0])
        XCTAssertTrue(l.rests.isEmpty)
    }
}
