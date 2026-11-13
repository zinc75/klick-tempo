// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit
import KlickEngine
import KlickKit

/// The choice between the metronome and the map. While the other one plays, the change asks for a confirmation: it stops what
/// plays, and a map starts again from its first bar. Used by the footer and by the live view.
struct ModePicker: View {
    @Environment(AppModel.self) private var model
    /// The mode asked for while the other one plays: it replaces it only once the user has confirmed.
    @State private var pendingMode: Mode?

    var body: some View {
        Picker("Lecture", selection: Binding(get: { model.player.mode ?? model.mode }, set: { requested in
            if model.isPlaying && model.player.mode != requested { pendingMode = requested } else { model.choose(requested) }
        })) {
            Text("Métronome").tag(Mode.simple)
            Text("Carte").tag(Mode.map)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .confirmationDialog(pendingMode == .map ? "Passer à la carte de tempo ?" : "Passer au métronome ?",
                            isPresented: Binding(get: { pendingMode != nil }, set: { if !$0 { pendingMode = nil } }),
                            titleVisibility: .visible, presenting: pendingMode) { mode in
            Button("Changer") { model.choose(mode) }
            Button("Annuler", role: .cancel) {}
        } message: { mode in
            Text(mode == .map ? "Le métronome s'arrête et la carte démarre depuis le début." : "La carte s'arrête et le métronome démarre.")
        }
    }
}

/// The footer of the map and settings pages: what the button will play, the button, and the command line.
struct FooterBar: View {
    @Environment(AppModel.self) private var model
    @State private var showsCommand = false

    /// What the footer talks about: what plays, or, stopped, what the button would play.
    private var shownMode: Mode { model.player.mode ?? model.mode }

    private var summary: String {
        if shownMode == .map {
            let map = model.document
            return String(localized: "Carte de tempo, \(Plural.sections(map.sections.count)), \(Plural.bars(map.totalBars))")
        }
        let s = model.settings
        return String(localized: "Mesure \(s.beats)/\(s.denominator), \(Int(s.tempo.rounded())) BPM")
    }

