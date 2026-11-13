// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit
import KlickEngine
import KlickKit

/// The metronome: the tempo and the beats at the top, then the tap tempo, the speed trainer and the start.
struct MetronomePage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HeroCard()
                // The three cards side by side: the page stays short enough for a small laptop screen.
                HStack(alignment: .top, spacing: 14) {
                    TapTempoCard()
                    TrainerCard()
                    StartCard()
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .scrollEdgeEffectStyleIfAvailable()
    }
}

// MARK: hero

private struct HeroCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let player = model.player
        let counting = player.phase == .countIn
        VStack(spacing: 8) {
            // The tempo, or the count-in while it runs.
            HStack(spacing: 22) {
                VStack(spacing: 6) {
                    NudgeButton(label: "−10") { model.nudgeTempo(-10) }
                    NudgeButton(label: "−1") { model.nudgeTempo(-1) }
                }
                Text(verbatim: counting ? "\(player.countInRemaining)" : "\(Int(shownTempo.rounded()))")
                    .font(.system(size: 100, weight: .ultraLight))
                    .monospacedDigit()
                    .frame(minWidth: 230)
                    .contentTransition(.numericText())
                    .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                        // Drag up or down on the number: three points for a unit.
                        model.settings.tempo = AppModel.clamped(dragStart(model.settings.tempo) - value.translation.height / 3)
                    }.onEnded { _ in dragOrigin = nil })
                    .help("Glisser vers le haut ou le bas pour changer le tempo, ou toucher ↑ ↓ ← → au clavier. T pour taper le tempo.")
                VStack(spacing: 6) {
                    NudgeButton(label: "+10") { model.nudgeTempo(10) }
                    NudgeButton(label: "+1") { model.nudgeTempo(1) }
                }
            }
            Text(counting ? "DÉCOMPTE" : "BATTEMENTS PAR MINUTE").font(.caption).tracking(1.5).foregroundStyle(.tertiary)
            Text(verbatim: TempoWord.name(for: model.settings.tempo)).font(.title3).italic().foregroundStyle(.secondary)
            Slider(value: $model.settings.tempo, in: AppModel.tempoRange, step: 1)
                .frame(maxWidth: 620)
                .padding(.top, 6)

            BeatLamps(lit: lit)
                .padding(.top, 10)

            StaffView(layout: StaffLayout(beats: model.settings.beats, denominator: model.settings.denominator, pattern: model.settings.pattern),
                      lit: lit)
                .padding(.top, 4)

            HStack {
                MeterControls().frame(maxWidth: .infinity, alignment: .leading)
                GoButton(diameter: 84)
                VolumeControls().frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 14).padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .blockBackground(cornerRadius: 16)
        .onChange(of: model.player.beatCount) {
            guard let beat = model.player.beat else { return }
            let index = beat.beat
            lit = index
            Task {
                try? await Task.sleep(for: .milliseconds(110))
                if lit == index { lit = nil }
            }
        }
    }

    /// The tempo that is set, or, while the speed trainer runs, the one that plays now (it rises bar after bar).
    private var shownTempo: Double {
        let player = model.player
        return model.settings.trainer.isEnabled && player.phase == .playing && player.tempo > 0 ? player.tempo : model.settings.tempo
    }

    // The beat that is heard now, for the lamps and the staff: lit for a moment at each beat.
    @State private var lit: Int?

    // The value of the tempo when a drag starts, kept for the length of the gesture.
    @State private var dragOrigin: Double?
    private func dragStart(_ current: Double) -> Double {
        if let dragOrigin { return dragOrigin }
        dragOrigin = current
        return current
    }

}

private struct NudgeButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { Text(verbatim: label).frame(width: 38) }
            .buttonStyle(.bordered)
            .controlSize(.small)
    }
}

// MARK: beats

/// One lamp per beat of the bar: it flashes with the click; a click on a lamp changes its accent (accent, normal, silent).
private struct BeatLamps: View {
    @Environment(AppModel.self) private var model
    let lit: Int?

