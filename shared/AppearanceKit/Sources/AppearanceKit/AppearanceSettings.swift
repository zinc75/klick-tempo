// SPDX-License-Identifier: MIT

import SwiftUI
import AppKit
import Observation

/// Dark whatever the system says (the look of the Jack apps and of JackMate), the look of the system, or light.
public enum AppearanceMode: String, CaseIterable, Sendable {
    case dark, system, light

    /// The appearance to give the application; nil follows the system.
    public var nsAppearance: NSAppearance? {
        switch self {
        case .dark: return NSAppearance(named: .darkAqua)
        case .light: return NSAppearance(named: .aqua)
        case .system: return nil
        }
    }
}

/// The accent: the colour of the application, the one of macOS, or one of a short palette.
public enum AccentChoice: String, CaseIterable, Sendable {
    case app, system
    case blue, purple, pink, red, orange, green

    /// The colours on offer, in the order of the macOS accent settings (without yellow and graphite).
    public static let palette: [AccentChoice] = [.blue, .purple, .pink, .red, .orange, .green]

    /// The system colour of a palette entry; nil for "app" and "system", which have to be resolved first.
    public var color: Color? {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .app, .system: return nil
        }
    }
}

/// What the user chose for the look of an application, kept between two launches. The same for every application of the
/// collection; each one gives its own colour, which "the colour of the application" stands for.
@MainActor @Observable
public final class AppearanceSettings {
    public static let modeKey = "appearance"
    public static let accentKey = "accent"

    /// The colour of the application, one of the palette.
    public let appAccent: AccentChoice

    public var mode: AppearanceMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.modeKey); applyAppearance() }
    }

    public var accent: AccentChoice {
        didSet { defaults.set(accent.rawValue, forKey: Self.accentKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Reads the saved choices; a value that is not known (a newer or older version, a hand edit) falls back to the default:
    /// dark and the colour of the application. The key of the mode is the one of the first versions, which kept "light" or "dark".
    public init(appAccent: AccentChoice, defaults: UserDefaults = .standard) {
        self.appAccent = AccentChoice.palette.contains(appAccent) ? appAccent : .blue
        self.defaults = defaults
        mode = defaults.string(forKey: Self.modeKey).flatMap(AppearanceMode.init(rawValue:)) ?? .dark
        accent = defaults.string(forKey: Self.accentKey).flatMap(AccentChoice.init(rawValue:)) ?? .app
    }

    /// The colour of the palette the accent comes to; nil when it follows macOS.
    public var effectiveAccent: AccentChoice? {
        switch accent {
        case .app: return appAccent
        case .system: return nil
        default: return accent
        }
    }

    /// The tint to give the windows; nil leaves the accent of macOS.
    public var tint: Color? { effectiveAccent?.color }

    public func applyAppearance() { NSApp?.appearance = mode.nsAppearance }

    /// The look a click on the quick toggle goes to (the sun or the moon of a toolbar): from dark to light and back, and from
    /// "system" to the opposite of what the system shows now.
    public func toggled(currentlyDark: Bool) -> AppearanceMode { currentlyDark ? .light : .dark }
}

extension View {
    /// Gives the window the accent chosen in the settings.
    public func appAccent(_ settings: AppearanceSettings) -> some View {
        modifier(AccentModifier(settings: settings))
    }
}

private struct AccentModifier: ViewModifier {
    let settings: AppearanceSettings

    func body(content: Content) -> some View {
        if let tint = settings.tint {
            content.tint(tint)
        } else {
            content
        }
    }
}
