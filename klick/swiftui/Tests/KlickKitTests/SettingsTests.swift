// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
import KlickEngine
@testable import KlickKit

final class SettingsTests: XCTestCase {
    func testTapTempoLearnsFromTaps() {
        var tap = TapTempo()
        XCTAssertNil(tap.tap(at: 10.0))
        XCTAssertEqual(try XCTUnwrap(tap.tap(at: 10.5)), 120, accuracy: 0.001)
        tap.tap(at: 11.0); tap.tap(at: 11.5)
        XCTAssertTrue(tap.isReliable)
        XCTAssertEqual(try XCTUnwrap(tap.bpm), 120, accuracy: 0.001)
        tap.tap(at: 12.0 + 0.0)
        XCTAssertEqual(tap.count, 5)
    }

    func testTapTempoStartsAgainAfterAPauseAndKeepsTheLastTaps() {
        var tap = TapTempo()
        tap.tap(at: 0); tap.tap(at: 0.5)
        tap.tap(at: 10)   // longer than the gap allowed: a new series
        XCTAssertEqual(tap.count, 1)
        XCTAssertNil(tap.bpm)
        for i in 1...20 { tap.tap(at: 10 + Double(i) * 0.4) }
        XCTAssertEqual(tap.count, TapTempo.maxTaps)
        XCTAssertEqual(try XCTUnwrap(tap.bpm), 150, accuracy: 0.001, "only the last taps count: the tempo can change")
        tap.tap(at: 1)    // time going backwards
        XCTAssertEqual(tap.count, 1)
        tap.reset()
        XCTAssertEqual(tap.count, 0)
    }

    func testMeterChoicesDependOnTheDenominator() {
        XCTAssertEqual(MeterRules.numerators(for: 2), [2, 3, 4])
        XCTAssertEqual(MeterRules.numerators(for: 8), [3, 5, 6, 7, 9, 12])
        XCTAssertEqual(MeterRules.numerators(for: 4, including: 11), [2, 3, 4, 5, 6, 7, 8, 11])
        XCTAssertEqual(MeterRules.numerator(4, for: 8), 3, "the nearest one that exists")
        XCTAssertEqual(MeterRules.numerator(12, for: 4), 8)
        XCTAssertEqual(MeterRules.numerator(5, for: 16), 5)
        XCTAssertEqual(MeterRules.denominators, [2, 4, 8, 16])
    }

    func testBeatGroups() {
        XCTAssertEqual(MeterRules.groups(beats: 4, denominator: 4), [4])
        XCTAssertEqual(MeterRules.groups(beats: 6, denominator: 8), [3, 3])
        XCTAssertEqual(MeterRules.groups(beats: 12, denominator: 16), [3, 3, 3, 3])
        XCTAssertEqual(MeterRules.groups(beats: 5, denominator: 8), [2, 3])
        XCTAssertEqual(MeterRules.groups(beats: 7, denominator: 8), [2, 2, 3])
        XCTAssertEqual(MeterRules.groups(beats: 8, denominator: 8), [2, 2, 2, 2])
    }

    func testTempoWords() {
        XCTAssertEqual(TempoWord.name(for: 30), "Grave")
        XCTAssertEqual(TempoWord.name(for: 70), "Adagio")
        XCTAssertEqual(TempoWord.name(for: 120), "Allegro")
        XCTAssertEqual(TempoWord.name(for: 119.9), "Moderato")
        XCTAssertEqual(TempoWord.name(for: 260), "Prestissimo")
    }

    func testCountInForTheEngine() {
        XCTAssertEqual(CountIn.none.engineParameters(beatsPerBar: 4).bars, 0)
        XCTAssertEqual(CountIn.twoBeats.engineParameters(beatsPerBar: 7).beatsPerBar, 2)
        XCTAssertEqual(CountIn.oneBar.beats(beatsPerBar: 5), 5)
        XCTAssertEqual(CountIn.fourBars.beats(beatsPerBar: 3), 12)
    }

