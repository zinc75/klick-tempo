// SPDX-License-Identifier: MIT

import SwiftUI

extension AccentChoice {
    /// The name shown for the choice (French texts are the keys of the string catalog of the application).
    public var displayName: LocalizedStringKey {
        switch self {
        case .app: return "Couleur de l'application"
        case .system: return "Couleur système"
        case .blue: return "Bleu"
        case .purple: return "Violet"
        case .pink: return "Rose"
        case .red: return "Rouge"
        case .orange: return "Orange"
        case .green: return "Vert"
        }
    }
}

/// The look: three small windows to choose from, as in the settings of macOS: dark, the one of the system (half and half), and
/// light. The chosen one has a ring in the accent. The application puts it where it wants in its page.
public struct AppearanceModePicker: View {
    @Bindable var settings: AppearanceSettings

    public init(settings: AppearanceSettings) {
        self.settings = settings
    }

    public var body: some View {
        HStack(spacing: 14) {
            Tile(mode: .dark, title: "Sombre", settings: settings)
            Tile(mode: .system, title: "Système", settings: settings)
            Tile(mode: .light, title: "Clair", settings: settings)
        }
    }
}

private struct Tile: View {
    let mode: AppearanceMode
    let title: LocalizedStringKey
    let settings: AppearanceSettings
    @Environment(\.appAccentColor) private var accent

    var body: some View {
        let selected = settings.mode == mode
        Button { settings.mode = mode } label: {
            VStack(spacing: 5) {
                preview
                    .frame(width: 84, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5))
                    .padding(3)
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(selected ? accent : .clear, lineWidth: 2.5))
                Text(title).font(.callout).fontWeight(selected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// The miniature: a dark window, a light one, or both cut along a diagonal.
    @ViewBuilder private var preview: some View {
        switch mode {
        case .dark: MiniWindow(dark: true, accent: accent)
        case .light: MiniWindow(dark: false, accent: accent)
        case .system:
            ZStack {
                MiniWindow(dark: false, accent: accent)
                MiniWindow(dark: true, accent: accent)
                    .mask(GeometryReader { g in
                        Path { p in
                            p.move(to: CGPoint(x: g.size.width * 0.62, y: 0))
                            p.addLine(to: CGPoint(x: g.size.width, y: 0))
                            p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                            p.addLine(to: CGPoint(x: g.size.width * 0.38, y: g.size.height))
                            p.closeSubpath()
                        }
                    })
            }
        }
    }
}

/// A window of a few lines: a bar, a sidebar with the chosen row in the accent, and the page.
private struct MiniWindow: View {
    let dark: Bool
    let accent: Color

    var body: some View {
        let page = dark ? Color(white: 0.13) : Color(white: 0.97)
        let side = dark ? Color(white: 0.09) : Color(white: 0.90)
        let line = dark ? Color(white: 0.32) : Color(white: 0.78)
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(accent).frame(width: 20, height: 6)
                Capsule().fill(line).frame(width: 18, height: 4)
                Capsule().fill(line).frame(width: 14, height: 4)
                Spacer()
            }
            .padding(.top, 14).padding(.horizontal, 5)
            .frame(width: 30)
            .frame(maxHeight: .infinity)
            .background(side)
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(line).frame(width: 30, height: 5)
                RoundedRectangle(cornerRadius: 3).fill(line.opacity(0.6)).frame(height: 14)
                RoundedRectangle(cornerRadius: 3).fill(line.opacity(0.6)).frame(height: 8)
                Spacer()
            }
            .padding(.top, 14).padding(.horizontal, 7)
            .frame(maxWidth: .infinity)
            .background(page)
        }
    }
}

/// The accent: six round swatches, and under them two buttons, "the colour of the application" and "the colour of the system".
/// The chosen one has a ring. For a swatch the name is `settings.accent.displayName` (also its tooltip).
public struct AccentSwatches: View {
    @Bindable var settings: AppearanceSettings

    public init(settings: AppearanceSettings) {
        self.settings = settings
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(AccentChoice.palette, id: \.self) { Swatch(choice: $0, settings: settings) }
            }
            HStack(spacing: 8) {
                SourceButton(choice: .app, color: settings.appTint, settings: settings)
                SourceButton(choice: .system, color: AccentChoice.systemColor, settings: settings)
            }
        }
    }
}

/// A round swatch of the palette.
private struct Swatch: View {
    let choice: AccentChoice
    let settings: AppearanceSettings

    var body: some View {
        let selected = settings.accent == choice
        Button { settings.accent = choice } label: {
            (choice.color ?? .blue)
                .frame(width: 20, height: 20)
                .clipShape(Circle())
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? Color.primary.opacity(0.7) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .help(choice.displayName)
        .accessibilityLabel(choice.displayName)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// A button with the name of where the colour comes from, and a dot of that colour.
private struct SourceButton: View {
    let choice: AccentChoice
    let color: Color
    let settings: AppearanceSettings

    var body: some View {
        let selected = settings.accent == choice
        Button { settings.accent = choice } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(choice.displayName).font(.callout)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(selected ? 0.14 : 0.06)))
            .overlay(Capsule().strokeBorder(selected ? Color.primary.opacity(0.6) : .clear, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
