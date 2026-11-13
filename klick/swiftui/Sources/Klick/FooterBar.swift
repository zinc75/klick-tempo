// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit
import KlickEngine
import KlickKit

/// The footer of the map and settings pages: what the button will play, the button, and the command line.
struct FooterBar: View {
    @Environment(AppModel.self) private var model
    @State private var showsCommand = false

    private var summary: String {
        if model.mode == .map {
            let map = model.document
            return String(localized: "Carte de tempo, \(Plural.sections(map.sections.count)), \(Plural.bars(map.totalBars))")
        }
        let s = model.settings
        return String(localized: "Mesure \(s.beats)/\(s.denominator), \(Int(s.tempo.rounded())) BPM")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // The settings pages say which of the two the button plays; the two main pages decide by themselves.
                if model.page != .map {
                    Picker("Lecture", selection: Binding(get: { model.mode }, set: { model.choose($0) })) {
                        Text("Métronome").tag(Mode.simple)
                        Text("Carte").tag(Mode.map)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                Text(verbatim: summary).fontWeight(.medium)
                Text(model.isPlaying ? "En cours" : "Arrêté").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GoButton(isPlaying: model.isPlaying) { model.togglePlayback() }

            HStack {
                Button("Ligne de commande") { showsCommand = true }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .sheet(isPresented: $showsCommand) { CommandSheet() }
        .padding(.horizontal, 24)
        .frame(height: 88)
        .background(Color.windowFill)
        .overlay(alignment: .top) { Divider() }
    }
}

/// The big round button: an accent glass disc with the play triangle, and the stop square while something plays.
struct GoButton: View {
    let isPlaying: Bool
    var diameter: CGFloat = 58
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: diameter * 0.4, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                .offset(x: isPlaying ? 0 : diameter * 0.02)
                .frame(width: diameter, height: diameter)
                .accentGlassDisc()
                .shadow(color: Color.accentColor.opacity(isHovered ? 0.55 : 0.0), radius: 12)
                .scaleEffect(isHovered ? 1.06 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering in withAnimation(.spring(duration: 0.22, bounce: 0.35)) { isHovered = hovering } }
        .accessibilityLabel(isPlaying ? "Arrêter" : "Démarrer")
        .help(isPlaying ? "Arrêter (barre d'espace)" : "Démarrer (barre d'espace)")
    }
}

/// No chrome, and a small dip under the click, as the glass of a button gives.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

/// The command line that does the same from the Terminal.
struct CommandSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var text: String {
        KlickCommand.text(settings: model.settings, mode: model.mode, mapFile: model.document.name, connectToPhysicalOutputs: false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ligne de commande équivalente").font(.title3).fontWeight(.semibold)
            Text("Ce que Klick lance pour jouer ce métronome. Utilisable telle quelle dans le Terminal.").foregroundStyle(.secondary)
            Text(verbatim: text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Button("Copier") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Spacer()
                Button("Fermer") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
