// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// The Italian word that goes with a tempo (the same in every language, as on a score).
public enum TempoWord {
    private static let words: [(below: Double, name: String)] = [
        (40, "Grave"), (60, "Largo"), (76, "Adagio"), (108, "Andante"), (120, "Moderato"),
        (168, "Allegro"), (200, "Presto"),
    ]

    public static func name(for bpm: Double) -> String {
        words.first { bpm < $0.below }?.name ?? "Prestissimo"
    }
}
