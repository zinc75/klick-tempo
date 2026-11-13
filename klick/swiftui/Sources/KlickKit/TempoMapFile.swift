// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation

/// The tempo map file of klick: one section per line,
/// `[label:] bars [beats/denominator] tempo[-tempo2] [pattern] [volume]  # comment`.
/// A list of tempos (`120,121,122,...`) gives one tempo per beat: it must have `bars * beats` values.
public enum TempoMapFile {
    public struct ParseError: Error, LocalizedError, Equatable {
        public let line: Int
        public let text: String
        public let message: String
        public var errorDescription: String? { "line \(line): \(message)\n\(text)" }
    }

    /// Tempo range accepted by the engine.
    public static let tempoRange = 10.0...1000.0

    public static func parse(_ text: String) throws -> [MapSection] {
        var sections: [MapSection] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, raw) in lines.enumerated() {
            let original = String(raw).trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            func fail(_ message: String) -> ParseError { ParseError(line: index + 1, text: original, message: message) }

            var line = original
            if let hash = line.firstIndex(of: "#") { line = String(line[..<hash]) }
            line = line.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            var label = ""
            if let colon = line.firstIndex(of: ":") {
                label = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                if label.isEmpty || !MapSection.isValid(label: label) { throw fail("invalid label") }
                line = String(line[line.index(after: colon)...])
            }
            var tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard !tokens.isEmpty, let bars = Int(tokens.removeFirst()), bars > 0 else { throw fail("the number of bars must be a positive integer") }

            var beats = 4, denominator = 4
            if let first = tokens.first, first.contains("/") {
                let parts = first.split(separator: "/", omittingEmptySubsequences: false)
                guard parts.count == 2, let b = Int(parts[0]), let d = Int(parts[1]), b > 0, d > 0 else { throw fail("invalid time signature") }
                beats = b; denominator = d
                tokens.removeFirst()
            }

            guard let tempoToken = tokens.first else { throw fail("missing tempo") }
            tokens.removeFirst()
            var tempi: [Double]?
            if tempoToken.contains(",") {
                let values = tempoToken.split(separator: ",", omittingEmptySubsequences: false).map { Double($0) }
                guard values.allSatisfy({ $0 != nil && tempoRange.contains($0!) }) else { throw fail("tempo out of range (10 to 1000)") }
                guard values.count == bars * beats else { throw fail("number of tempo values doesn't match number of beats") }
                tempi = values.map { $0! }
            }
            let tempoParts = tempoToken.split(separator: "-", omittingEmptySubsequences: false)
            guard tempi != nil || ((1...2).contains(tempoParts.count) && Double(tempoParts[0]).map(tempoRange.contains) == true) else {
                throw fail("tempo out of range (10 to 1000)")
            }
            let tempo = tempi?.first ?? Double(tempoParts[0])!
            var tempoEnd: Double?
            if tempi == nil, tempoParts.count == 2 {
                guard let t2 = Double(tempoParts[1]), tempoRange.contains(t2) else { throw fail("tempo out of range (10 to 1000)") }
                tempoEnd = t2
            }

            var pattern: String?
            if let token = tokens.first, token.allSatisfy({ "Xx.".contains($0) }) {
                guard MapSection.isValid(pattern: token, beats: beats) else { throw fail("the pattern must have one character per beat") }
                pattern = token
                tokens.removeFirst()
            }
            var volume = 1.0
            if let token = tokens.first {
                guard let v = Double(token), v >= 0 else { throw fail("malformed tempo map entry") }
                volume = v
                tokens.removeFirst()
            }
            if !tokens.isEmpty { throw fail("malformed tempo map entry") }

            let muted = volume == 0
            sections.append(MapSection(label: label, bars: bars, beats: beats, denominator: denominator, tempo: tempo, tempoEnd: tempoEnd, tempi: tempi,
                                       pattern: pattern, volume: muted ? 1 : volume, muted: muted))
        }
        return sections
    }

    public static func format(_ sections: [MapSection]) -> String {
        sections.map { s in
            var parts: [String] = []
            if !s.label.isEmpty { parts.append("\(s.label):") }
            parts.append("\(s.bars)")
            parts.append("\(s.beats)/\(s.denominator)")
            if let tempi = s.tempi { parts.append(tempi.map(number).joined(separator: ",")) }
            else { parts.append(s.tempoEnd.map { "\(number(s.tempo))-\(number($0))" } ?? number(s.tempo)) }
            if s.pattern != MapSection.defaultPattern(beats: s.beats) { parts.append(s.pattern) }
            if s.muted { parts.append("0") } else if s.volume != 1 { parts.append(number(s.volume)) }
            return parts.joined(separator: " ")
        }.joined(separator: "\n") + (sections.isEmpty ? "" : "\n")
    }

    /// 120, 90.5, 0.65: no trailing zeros.
    static func number(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1e9 { return String(Int(v)) }
        var s = String(format: "%.3f", v)
        while s.hasSuffix("0") { s.removeLast() }
        return s
    }
}
