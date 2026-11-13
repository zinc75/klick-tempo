// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// A tempo map as a document: sections, the file it comes from, and whether it was modified since it was opened or saved.
public struct TempoMapDocument: Equatable, Sendable {
    public var sections: [MapSection]
    /// The file, `nil` until the map is saved.
    public private(set) var url: URL?
    private var saved: [MapSection]

    /// Name shown under the title of the page.
    public var name: String { url?.lastPathComponent ?? "Untitled.klick" }
    /// True when the sections differ from the file (or from a new map): "Save" is enabled only then.
    public var isModified: Bool { sections != saved }
    public var totalBars: Int { sections.reduce(0) { $0 + $1.bars } }

    public init(sections: [MapSection] = []) {
        self.sections = sections
        self.saved = sections
    }

    public init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let parsed = try TempoMapFile.parse(text)
        self.sections = parsed
        self.saved = parsed
        self.url = url
    }

    /// Writes the map; afterwards it is no longer modified.
    public mutating func save(to destination: URL? = nil) throws {
        guard let target = destination ?? url else { throw CocoaError(.fileNoSuchFile) }
        try TempoMapFile.format(sections).write(to: target, atomically: true, encoding: .utf8)
        url = target
        saved = sections
    }

    /// Inserts after `index` (at the end when `nil`) and returns the index of the new section.
    @discardableResult
    public mutating func insert(_ section: MapSection, after index: Int?) -> Int {
        let at = index.map { min($0 + 1, sections.count) } ?? sections.count
        sections.insert(section, at: at)
        return at
    }
}