    var body: some View {
        let pattern = Array(model.settings.pattern)
        let small = pattern.count > 8
        HStack(spacing: small ? 10 : 18) {
            ForEach(pattern.indices, id: \.self) { i in
                VStack(spacing: 4) {
                    Button { cycle(i) } label: {
                        Text(verbatim: pattern[i] == "." ? "·" : "\(i + 1)")
                            .font(.system(size: small ? 14 : 18, weight: .semibold))
                            .frame(width: size(pattern[i], small: small), height: size(pattern[i], small: small))
                            .background(Circle().fill(fill(pattern[i], isLit: lit == i)))
                            .overlay { if pattern[i] == "." { Circle().strokeBorder(.quaternary, lineWidth: 1.5) } }
                            // A silent beat has no fill: without this only the dot would take the click.
                            .contentShape(Circle())
                            .foregroundStyle(lit == i ? Color.white : .secondary)
                            .shadow(color: lit == i ? Color.accentColor.opacity(0.7) : .clear, radius: 14)
                            .scaleEffect(lit == i ? 1.1 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Temps \(i + 1)")
                    Text(verbatim: String(pattern[i])).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(.tertiary)
                }
                .frame(minWidth: 50)
            }
        }
        .frame(minHeight: 76)
        .animation(.easeOut(duration: 0.08), value: lit)
    }

    private func size(_ c: Character, small: Bool) -> CGFloat {
        c == "X" ? (small ? 46 : 58) : (small ? 38 : 48)
    }

    private func fill(_ c: Character, isLit: Bool) -> Color {
        if c == "." { return .clear }
        if isLit { return Color.accentColor }
        return Color.primary.opacity(0.12)
    }

    private func cycle(_ i: Int) {
        var chars = Array(model.settings.pattern)
        chars[i] = chars[i] == "X" ? "x" : chars[i] == "x" ? "." : "X"
        model.settings.pattern = String(chars)
    }
}

// MARK: meter and volume

private struct MeterControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 8) {
            Text("Mesure").font(.callout).foregroundStyle(.secondary).fixedSize()
            Picker("Temps par mesure", selection: Binding(get: { model.settings.beats }, set: { model.settings.setBeats($0) })) {
                ForEach(MeterRules.numerators(for: model.settings.denominator, including: model.settings.beats), id: \.self) { Text(verbatim: "\($0)").tag($0) }
            }
            .labelsHidden()
            .frame(width: 64)
            Text(verbatim: "/").foregroundStyle(.secondary)
            Picker("Valeur du temps", selection: Binding(get: { model.settings.denominator }, set: { model.settings.setDenominator($0) })) {
                ForEach(MeterRules.denominators, id: \.self) { Text(verbatim: "\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }
}

private struct VolumeControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                Text("Volume").font(.callout).foregroundStyle(.secondary)
                Slider(value: $model.settings.masterVolume, in: 0...1).frame(width: 96)
                    .disabled(model.settings.isQuiet)
                    .opacity(model.settings.isQuiet ? 0.4 : 1)
            }
        }
    }
}

// MARK: tap tempo

private struct TapTempoCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let tap = model.tapTempo
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Taper le tempo").font(.headline)
                Spacer()
                Text("apprend la vitesse").font(.caption).foregroundStyle(.tertiary)
            }
            HStack(alignment: .center, spacing: 14) {
                // The pad takes the room the card gives it, as large as its height allows (3 by 2).
                TrackpadPad(tap: tap) { model.tap() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    RegularityRow(tap: tap)
                    VStack(spacing: 6) {
                        Button { model.applyTap() } label: { Text("Appliquer").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                            .disabled(!tap.canApply)
                            .help("Appliquer le tempo")
                        Button { model.resetTap() } label: { Text("Recommencer").frame(maxWidth: .infinity) }
                    }
                    .controlSize(.small)
                }
                .frame(width: 108)
            }
        }
        .padding(16)
        // Wider than this the pad could not grow (its height is the limit): the other two cards take the room.
        .frame(maxWidth: 340, maxHeight: .infinity, alignment: .topLeading)
        .blockBackground()
    }
}

/// A trackpad to tap on: proportions of a laptop one (3 by 2), softly rounded, with the tempo learned so far on it.
private struct TrackpadPad: View {
    let tap: TapTempo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(verbatim: tap.bpm.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—")
                    .font(.system(size: 30, weight: .ultraLight)).monospacedDigit()
                Text(tap.count == 0 ? "Tapez ici, ou touche T" : "\(tap.count) taps")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .frame(minWidth: 90, minHeight: 60)
        }
        .buttonStyle(TrackpadStyle())
        .help("Taper en rythme : trackpad ou touche T")
    }
}

