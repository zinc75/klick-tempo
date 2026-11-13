// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import KlickKit

/// The pages of the window: the metronome and the tempo map first, then the settings.
struct Sidebar: View {
    @Environment(AppModel.self) private var model

    private var selection: Binding<Page?> {
        Binding(get: { model.page }, set: { if let page = $0 { model.show(page) } })
    }

    var body: some View {
        List(selection: selection) {
            Label("Métronome", systemImage: "metronome").tag(Page.metronome)
            Label("Carte de tempo", systemImage: "chart.xyaxis.line").tag(Page.map)
            Section("Réglages") {
                Label("Sons", systemImage: "waveform").tag(Page.sounds)
                Label("Sortie", systemImage: "speaker.wave.2").tag(Page.output)
                Label("Exporter", systemImage: "square.and.arrow.up").tag(Page.export)
            }
        }
        .listStyle(.sidebar)
    }
}
