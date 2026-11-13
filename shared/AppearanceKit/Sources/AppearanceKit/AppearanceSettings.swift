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

    /// The accent chosen by the user in the settings of macOS (the one of the control of the system, not the default of SwiftUI).
    public static var systemColor: Color { Color(nsColor: .controlAccentColor) }

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

    /// The colour of the application: one of the palette, or an own colour given by the application (a warmer orange than the
    /// one of the system, say), which then stands in for it.
    public let appAccent: AccentChoice
    public let appColor: Color?

    public var mode: AppearanceMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.modeKey); applyAppearance() }
    }

    public var accent: AccentChoice {
        didSet { defaults.set(accent.rawValue, forKey: Self.accentKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Reads the saved choices; a value that is not known (a newer or older version, a hand edit) falls back to the default:
    /// dark and the colour of the application. The key of the mode is the one of the first versions, which kept "light" or "dark".
    public init(appAccent: AccentChoice, appColor: Color? = nil, defaults: UserDefaults = .standard) {
        self.appAccent = AccentChoice.palette.contains(appAccent) ? appAccent : .blue
        self.appColor = appColor
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

    /// The colour of the application as it is drawn.
    public var appTint: Color { appColor ?? appAccent.color ?? .blue }

    /// The colour to draw with: nil when it follows macOS.
    public var tint: Color? { accent == .app ? appTint : effectiveAccent?.color }

    public func applyAppearance() { NSApp?.appearance = mode.nsAppearance }
}

private struct AppAccentKey: EnvironmentKey {
    static let defaultValue: Color = AccentChoice.systemColor
}

extension EnvironmentValues {
    /// The accent of the application: the colour chosen in the settings, the accent of macOS when the user follows it. Views read
    /// it instead of `Color.accentColor`, which SwiftUI keeps at the accent of macOS whatever `.tint` says, and so does the
    /// selection of a sidebar.
    public var appAccentColor: Color {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
}

extension View {
    /// Gives the window the accent chosen in the settings, for the views that read `appAccentColor`. It does not tint the
    /// controls of the system by itself: a tint changes the text of every bordered button too. A control that has to show the
    /// accent (a slider, a switch, a prominent button) says so with `accentTint()`.
    public func appAccent(_ settings: AppearanceSettings) -> some View {
        environment(\.appAccentColor, settings.tint ?? AccentChoice.systemColor)
    }

    /// Shows the accent of the application on this control.
    public func accentTint() -> some View {
        modifier(AccentTintModifier())
    }
}

private struct AccentTintModifier: ViewModifier {
    @Environment(\.appAccentColor) private var accent

    func body(content: Content) -> some View {
        content.tint(accent)
    }
}
