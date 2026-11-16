// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import KlickKit
import AppearanceKit

/// The pages of the window: the metronome and the tempo map first, then the settings.
struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appAccentColor) private var accent

    var body: some View {
        // The selection is drawn here, in the accent of the application: the one of a sidebar follows the accent of macOS.
        List {
            row("Métronome", "metronome", .metronome)
            row("Carte de tempo", "chart.xyaxis.line", .map)
            Section("Réglages") {
                row("Sons", "waveform", .sounds)
                row("Sortie", "speaker.wave.2", .output)
                row("Exporter", "square.and.arrow.up", .export)
                row("Affichage", "circle.lefthalf.filled", .appearance)
            }
        }
        .listStyle(.sidebar)
        .inactiveSidebarFill()
    }

    private func row(_ title: LocalizedStringKey, _ symbol: String, _ page: Page) -> some View {
        let selected = model.page == page
        return Button { model.show(page) } label: {
            Label(title, systemImage: symbol)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(RoundedRectangle(cornerRadius: 8).fill(selected ? accent : .clear).padding(.horizontal, 10))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
