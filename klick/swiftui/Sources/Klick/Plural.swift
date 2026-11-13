// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import Foundation

/// Counts with the right number. Two whole strings each, so that a translation can write them as it needs; the plural from 2
/// on (as in French, where 0 and 1 are singular). To move to plural variations of the string catalog with the translations.
enum Plural {
    static func sections(_ n: Int) -> String {
        n > 1 ? String(localized: "\(n) sections") : String(localized: "\(n) section")
    }

    static func bars(_ n: Int) -> String {
        n > 1 ? String(localized: "\(n) mesures") : String(localized: "\(n) mesure")
    }
}
