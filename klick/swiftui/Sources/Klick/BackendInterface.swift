// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import AppKit
import KlickKit
import AppearanceKit

/// What the window shows of a backend: its lines on the page "Sortie" and the part of the menu of the pill that is its own. The
/// backend itself (KlickKit) has no UI; a backend that comes from another library brings its interface the same way.
@MainActor
protocol BackendInterface {
    var backendID: String { get }
    /// What the line "État" of the page says under its title, when there is a single backend.
    func stateDetail() -> Text?
    /// The groups of the page "Sortie" that belong to this backend.
    func outputSections(model: AppModel) -> AnyView
    /// What the menu of the pill shows for this backend, below the choice of the backend.
    func pillMenu(model: AppModel, close: @escaping () -> Void) -> AnyView
}

/// The interfaces of the backends the application offers, by backend id.
@MainActor
enum BackendRegistry {
    static var interfaces: [BackendInterface] = [CoreAudioInterface()]

    /// The interface of a backend; a plain one (its output and rate) when none was registered.
    static func interface(for id: String) -> BackendInterface {
        interfaces.first { $0.backendID == id } ?? PlainInterface(backendID: id)
    }
}

/// A backend without anything of its own to show.
struct PlainInterface: BackendInterface {
    let backendID: String

    func stateDetail() -> Text? { nil }
    func outputSections(model: AppModel) -> AnyView { AnyView(EmptyView()) }
    func pillMenu(model: AppModel, close: @escaping () -> Void) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: model.output.name).font(.caption).fontWeight(.medium)
                Text(verbatim: "\(model.backend.name) · \((model.output.sampleRate / 1000).formatted(.number.precision(.fractionLength(0...1)))) kHz")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.bottom, 4)
        )
    }
}

// MARK: CoreAudio

/// CoreAudio: the output device of the system, followed, or one that is chosen; what it announces.
struct CoreAudioInterface: BackendInterface {
    let backendID = "coreaudio"

    func stateDetail() -> Text? { Text("CoreAudio : Klick joue sur la sortie choisie ci-dessous.") }

    func outputSections(model: AppModel) -> AnyView { AnyView(CoreAudioSections()) }

    func pillMenu(model: AppModel, close: @escaping () -> Void) -> AnyView { AnyView(CoreAudioPillMenu(close: close)) }
}

private struct CoreAudioSections: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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

/// The outputs to choose from: the system's, followed, or one of the devices.
private struct CoreAudioPillMenu: View {
    let close: () -> Void
    @Environment(AppModel.self) private var model

    private var rate: String {
        (model.output.sampleRate / 1000).formatted(.number.precision(.fractionLength(0...1))) + " kHz"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Sortie").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.bottom, 4)
            PillRow(title: Text("Suivre le système"), detail: model.settings.outputDeviceUID == nil ? model.output.name : nil,
                    selected: model.settings.outputDeviceUID == nil, close: close) {
                model.chooseOutput(uid: nil)
            }
            ForEach(model.outputDevices) { device in
                PillRow(title: Text(verbatim: device.name), detail: nil, selected: model.settings.outputDeviceUID == device.uid, close: close) {
                    model.chooseOutput(uid: device.uid)
                }
            }
            if model.isChosenOutputMissing {
                Label("La sortie choisie n'est pas branchée.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(Color.alert).padding(.horizontal, 10).padding(.vertical, 4)
            }
            Divider().padding(.vertical, 4)
            // What plays now: the output, the rate of the device (the engine works at its own rate, CoreAudio converts) and the
            // latency it announces.
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: model.output.name).font(.caption).fontWeight(.medium)
                Text(verbatim: "CoreAudio · \(rate) · \(Int(model.output.latencyMilliseconds.rounded())) ms")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.bottom, 4)
            PillRow(title: Text("Réglages de la sortie…"), detail: nil, selected: nil, close: close) { model.show(.output) }
        }
    }
}