    private var status: LocalizedStringKey {
        guard model.isPlaying else { return "Arrêté" }
        return shownMode == .map ? "En cours : carte de tempo" : "En cours : métronome"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // The settings pages say which of the two the button plays; the two main pages decide by themselves.
                if model.page != .map {
                    ModePicker()
                }
                Text(verbatim: summary).fontWeight(.medium)
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GoButton()

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

/// The big round button: a glass disc in the colour of the accent, with a small metronome. Stopped, its rod stands upright;
/// playing, the rod swings like a pendulum, reaching one side at each beat (a beat on each side, as on a real metronome). A ring
/// spreads from the disc at the first beat of each bar. Under the pointer the disc swells and glows.
struct GoButton: View {
    @Environment(AppModel.self) private var model
    /// 54 in the footer; larger on the metronome page.
    var diameter: CGFloat = 54
    @State private var isHovered = false
    /// 0 when a ring starts, 1 when it is gone.
    @State private var ring = 1.0
    @Environment(\.colorScheme) private var colorScheme

    private var scale: CGFloat { diameter / 54 }
    private static let swingDegrees = 24.0

    var body: some View {
        let player = model.player
        Button { model.togglePlayback() } label: {
            TimelineView(.animation(paused: !model.isPlaying)) { timeline in
                MetronomeGlyph(angle: rodAngle(at: timeline.date))
            }
            .scaleEffect(0.84)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
            .animation(model.isPlaying ? nil : .spring(duration: 0.4, bounce: 0.3), value: model.isPlaying)
            .frame(width: 54, height: 54)
            .accentGlassDisc()
            .shadow(color: Color.accentColor.opacity(isHovered ? 0.55 : 0), radius: isHovered ? 12 : 0)
            .scaleEffect(isHovered ? 1.08 : 1)
            .scaleEffect(scale)
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering in withAnimation(.spring(duration: 0.22, bounce: 0.35)) { isHovered = hovering } }
        .background {
            // one ring per bar, from the first beat: it appears at once at the size of the disc, then spreads while it fades
            Circle().stroke(Color.accentColor.mix(with: colorScheme == .dark ? .white : Color(white: 0.25), by: max(0, 1 - ring * 10)).opacity(0.5), lineWidth: 2)   // white (dark mode) or black (light mode) at the start, then the accent
                .frame(width: diameter, height: diameter)
                .scaleEffect(1 + 0.55 * ring)
                .opacity(model.isPlaying && ring < 1 ? 1 - ring : 0)
        }
        .onChange(of: player.barCount) {
            guard player.barCount > 0 else { return }
            ring = 0
            Task {
                try? await Task.sleep(for: .milliseconds(30))   // let the first state be drawn before it spreads
                withAnimation(.easeOut(duration: max(0.15, player.beatDuration))) { ring = 1 }   // spreads for one beat
            }
        }
        .accessibilityLabel(model.isPlaying ? "Arrêter" : "Démarrer")
        .help(model.isPlaying ? "Arrêter (barre d'espace)" : "Démarrer (barre d'espace)")
    }

    /// The rod is at one end of its swing at each beat, on alternate sides. It leaves that end gently, speeds up and reaches the
    /// other end exactly on the next beat, where it stops dead, so that the beat reads as a hit.
    private func rodAngle(at now: Date) -> Double {
        let player = model.player
        guard model.isPlaying, player.beatCount > 0 else { return 0 }
        let progress = min(1, max(0, now.timeIntervalSince(player.lastBeatTime) / player.beatDuration))
        let side = player.beatCount.isMultiple(of: 2) ? 1.0 : -1.0
        let travel = 1 - 2 * pow(progress, 1.25)                       // +1 at the beat, -1 at the next one, fastest on arrival
        return side * Self.swingDegrees * travel
    }
}

/// A metronome: the tapered case with its window, the base, the hub, and the rod with its weight, which turns about the hub
/// (degrees from upright). Drawn white, to be put on a coloured disc.
struct MetronomeGlyph: View {
    var angle: Double

    var body: some View {
        ZStack {
            // the case: a soft body with a lit edge
            CaseShape()
                .fill(LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0.10)], startPoint: .top, endPoint: .bottom))
                .frame(width: 25, height: 33)
                .offset(y: 1)
            CaseShape()
                .stroke(.white, style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))
                .frame(width: 25, height: 33)
                .offset(y: 1)
            // the window where the rod swings
            Capsule().fill(.black.opacity(0.22)).frame(width: 3.4, height: 20).offset(y: -1)
            // the base
            RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 30, height: 4).offset(y: 18.5)
            // the rod and its weight, turning about the hub
            ZStack {
                Capsule().frame(width: 2, height: 36)
                RoundedRectangle(cornerRadius: 1.6).frame(width: 8.5, height: 5.5).offset(y: -4)
                RoundedRectangle(cornerRadius: 0.5).fill(.black.opacity(0.25)).frame(width: 8.5, height: 0.9).offset(y: -4)
            }
            .frame(width: 12, height: 36)
            .rotationEffect(.degrees(angle), anchor: .init(x: 0.5, y: 1))
            .offset(y: -6)
            // the hub
            Circle().fill(.white).frame(width: 5.5, height: 5.5).offset(y: 12)
            Circle().fill(.black.opacity(0.3)).frame(width: 1.8, height: 1.8).offset(y: 12)
        }
        .frame(width: 34, height: 44)
    }

    /// A tapered case with rounded corners.
    private struct CaseShape: Shape {
        func path(in r: CGRect) -> Path {
            let inset = r.width * 0.24
            let corners = [CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY),
                           CGPoint(x: r.maxX - inset, y: r.minY), CGPoint(x: r.minX + inset, y: r.minY)]
            var p = Path()
            p.move(to: CGPoint(x: (corners[3].x + corners[0].x) / 2, y: (corners[3].y + corners[0].y) / 2))
            for i in 0..<4 { p.addArc(tangent1End: corners[i], tangent2End: corners[(i + 1) % 4], radius: 3) }
            p.closeSubpath()
            return p
        }
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
