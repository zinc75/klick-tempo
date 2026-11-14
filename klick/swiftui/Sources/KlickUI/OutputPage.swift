// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import AppKit
import MatrixKit
import KlickKit
import AppearanceKit

/// The output: where the sound goes (the output of the system, for now), what it announces, and the delay of the lamps for this
/// output, set by ear.
struct OutputPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sortie").font(.title2).fontWeight(.semibold)
                    Text("Où va le son du métronome, et comment les voyants lumineux se calent sur lui.").foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                GroupTitle("Moteur audio")
                Group {
                    if model.backends.count > 1 {
                        OutputRow(title: "Moteur", detail: backendDetail) {
                            Picker("Moteur", selection: Binding(get: { model.backend.id }, set: { model.switchBackend(to: $0) })) {
                                ForEach(model.backends, id: \.id) { backend in
                                    Text(verbatim: backend.name).tag(backend.id).disabled(backend.availability != .available)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    } else {
                        OutputRow(title: "État", detail: interface.stateDetail()) {
                            Text(verbatim: model.backend.name).foregroundStyle(.secondary)
                        }
                    }
                }
                .groupBox()

                interface.outputSections(model: model)

                GroupTitle("Voyants lumineux")
                VStack(spacing: 0) {
                    OffsetRow()
                    Divider()
                    OutputRow(title: "Régler à l'oreille", detail: Text("Lancez le métronome et avancez le curseur jusqu'à ce que le voyant s'allume avec le clic.")) {
                        OffsetLamp()
                        Button(LocalizedStringKey(model.isPlaying ? "Arrêter" : "Jouer")) { model.togglePlayback() }.controlSize(.small)
                    }
                }
                .groupBox()
                Text("Certaines sorties, le Bluetooth surtout, retardent le son plus qu'elles ne le disent : les voyants s'allument alors avant le clic. Le décalage est gardé pour chaque sortie.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .scrollEdgeEffectStyleIfAvailable()
        .onAppear { model.refreshOutput() }
    }

    private var interface: BackendInterface { BackendRegistry.interface(for: model.backend.id) }

    /// Under the choice of the backend: why one of them cannot be used, else what a change does.
    private var backendDetail: Text {
        let reasons = model.backends.compactMap { backend -> String? in
            if case .unavailable(let reason) = backend.availability { return "\(backend.name) : \(reason)" }
            return nil
        }
        return reasons.isEmpty ? Text("Changer de moteur arrête la lecture.") : Text(verbatim: reasons.joined(separator: "\n"))
    }
}

/// The building blocks of the page "Sortie", public so that a backend that comes from another library lays out its own groups the same way.
/// The title of a group.
public struct GroupTitle: View {
    let text: LocalizedStringKey
    public init(_ text: LocalizedStringKey) { self.text = text }
    public var body: some View { Text(text).font(.headline).padding(.top, 6) }
}

extension View {
    /// The block of glass around the rows of a group.
    public func groupBox() -> some View { self.padding(.horizontal, 14).blockBackground() }
}

/// A row of a group: title, optional detail, controls at the right.
public struct OutputRow<Controls: View>: View {
    let title: LocalizedStringKey
    var detail: Text?
    let controls: Controls

    public init(title: LocalizedStringKey, detail: Text? = nil, @ViewBuilder controls: () -> Controls) {
        self.title = title
        self.detail = detail
        self.controls = controls()
    }

    public var body: some View {
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
            Slider(value: Binding(get: { model.displayOffset }, set: { model.displayOffset = $0.rounded() }), in: -100...100, step: 5).accentTint()
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
    @Environment(\.appAccentColor) private var accent
    @Environment(AppModel.self) private var model
    @State private var lit = false

    var body: some View {
        Circle()
            .fill(lit ? accent : Color.primary.opacity(0.14))
            .frame(width: 22, height: 22)
            .shadow(color: lit ? accent.opacity(0.7) : .clear, radius: 8)
            .animation(.easeOut(duration: 0.08), value: lit)
            .onChange(of: model.player.beatCount) {
                lit = true
                Task { try? await Task.sleep(for: .milliseconds(110)); lit = false }
            }
            .accessibilityHidden(true)
    }
}
