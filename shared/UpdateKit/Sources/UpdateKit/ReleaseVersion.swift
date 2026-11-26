// SPDX-License-Identifier: MIT

import Foundation

/// A version as a list of numbers, compared number by number; a missing number counts as 0.
public struct ReleaseVersion: Comparable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let numbers: [Int]

    public init(numbers: [Int]) { self.numbers = numbers }

    /// "0.9.73.6" gives [0, 9, 73, 6]; nil when a part is not a number.
    public init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { Int($0) }
        guard !parts.isEmpty, numbers.count == parts.count else { return nil }
        self.numbers = numbers
    }

    public var description: String { numbers.map(String.init).joined(separator: ".") }

    public static func < (a: ReleaseVersion, b: ReleaseVersion) -> Bool {
        for index in 0..<max(a.numbers.count, b.numbers.count) {
            let x = index < a.numbers.count ? a.numbers[index] : 0
            let y = index < b.numbers.count ? b.numbers[index] : 0
            if x != y { return x < y }
        }
        return false
    }

    public static func == (a: ReleaseVersion, b: ReleaseVersion) -> Bool { !(a < b) && !(b < a) }

    public func hash(into hasher: inout Hasher) {
        var trimmed = numbers
        while trimmed.last == 0 { trimmed.removeLast() }
        hasher.combine(trimmed)
    }
}

/// What a release of the collection is called: the version of the tool it comes from, and the number of this macOS edition of that version.
/// The tag of a release reads `<prefix><version>-macOS` (revision 1) or `<prefix><version>-macOS-<revision>`:
/// `jack_capture-v0.9.73-macOS-6` is version 0.9.73, revision 6.
public struct ReleaseLabel: Codable, Equatable, Sendable {
    /// The version of the tool, as upstream numbers it ("0.9.73").
    public let upstream: String
    public let revision: Int

    public init(upstream: String, revision: Int) {
        self.upstream = upstream
        self.revision = revision
    }

    /// The version and the revision as one number, to compare two labels: [0, 9, 73, 6].
    public var version: ReleaseVersion {
        ReleaseVersion(numbers: (ReleaseVersion(upstream)?.numbers ?? []) + [revision])
    }

    /// "0.9.73 macOS Edition · révision 6", the line of the About panel. `revisionWord` is the translated word.
    public func text(revisionWord: String) -> String {
        "\(upstream) macOS Edition · \(revisionWord) \(revision)"
    }

    /// The label of a tag, or nil when the tag is not one of the tool (other prefix, or not a version).
    public static func parse(tag: String, prefix: String) -> ReleaseLabel? {
        guard tag.hasPrefix(prefix) else { return nil }
        var rest = String(tag.dropFirst(prefix.count))
        var revision = 1
        if let range = rest.range(of: "-macOS") {
            let suffix = rest[range.upperBound...]
            rest = String(rest[..<range.lowerBound])
            if !suffix.isEmpty {
                guard suffix.hasPrefix("-"), let number = Int(suffix.dropFirst()), number >= 1 else { return nil }
                revision = number
            }
        }
        guard ReleaseVersion(rest) != nil else { return nil }
        return ReleaseLabel(upstream: rest, revision: revision)
    }

    /// The label of the running application: `CFBundleShortVersionString` is the version of the tool, `JACRevision` (written by the
    /// build) the revision; without it, the revision is what follows the version in `CFBundleVersion` ("0.9.73.6").
    public static func installed(bundle: Bundle = .main) -> ReleaseLabel? {
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["UPDATEKIT_INSTALLED"], let label = parseInstalled(forced) { return label }
        #endif
        guard let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              ReleaseVersion(short) != nil else { return nil }
        if let text = bundle.object(forInfoDictionaryKey: "JACRevision") as? String, let revision = Int(text), revision >= 1 {
            return ReleaseLabel(upstream: short, revision: revision)
        }
        if let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String, build.hasPrefix(short + "."),
           let revision = Int(build.dropFirst(short.count + 1)), revision >= 1 {
            return ReleaseLabel(upstream: short, revision: revision)
        }
        return ReleaseLabel(upstream: short, revision: 1)
    }

    /// "0.9.73.5" (a development aid): the last number is the revision.
    static func parseInstalled(_ text: String) -> ReleaseLabel? {
        guard let version = ReleaseVersion(text), version.numbers.count >= 2, let revision = version.numbers.last else { return nil }
        return ReleaseLabel(upstream: version.numbers.dropLast().map(String.init).joined(separator: "."), revision: revision)
    }
}