    func testChangingTheMeterKeepsThePatternValid() {
        var s = ClickSettings()
        s.pattern = "X.xx"
        s.setBeats(6)
        XCTAssertEqual(s.pattern, "X.xxxx")
        s.setBeats(3)
        XCTAssertEqual(s.pattern, "X.x")
        s.setDenominator(8)    // 3 exists for eighths
        XCTAssertEqual(s.beats, 3)
        s.setBeats(12)
        s.setDenominator(2)    // 12 does not exist for halves: the nearest
        XCTAssertEqual(s.beats, 4)
        XCTAssertTrue(MapSection.isValid(pattern: s.pattern, beats: s.beats))
    }

    func testSettingsAreKeptBetweenLaunches() throws {
        var s = ClickSettings()
        s.tempo = 93.5; s.pitch = 3; s.countIn = .twoBars; s.isQuiet = true
        s.sound = .files(accent: "/Users/x/a.wav", normal: "/Users/x/n.wav")
        s.trainer.isEnabled = true
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(ClickSettings.self, from: data), s)
    }

    func testSpeedTrainerForTheEngineAndItsDuration() {
        var t = SpeedTrainer()
        XCTAssertEqual(t.engineIncrement, 0)
        XCTAssertNil(t.duration(from: 120, beats: 4, denominator: 4))
        t.isEnabled = true; t.target = 140; t.step = 2; t.everyBars = 8
        XCTAssertEqual(t.engineIncrement, 0.25, accuracy: 1e-9)
        XCTAssertEqual(t.engineLimit, 140)
        let seconds = try? XCTUnwrap(t.duration(from: 120, beats: 4, denominator: 4))
        XCTAssertEqual(seconds ?? 0, 10 * 8 * 4 * 60 / 130.0, accuracy: 25)   // ten steps of eight bars, about 130 BPM on average
        XCTAssertNil(t.duration(from: 150, beats: 4, denominator: 4), "already above the target")
    }

    func testCommandLineWritesOnlyWhatDiffersFromKlick() {
        var s = ClickSettings()
        s.accentVolume = 1; s.normalVolume = 1
        XCTAssertEqual(KlickCommand.text(settings: s, mode: .simple, mapFile: nil, connectToPhysicalOutputs: false), "klick 4/4 120 Xxxx")
        s.accentVolume = 0.9; s.normalVolume = 0.65
        XCTAssertEqual(KlickCommand.text(settings: s, mode: .simple, mapFile: nil, connectToPhysicalOutputs: true), "klick -P -v 0.90,0.65 4/4 120 Xxxx")
        s.sound = .builtIn(.click); s.pitch = 12; s.tempo = 100; s.setBeats(3)
        XCTAssertEqual(KlickCommand.text(settings: s, mode: .simple, mapFile: nil, connectToPhysicalOutputs: false),
                       "klick -s 3 -v 0.90,0.65 -w 2.00 3/4 100 Xxx")
    }

    func testCommandLineOfTheSpeedTrainerAndOfAMap() {
        var s = ClickSettings()
        s.accentVolume = 1; s.normalVolume = 1
        s.trainer.isEnabled = true; s.trainer.target = 140; s.trainer.step = 2; s.trainer.everyBars = 8
        XCTAssertEqual(KlickCommand.text(settings: s, mode: .simple, mapFile: nil, connectToPhysicalOutputs: false), "klick 4/4 120-140/4 Xxxx")
        s.countIn = .twoBeats; s.isCountInAudible = true
        XCTAssertEqual(KlickCommand.text(settings: s, mode: .map, mapFile: "my song.klick", connectToPhysicalOutputs: false),
                       "klick -c 0 -f 'my song.klick'")
        s.isCountInAudible = false
        XCTAssertEqual(KlickCommand.text(settings: s, mode: .map, mapFile: "song.klick", connectToPhysicalOutputs: false),
                       "klick -f song.klick", "klick has no silent count-in")
        s.isCountInAudible = true; s.isQuiet = true
        XCTAssertEqual(KlickCommand.text(settings: s, mode: .map, mapFile: "song.klick", connectToPhysicalOutputs: false),
                       "klick -f song.klick")
    }
}
