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
                HStack(alignment: .top, spacing: 14) {
                    TapTempoCard()
                    VStack(spacing: 14) {
                        TrainerCard()
                        StartCard()
                    }
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
                    .font(.system(size: 120, weight: .ultraLight))
                    .monospacedDigit()
                    .frame(minWidth: 260)
                    .contentTransition(.numericText())
                    .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                        // Drag up or down on the number: three points for a unit.
                        model.settings.tempo = AppModel.clamped(dragStart(model.settings.tempo) - value.translation.height / 3)
                    }.onEnded { _ in dragOrigin = nil })
                    .help("Glisser vers le haut ou le bas pour changer le tempo")
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
            Text("Glissez sur le chiffre, ou touchez ↑ ↓ ← → au clavier. T pour taper le tempo.")
                .font(.caption).foregroundStyle(.tertiary)

            BeatLamps(lit: lit)
                .padding(.top, 14)

            StaffView(layout: StaffLayout(beats: model.settings.beats, denominator: model.settings.denominator, pattern: model.settings.pattern),
                      lit: lit)
                .padding(.top, 4)

            HStack {
                MeterControls().frame(maxWidth: .infinity, alignment: .leading)
                GoButton(diameter: 84)
                VolumeControls().frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.top, 10)
        }
        .padding(.vertical, 18).padding(.horizontal, 22)
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
        .frame(minHeight: 86)
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
            Text("Mesure").font(.callout).foregroundStyle(.secondary)
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
                Slider(value: $model.settings.masterVolume, in: 0...1).frame(width: 110)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Taper le tempo").font(.headline)
                Spacer()
                Text("apprend la vitesse").font(.caption).foregroundStyle(.tertiary)
            }
            Button { model.tap() } label: {
                VStack(spacing: 6) {
                    Text(verbatim: tap.bpm.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—").font(.system(size: 52, weight: .ultraLight)).monospacedDigit()
                    Text(tap.count == 0 ? "Tapez en rythme : trackpad ou touche T" : "\(tap.count) taps")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 130)
                .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            RegularityRow(tap: tap)
            HStack {
                Button("Appliquer le tempo") { model.applyTap() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!tap.canApply)
                Button("Recommencer") { model.resetTap() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blockBackground()
    }

}

/// How even the taps are: a bar and a percentage (an ellipsis until there are four taps).
private struct RegularityRow: View {
    let tap: TapTempo

    var body: some View {
        let value = tap.isReliable ? tap.regularity : nil
        HStack(spacing: 8) {
            Text("Régularité").font(.caption).foregroundStyle(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.accentColor).frame(width: geometry.size.width * (value ?? 0))
                }
            }
            .frame(height: 5)
            Text(verbatim: tap.count < 2 ? "—" : value.map { "\(Int(($0 * 100).rounded())) %" } ?? "…")
                .font(.caption).monospacedDigit().frame(width: 42, alignment: .trailing)
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
            Toggle(isOn: $model.settings.trainer.isEnabled) { Text("Entraînement de vitesse").font(.headline) }
                .toggleStyle(.switch)
            Group {
                StepperRow(title: "Jusqu'à", detail: "Tempo à atteindre, puis constant.", unit: "BPM", value: $model.settings.trainer.target, range: 40...260, step: 5)
                StepperRow(title: "Augmenter de", detail: nil, unit: "BPM", value: $model.settings.trainer.step, range: 1...20, step: 1)
                StepperRow(title: "Toutes les", detail: nil, unit: "mesures", value: Binding(get: { Double(model.settings.trainer.everyBars) }, set: { model.settings.trainer.everyBars = Int($0) }), range: 1...64, step: 1)
            }
            .disabled(!model.settings.trainer.isEnabled)
            .opacity(model.settings.trainer.isEnabled ? 1 : 0.5)
            Text(verbatim: summary).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                VStack(alignment: .leading, spacing: 1) {
                    Text("Décompte")
                    Text("Quelques temps comptés avant le départ.").font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
                Picker("Décompte", selection: $model.settings.countIn) {
                    ForEach(CountIn.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .frame(width: 130)
            }
            Toggle("Décompte audible", isOn: $model.settings.isCountInAudible)
                .toggleStyle(.switch)
                .disabled(model.settings.countIn == .none || model.settings.isQuiet)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
