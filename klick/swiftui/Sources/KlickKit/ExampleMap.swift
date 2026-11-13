// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// A tempo map that comes with the application, to show what a map is for. The files are in the `Examples` folder of the
/// application; their names and descriptions are translated here, the comments in the files are in English.
public struct ExampleMap: Identifiable, Equatable, Sendable {
    /// The name of the file, without its extension.
    public let id: String

    public static let all = ["practice-ramp", "meter-changes", "slow-ramp", "silent-bars"].map(ExampleMap.init)

    public init(id: String) { self.id = id }

    public var title: String {
        switch id {
        case "practice-ramp": return String(localized: "Progression de travail")
        case "meter-changes": return String(localized: "Changements de mesure")
        case "slow-ramp": return String(localized: "Rampe lente")
        case "silent-bars": return String(localized: "Exercice de silence")
        default: return id
        }
    }

    public var detail: String {
        switch id {
        case "practice-ramp": return String(localized: "Cinq paliers de 80 à 120, huit mesures chacun.")
        case "meter-changes": return String(localized: "4/4, 6/8, 7/8 et 5/4 à la suite.")
        case "slow-ramp": return String(localized: "Accélération puis ralentissement progressifs.")
        case "silent-bars": return String(localized: "Des mesures sans clic pour garder le tempo seul.")
        default: return ""
        }
    }

    public func url(in directory: URL) -> URL { directory.appendingPathComponent(id + ".klick") }

    public func sections(in directory: URL) throws -> [MapSection] {
        try TempoMapFile.parse(String(contentsOf: url(in: directory), encoding: .utf8))
    }
}