/// The surface of the trackpad: a faint gradient and a thin edge, a little lighter under the finger.
private struct TrackpadStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        configuration.label
            .background {
                shape
                    .fill(LinearGradient(colors: [Color.primary.opacity(configuration.isPressed ? 0.13 : 0.08),
                                                  Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(.quaternary, lineWidth: 1))
                    .overlay(shape.inset(by: 1).strokeBorder(.white.opacity(0.06), lineWidth: 1))
            }
            .contentShape(shape)
    }
}

/// How even the taps are: a percentage and a bar (an ellipsis until there are four taps).
private struct RegularityRow: View {
    let tap: TapTempo

    var body: some View {
        let value = tap.isReliable ? tap.regularity : nil
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Régularité").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: tap.count < 2 ? "—" : value.map { "\(Int(($0 * 100).rounded())) %" } ?? "…")
                    .font(.caption).monospacedDigit()
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.accentColor).frame(width: geometry.size.width * (value ?? 0))
                }
            }
            .frame(height: 5)
        }
        .animation(.easeOut(duration: 0.15), value: value)
    }
}

// MARK: speed trainer and start

private struct TrainerCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Entraînement de vitesse").font(.headline)
                Spacer()
                Toggle("Entraînement de vitesse", isOn: $model.settings.trainer.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            Group {
                StepperRow(title: "Jusqu'à", detail: nil, unit: "BPM", value: $model.settings.trainer.target, range: 40...260, step: 5)
                StepperRow(title: "Augmenter de", detail: nil, unit: "BPM", value: $model.settings.trainer.step, range: 1...20, step: 1)
                StepperRow(title: "Toutes les", detail: nil, unit: "mesures", value: Binding(get: { Double(model.settings.trainer.everyBars) }, set: { model.settings.trainer.everyBars = Int($0) }), range: 1...64, step: 1)
            }
            .disabled(!model.settings.trainer.isEnabled)
            .opacity(model.settings.trainer.isEnabled ? 1 : 0.5)
            Text(verbatim: summary).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .blockBackground()
    }

    private var summary: String {
        let s = model.settings
        guard s.trainer.isEnabled else { return String(localized: "Le tempo reste le même.") }
        guard let seconds = s.trainer.duration(from: s.tempo, beats: s.beats, denominator: s.denominator) else {
            return String(localized: "Le tempo de départ est déjà au niveau visé.")
        }
        let minutes = Int((seconds / 60).rounded(.up))
        return String(localized: "De \(Int(s.tempo)) à \(Int(s.trainer.target)) BPM, +\(Int(s.trainer.step)) toutes les \(s.trainer.everyBars) mesures : environ \(minutes) min.")
    }
}

private struct StepperRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    let unit: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let detail { Text(detail).font(.caption).foregroundStyle(.tertiary) }
            }
            Spacer()
            Text(verbatim: "\(Int(value))").monospacedDigit().frame(minWidth: 34, alignment: .trailing)
            Stepper("", value: $value, in: range, step: step).labelsHidden()
            Text(unit).font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
        }
    }
}

private struct StartCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 10) {
            Text("Départ").font(.headline)
            HStack {
                Text("Décompte")
                Spacer()
                Picker("Décompte", selection: $model.settings.countIn) {
                    ForEach(CountIn.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .frame(width: 130)
            }
            HStack {
                Text("Décompte audible")
                Spacer()
                Toggle("Décompte audible", isOn: $model.settings.isCountInAudible)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .disabled(model.settings.countIn == .none || model.settings.isQuiet)
            .opacity(model.settings.countIn == .none || model.settings.isQuiet ? 0.5 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .blockBackground()
    }
}

extension CountIn {
    var label: LocalizedStringKey {
        switch self {
        case .none: return "Aucun"
        case .twoBeats: return "2 temps"
        case .oneBar: return "1 mesure"
        case .twoBars: return "2 mesures"
        case .fourBars: return "4 mesures"
        }
    }
}

extension View {
    /// Soft fade of the scrolled content under the toolbar and the footer (macOS 26); nothing on macOS 15.
    @ViewBuilder func scrollEdgeEffectStyleIfAvailable() -> some View {
        if #available(macOS 26, *) { self.scrollEdgeEffectStyle(.soft, for: .all) } else { self }
    }
}
