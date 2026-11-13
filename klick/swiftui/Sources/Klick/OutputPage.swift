// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import AppKit
import MatrixKit
import KlickKit

/// The output: where the sound goes (the output of the system, for now), what it announces, and the delay of the lamps for this
/// output, set by ear.
struct OutputPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sortie").font(.title2).fontWeight(.semibold)
                    Text("Où va le son du métronome, et comment les lampes se calent sur lui.").foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                GroupTitle("Moteur audio")
                Group {
                    OutputRow(title: "État", detail: Text("CoreAudio : Klick joue sur la sortie choisie ci-dessous.")) {
                        Text(verbatim: "CoreAudio").foregroundStyle(.secondary)
                    }
                }
                .groupBox()

                GroupTitle("CoreAudio")
                VStack(spacing: 0) {
                    OutputRow(title: "Sortie", detail: outputDetail) {
                        Picker("Sortie", selection: Binding(get: { model.settings.outputDeviceUID }, set: { model.chooseOutput(uid: $0) })) {
                            Text("Suivre le système").tag(String?.none)
                            Divider()
                            ForEach(model.outputDevices) { device in Text(verbatim: device.name).tag(Optional(device.uid)) }
                            if let uid = model.settings.outputDeviceUID, !model.outputDevices.contains(where: { $0.uid == uid }) {
                                Text("Sortie absente").tag(Optional(uid))
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button("Réglages du son…") { openSoundSettings() }.controlSize(.small)
                    }
                    Divider()
                    OutputRow(title: "Fréquence d'échantillonnage", detail: Text("Klick joue à \(model.player.sampleRate / 1000, format: .number.precision(.fractionLength(0...1))) kHz et CoreAudio convertit.")) {
                        Text(verbatim: kHz(model.output.sampleRate))
                    }
                    Divider()
                    OutputRow(title: "Latence annoncée", detail: Text("Ce que la sortie dit : les lampes en tiennent compte.")) {
                        Text(verbatim: milliseconds(model.output.latencyMilliseconds))
                    }
                    Divider()
                    OutputRow(title: "Tampon", detail: Text("Plus petit : moins de retard, plus de risques de craquements. Klick prend celui que la sortie utilise.")) {
                        Text("\(model.output.bufferFrames) échantillons")
                    }
                }
                .groupBox()

                GroupTitle("Lampes")
                VStack(spacing: 0) {
                    OffsetRow()
                    Divider()
                    OutputRow(title: "Régler à l'oreille", detail: Text("Lancez le métronome et avancez le curseur jusqu'à ce que la lampe s'allume avec le clic.")) {
                        OffsetLamp()
                        Button(LocalizedStringKey(model.isPlaying ? "Arrêter" : "Jouer")) { model.togglePlayback() }.controlSize(.small)
                    }
                }
                .groupBox()
                Text("Certaines sorties, le Bluetooth surtout, retardent le son plus qu'elles ne le disent : les lampes s'allument alors avant le clic. Le décalage est gardé pour chaque sortie.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .scrollEdgeEffectStyleIfAvailable()
        .onAppear { model.refreshOutput() }
    }

    private var outputDetail: Text {
        if model.isChosenOutputMissing { return Text("La sortie choisie n'est pas branchée : Klick joue sur la sortie du système.") }
        return model.settings.outputDeviceUID == nil
            ? Text("Klick suit la sortie du système : \(model.output.name).")
            : Text("Jouer ici ne change pas la sortie du système.")
    }

    private func kHz(_ rate: Double) -> String {
        rate > 0 ? (rate / 1000).formatted(.number.precision(.fractionLength(0...1))) + " kHz" : "—"
    }

    private func milliseconds(_ value: Double) -> String { "\(Int(value.rounded())) ms" }

    private func openSoundSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") { NSWorkspace.shared.open(url) }
    }
}

private struct GroupTitle: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }
    var body: some View { Text(text).font(.headline).padding(.top, 6) }
}

private extension View {
    func groupBox() -> some View { self.padding(.horizontal, 14).blockBackground() }
}

/// A row of a group: title, optional detail, controls at the right.
private struct OutputRow<Controls: View>: View {
    let title: LocalizedStringKey
    var detail: Text?
    @ViewBuilder let controls: Controls

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let detail { detail.font(.caption).foregroundStyle(.tertiary) }
            }
            Spacer(minLength: 12)
            controls
        }
        .padding(.vertical, 9)
    }
}

/// The delay of the lamps for the output in use, from -100 to +100 ms: later than what the output announces (a positive number,
/// Bluetooth) or sooner (a negative one; the player never goes below the moment the beat is scheduled).
private struct OffsetRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        OutputRow(title: "Décalage pour cette sortie", detail: detail) {
            Slider(value: Binding(get: { model.displayOffset }, set: { model.displayOffset = $0.rounded() }), in: -100...100, step: 5)
                .frame(width: 180)
            Text(verbatim: model.displayOffset == 0 ? "0 ms" : String(format: "%+d ms", Int(model.displayOffset))).font(.system(.callout, design: .monospaced))
                .frame(width: 72, alignment: .trailing)
            Button("Remettre à 0") { model.displayOffset = 0 }.controlSize(.small).disabled(model.displayOffset == 0)
        }
    }

    private var detail: Text {
        model.output.isBluetooth
            ? Text("Sortie Bluetooth (\(model.output.name)) : elle retarde souvent le son plus qu'elle ne l'annonce.")
            : Text("Sortie : \(model.output.name).")
    }
}

/// A lamp that flashes with each beat heard, to set the delay by.
private struct OffsetLamp: View {
    @Environment(AppModel.self) private var model
    @State private var lit = false

    var body: some View {
        Circle()
            .fill(lit ? Color.accentColor : Color.primary.opacity(0.14))
            .frame(width: 22, height: 22)
            .shadow(color: lit ? Color.accentColor.opacity(0.7) : .clear, radius: 8)
            .animation(.easeOut(duration: 0.08), value: lit)
            .onChange(of: model.player.beatCount) {
                lit = true
                Task { try? await Task.sleep(for: .milliseconds(110)); lit = false }
            }
            .accessibilityHidden(true)
    }
}
