// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import KlickEngine
import KlickKit
import AppearanceKit

/// Says that what plays is driven by the transport of the backend (JACK): it waits for the transport to roll, or it plays with it.
/// Nothing when the transport is not followed.
struct TransportBadge: View {
    @Environment(\.appAccentColor) private var accent
    @Environment(AppModel.self) private var model

    var body: some View {
        let state = model.player.transport.state
        if model.isPlaying, state != .off {
            Label(LocalizedStringKey(state == .rolling ? "Piloté par le transport JACK" : "En attente du transport JACK"),
                  systemImage: state == .rolling ? "link" : "hourglass")
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(state == .rolling ? accent : Color.secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(state == .rolling ? accent.opacity(0.16) : Color.primary.opacity(0.08)))
                .help("Le départ et l'arrêt suivent le transport JACK. Le bouton arrête ; un nouvel appui remet en attente.")
        }
    }
}

/// Another client of JACK is the timebase master: the metronome takes its tempo and meter, a tempo map keeps its own (and says so).
struct ExternalMasterNote: View {
    @Environment(AppModel.self) private var model
    let mode: Mode

    var body: some View {
        let info = model.player.transport
        if model.isPlaying, info.state != .off, info.hasExternalMaster, model.player.mode == mode {
            Label {
                if mode == .simple {
                    Text("Tempo et mesure du maître de timebase JACK : \(Int(info.tempo.rounded())) BPM, \(info.beats)/\(info.denominator)")
                } else {
                    Text("Un autre client JACK est maître de timebase : la carte garde son tempo, qui peut différer du sien.")
                }
            } icon: {
                Image(systemName: mode == .simple ? "metronome" : "exclamationmark.triangle")
            }
            .font(.caption).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }
}
