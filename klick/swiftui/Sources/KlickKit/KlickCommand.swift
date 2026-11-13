// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import KlickEngine

/// The klick command line that does what the application is set to do, for the "command line" sheet. The application plays
/// with the engine of klick itself; the command is what to type in a Terminal to get the same metronome from the program.
public enum KlickCommand {
    /// The arguments after `klick`. Options left at the default of klick are not written.
    public static func arguments(settings s: ClickSettings, mode: Mode, mapFile: String?, connectToPhysicalOutputs: Bool) -> [String] {
        var a: [String] = []
        if connectToPhysicalOutputs { a.append("-P") }
        switch s.sound {
        case .builtIn(let sound): if sound != .square { a += ["-s", "\(sound.rawValue)"] }
        case .files(let accent, let normal): a += ["-S", "\(accent),\(normal)"]
        }
        if s.accentVolume != 1 || s.normalVolume != 1 { a += ["-v", "\(two(s.accentVolume)),\(two(s.normalVolume))"] }
        if s.pitch != 0 { a += ["-w", two(s.pitchFactor)] }
        switch mode {
        case .map:
            // klick's own count-in exists for tempo maps only (-c 0 means two beats).
            if s.countIn != .none && !s.isQuiet {
                a += ["-c", s.countIn == .twoBeats ? "0" : "\(s.countIn.engineParameters(beatsPerBar: s.beats).bars)"]
            }
            a += ["-f", mapFile ?? "map.klick"]
        case .simple:
            a.append("\(s.beats)/\(s.denominator)")
            if s.trainer.isEnabled, s.trainer.step > 0, s.trainer.target > s.tempo {
                // klick wants the bars it takes to rise by one unit of tempo.
                a.append("\(TempoMapFile.number(s.tempo))-\(TempoMapFile.number(s.trainer.target))/\(TempoMapFile.number(Double(s.trainer.everyBars) / s.trainer.step))")
            } else {
                a.append(TempoMapFile.number(s.tempo))
            }
            a.append(s.pattern)
        }
        return a
    }

    public static func text(settings: ClickSettings, mode: Mode, mapFile: String?, connectToPhysicalOutputs: Bool) -> String {
        (["klick"] + arguments(settings: settings, mode: mode, mapFile: mapFile, connectToPhysicalOutputs: connectToPhysicalOutputs)
            .map(quoted)).joined(separator: " ")
    }

    private static func two(_ v: Double) -> String { String(format: "%.2f", v) }

    private static func quoted(_ s: String) -> String {
        s.contains(where: { " \t'\"\\$&;()<>|*?".contains($0) }) ? "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" : s
    }
}
