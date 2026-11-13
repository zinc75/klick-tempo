// SPDX-License-Identifier: MIT

import SwiftUI

/// The content of the settings window: the look (dark, system, light) and the accent.
public struct AppearanceSettingsView: View {
    @Bindable var settings: AppearanceSettings

    public init(settings: AppearanceSettings) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Section {
                Picker("Apparence", selection: $settings.mode) {
                    Text("Sombre").tag(AppearanceMode.dark)
                    Text("Système").tag(AppearanceMode.system)
                    Text("Clair").tag(AppearanceMode.light)
                }
                .pickerStyle(.segmented)
            }
            Section {
                LabeledContent("Couleur d'accent") {
                    HStack(spacing: 10) {
                        Swatch(choice: .app, settings: settings)
                        Swatch(choice: .system, settings: settings)
                        Divider().frame(height: 20)
                        ForEach(AccentChoice.palette, id: \.self) { Swatch(choice: $0, settings: settings) }
                    }
                }
                Text(Self.name(of: settings.accent))
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The name shown under the swatches.
    static func name(of choice: AccentChoice) -> LocalizedStringKey {
        switch choice {
        case .app: return "Couleur de l'application"
        case .system: return "Couleur de macOS"
        case .blue: return "Bleu"
        case .purple: return "Violet"
        case .pink: return "Rose"
        case .red: return "Rouge"
        case .orange: return "Orange"
        case .green: return "Vert"
        }
    }
}

/// A round swatch; the chosen one has a ring. "macOS" shows the colours of the system as a wheel.
private struct Swatch: View {
    let choice: AccentChoice
    let settings: AppearanceSettings

    var body: some View {
        let selected = settings.accent == choice
        Button { settings.accent = choice } label: {
            ZStack {
                fill
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                if choice == .app {
                    Image(systemName: "app.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                }
            }
            .padding(3)
            .overlay(Circle().strokeBorder(selected ? Color.primary.opacity(0.7) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .help(AppearanceSettingsView.name(of: choice))
        .accessibilityLabel(AppearanceSettingsView.name(of: choice))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder private var fill: some View {
        switch choice {
        case .app: (settings.appAccent.color ?? .blue)
        case .system: AngularGradient(colors: [.blue, .purple, .pink, .red, .orange, .green, .blue], center: .center)
        default: (choice.color ?? .blue)
        }
    }
}
