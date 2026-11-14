// SPDX-License-Identifier: MIT

import SwiftUI

/// The badge of a JACK client: two letters on a coloured disc. The colour is a function of the
/// name, so that it is the same in every session and in JackMate (same rules as its `BadgeUtils`).
public struct BadgeStyle: Equatable, Sendable {
    public struct RGB: Equatable, Sendable {
        public var r: Double, g: Double, b: Double
    }

    public enum Kind: Sendable {
        case client
        /// The hardware capture ports ("system (capture)"): a fixed cyan with a microphone.
        case capture
        /// The hardware playback ports ("system (playback)"): a fixed violet with a loudspeaker, as in JackMate.
        case playback
    }

    public let letters: String
    public let kind: Kind
    /// Gradient from the top to the bottom of the disc.
    public let top: RGB
    public let bottom: RGB

    public init(client name: String, kind: Kind = .client) {
        self.kind = kind
        let abbr = Self.abbreviation(of: name)
        letters = abbr
        let base: RGB
        switch kind {
        case .capture:
            base = Self.rgb(hue: 0.524, saturation: 0.70, brightness: 0.78)
        case .playback:
            base = Self.rgb(hue: 0.78, saturation: 0.50, brightness: 0.82)
        case .client:
            base = Self.rgb(hue: Self.hue(abbreviation: abbr, fullName: name), saturation: 0.55, brightness: 0.80)
        }
        top = Self.shift(base, by: 0.18)
        bottom = Self.shift(base, by: -0.08)
    }

    /// One or two letters: the first letter in capitals, the second in lower case.
    public static func abbreviation(of name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: " (capture)", with: "")
            .replacingOccurrences(of: " (playback)", with: "")
        let letters = cleaned.filter { $0.isLetter }
        guard let first = letters.first else { return "?" }
        let second = letters.dropFirst().first.map { String($0).lowercased() } ?? ""
        return String(first).uppercased() + second
    }

    /// Hue between 0 and 1 from the abbreviation and the full name.
    public static func hue(abbreviation: String, fullName: String) -> Double {
        let scalars = Array(abbreviation.unicodeScalars)
        let v1 = scalars.count > 0 ? Int(scalars[0].value) : 65
        let v2 = scalars.count > 1 ? Int(scalars[1].value) : 97
        var hash = 0
        for scalar in fullName.unicodeScalars { hash = (hash &* 31 &+ Int(scalar.value)) & 0xFFFF }
        let mixed: Int = v1 * 47 + v2 * 23 + hash * 7
        return Double(mixed % 360) / 360
    }

    public static func rgb(hue h: Double, saturation s: Double, brightness v: Double) -> RGB {
        let i = Int(h * 6), f = h * 6 - Double(i)
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        let table = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]
        let c = table[i % 6]
        return RGB(r: c.0, g: c.1, b: c.2)
    }

    private static func shift(_ c: RGB, by d: Double) -> RGB {
        func clamp(_ x: Double) -> Double { min(1, max(0, x + d)) }
        return RGB(r: clamp(c.r), g: clamp(c.g), b: clamp(c.b))
    }
}

/// A client badge: two letters on a rounded square whose gradient comes from the client name.
/// The hardware capture client gets a microphone instead of the letters, the hardware playback client a loudspeaker.
public struct BadgeView: View {
    let client: String
    var isCapture = false
    var isPlayback = false
    var isJackMoebiusMaster = false
    var size: CGFloat = 22
    /// The application the client stands for, if known: its real icon replaces the letters.
    var bundleID: String?

    /// `isJackMoebiusMaster`: the shared input of JackMoebius, which shows the picto of JackMoebius in colour, as in JackMate.
    public init(client: String, isCapture: Bool = false, isPlayback: Bool = false, isJackMoebiusMaster: Bool = false, size: CGFloat = 22, bundleID: String? = nil) {
        self.client = client
        self.isCapture = isCapture
        self.isPlayback = isPlayback
        self.isJackMoebiusMaster = isJackMoebiusMaster
        self.size = size
        self.bundleID = bundleID
    }

    public var body: some View {
        if isJackMoebiusMaster, let picto = AppIcons.jackMoebiusPicto {
            // The picto gives its own shape and has no margin to compensate.
            Image(nsImage: picto).resizable().scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else if let id = bundleID, let icon = AppIcons.icon(forBundleID: id) {
            // The icon gives its own shape; application icons carry a transparent margin, hence the inflation.
            Image(nsImage: icon).resizable().scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(1.2)
                .accessibilityHidden(true)
        } else {
            letters
        }
    }

    private var letters: some View {
        let style = BadgeStyle(client: client, kind: isCapture ? .capture : isPlayback ? .playback : .client)
        return RoundedRectangle(cornerRadius: size * 0.28)
            .fill(LinearGradient(colors: [style.top.color, style.bottom.color], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay {
                if isCapture {
                    Image(systemName: "mic.fill").font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(.black.opacity(0.55))
                } else if isPlayback {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(.black.opacity(0.55))
                } else {
                    Text(verbatim: style.letters).font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(.black.opacity(0.55))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: size * 0.28).strokeBorder(.black.opacity(0.18), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            .accessibilityHidden(true)
    }
}

/// Up to three overlapping badges, for a channel fed by several sources.
public struct BadgeStack: View {
    let clients: [(name: String, isCapture: Bool, bundleID: String?)]
    var size: CGFloat = 16

    public init(clients: [(name: String, isCapture: Bool)], size: CGFloat = 16) {
        self.clients = clients.map { ($0.name, $0.isCapture, nil) }
        self.size = size
    }

    /// With the bundle identifier of the application each client stands for, when it is known.
    public init(clients: [(name: String, isCapture: Bool, bundleID: String?)], size: CGFloat = 16) {
        self.clients = clients
        self.size = size
    }

    public var body: some View {
        HStack(spacing: -size * 0.38) {
            ForEach(Array(clients.prefix(3).enumerated()), id: \.offset) { _, c in
                BadgeView(client: c.name, isCapture: c.isCapture, size: size, bundleID: c.bundleID)
            }
        }
    }
}

extension BadgeStyle.RGB {
    public var color: Color { Color(red: r, green: g, blue: b) }
}
