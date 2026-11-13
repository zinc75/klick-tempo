// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import XCTest
@testable import KlickKit

/// The string catalog of the interface (`Resources/Localizable.xcstrings`): French is the source language, the keys are the French
/// texts of the sources; English, German, Italian and Spanish are translated.
final class LocalizationCatalogTests: XCTestCase {
    static let catalogURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Resources/Localizable.xcstrings")
    static let languages = ["en", "de", "it", "es"]

    private func catalog() throws -> [String: [String: String]] {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: Self.catalogURL)) as? [String: Any])
        XCTAssertEqual(root["sourceLanguage"] as? String, "fr")
        let strings = try XCTUnwrap(root["strings"] as? [String: [String: Any]])
        return strings.mapValues { entry in
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            return localizations.compactMapValues { ($0["stringUnit"] as? [String: Any])?["value"] as? String }
        }
    }

    /// The format specifiers of a text, in order: what a translation must keep.
    private func specifiers(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(?:lld|@|lf|%)")
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { String(text[Range($0.range, in: text)!]) }.sorted()
    }

    func testEveryTextIsTranslatedIntoEveryLanguage() throws {
        let strings = try catalog()
        XCTAssertGreaterThan(strings.count, 200)
        for (key, values) in strings {
            for language in Self.languages {
                XCTAssertFalse((values[language] ?? "").isEmpty, "\(language) is missing for “\(key)”")
            }
        }
    }

    func testATranslationKeepsTheFormatSpecifiersOfItsKey() throws {
        for (key, values) in try catalog() {
            for (language, text) in values {
                XCTAssertEqual(specifiers(text), specifiers(key), "“\(key)” in \(language)")
            }
        }
    }

    func testTheExamplesAreTranslated() throws {
        let strings = try catalog()
        for example in ExampleMap.all {
            XCTAssertNotNil(strings[example.title], "the title of \(example.id)")
            XCTAssertNotNil(strings[example.detail], "the description of \(example.id)")
        }
    }

    func testTheCatalogMakesStringsFilesThatFormatCorrectly() throws {
        // What the build does: one .strings file per language in a bundle; then a lookup and a format.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("klick-l10n-\(UUID().uuidString).bundle")
        defer { try? FileManager.default.removeItem(at: directory) }
        let strings = try catalog()
        for language in Self.languages {
            let folder = directory.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            func quoted(_ s: String) -> String {
                "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n") + "\""
            }
            let text = strings.keys.sorted().map { "\(quoted($0)) = \(quoted(strings[$0]![language]!));" }.joined(separator: "\n")
            try text.write(to: folder.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
        }
        let english = try XCTUnwrap(Bundle(path: directory.appendingPathComponent("en.lproj").path))
        let template = english.localizedString(forKey: "Écriture… %lld %%", value: nil, table: nil)
        XCTAssertEqual(String(format: template, 42), "Writing… 42 %")
        let german = try XCTUnwrap(Bundle(path: directory.appendingPathComponent("de.lproj").path))
        XCTAssertEqual(german.localizedString(forKey: "Annuler", value: nil, table: nil), "Abbrechen")
        let bars = english.localizedString(forKey: "Durée : %@, %@. Taille estimée : %@.", value: nil, table: nil)
        XCTAssertEqual(String(format: bars, "2 min 3 s", "8 bars", "2.3 MB"), "Length: 2 min 3 s, 8 bars. Estimated size: 2.3 MB.")
    }
}
