// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import MatrixKit
import KlickKit
import AppearanceKit

/// The sounds: one of the four of klick, or two files; each can be heard; then the volumes and the pitch.
struct SoundsPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sons").font(.title2).fontWeight(.semibold)
                    Text("Un son pour l'accent et un pour les autres temps. Cliquez sur Écouter pour les entendre.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                Label("L'écoute passe par CoreAudio, sur la sortie du système.", systemImage: "speaker.wave.2.fill")
                    .font(.callout)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.35), lineWidth: 0.5))

                VStack(spacing: 0) {
                    ForEach(ClickSound.BuiltIn.allCases, id: \.self) { sound in
                        BuiltInRow(sound: sound)
                        Divider()
                    }
                    FilesRow()
                }
                .padding(.horizontal, 14)
                .blockBackground()

                Text("Réglages du son").font(.headline).padding(.top, 6)
                VStack(spacing: 0) {
                    SettingRow(title: "Volume de l'accent") {
                        Slider(value: $model.settings.accentVolume, in: 0...1).accentTint().frame(width: 160)
                        Text(verbatim: model.settings.accentVolume.formatted(.number.precision(.fractionLength(2))))
                            .font(.system(.callout, design: .monospaced)).frame(width: 40, alignment: .trailing)
                    }
                    Divider()
                    SettingRow(title: "Volume des autres temps") {
                        Slider(value: $model.settings.normalVolume, in: 0...1).accentTint().frame(width: 160)
                        Text(verbatim: model.settings.normalVolume.formatted(.number.precision(.fractionLength(2))))
                            .font(.system(.callout, design: .monospaced)).frame(width: 40, alignment: .trailing)
                    }
                    Divider()
                    SettingRow(title: "Hauteur", detail: pitchDetail) {
                        Slider(value: $model.settings.pitch, in: -12...12, step: 1).accentTint().frame(width: 160)
                        Text(pitchText).font(.system(.callout, design: .monospaced)).frame(width: 90, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 14)
                .blockBackground()

                Text("La hauteur utilise Rubber Band : le son est transposé sans changer sa durée.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .scrollEdgeEffectStyleIfAvailable()
    }

    private var pitchText: String {
        let n = Int(model.settings.pitch)
        return (n > 0 ? "+" : "") + (abs(n) > 1 ? String(localized: "\(n) demi-tons") : String(localized: "\(n) demi-ton"))
    }

    private var pitchDetail: String {
        let factor = model.settings.pitchFactor.formatted(.number.precision(.fractionLength(2)))
        return model.settings.pitch == 0 ? String(localized: "Aucune transposition.") : String(localized: "Fréquence multipliée par \(factor).")
    }
}

/// A row of a group: title, optional detail, and the controls at the right.
struct SettingRow<Controls: View>: View {
    let title: LocalizedStringKey
    var detail: String?
    @ViewBuilder let controls: Controls

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let detail { Text(verbatim: detail).font(.caption).foregroundStyle(.tertiary) }
            }
            Spacer(minLength: 12)
            controls
        }
        .padding(.vertical, 9)
    }
}

// MARK: rows

private func soundName(_ sound: ClickSound.BuiltIn) -> LocalizedStringKey {
    switch sound {
    case .square: return "Carré"
    case .sine: return "Sinus"
    case .noise: return "Bruit"
    case .click: return "Cloche / clic"
    }
}

private func soundDetail(_ sound: ClickSound.BuiltIn) -> LocalizedStringKey {
    switch sound {
    case .square: return "Onde carrée, sec et net"
    case .sine: return "Onde sinusoïdale, doux"
    case .noise: return "Bruit blanc filtré, discret"
    case .click: return "Clic acoustique enregistré"
    }
}

private struct BuiltInRow: View {
    @Environment(\.appAccentColor) private var accent
    let sound: ClickSound.BuiltIn
    @Environment(AppModel.self) private var model

    var body: some View {
        let selected = model.settings.sound == .builtIn(sound)
        HStack(spacing: 12) {
            RadioMark(selected: selected)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 12) {
                    Text(soundName(sound)).fontWeight(.medium)
                    Waveform(url: KlickResources.soundsDirectory.appendingPathComponent("\(sound.fileName)_emphasis.wav"))
                        .frame(width: 120, height: 26)
                        .foregroundStyle(selected ? accent : .secondary)
                }
                Text(soundDetail(sound)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            ListenButtons(sound: .builtIn(sound))
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { model.settings.sound = .builtIn(sound) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Two files of the user's own: one for the accent, one for the other beats (one file for both is fine).
private struct FilesRow: View {
    @Environment(AppModel.self) private var model

    private var files: (accent: String, normal: String)? {
        if case .files(let accent, let normal) = model.settings.sound { return (accent, normal) }
        return nil
    }

    var body: some View {
        let selected = files != nil
        HStack(spacing: 12) {
            RadioMark(selected: selected)
            VStack(alignment: .leading, spacing: 3) {
                Text("Fichiers personnels").fontWeight(.medium)
                Text(verbatim: detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button("Accent…") { choose(accent: true) }.controlSize(.small)
            Button("Autres temps…") { choose(accent: false) }.controlSize(.small)
            if let files { ListenButtons(sound: .files(accent: files.accent, normal: files.normal)) }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture { if files == nil { choose(accent: true) } }
    }

    private var detail: String {
        guard let files else { return String(localized: "Choisissez un son d'accent et un son pour les autres temps.") }
        let accent = URL(fileURLWithPath: files.accent).lastPathComponent
        let normal = URL(fileURLWithPath: files.normal).lastPathComponent
        return accent == normal ? accent : "\(accent) · \(normal)"
    }

    private func choose(accent: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.message = accent ? String(localized: "Son de l'accent") : String(localized: "Son des autres temps")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let current = files
        let chosen = url.path
        // The other one keeps its file, or follows the first choice.
        let other = accent ? (current?.normal ?? chosen) : (current?.accent ?? chosen)
        model.settings.sound = accent ? .files(accent: chosen, normal: other) : .files(accent: other, normal: chosen)
    }
}

/// The three ways to hear a sound: an accent, a normal beat, a bar. Off while the metronome plays.
private struct ListenButtons: View {
    let sound: ClickSound
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            button("Accent", .accent)
            button("Normal", .normal)
            button("Une mesure", .bar)
        }
        .controlSize(.small)
        .disabled(model.isPlaying)
        .help(LocalizedStringKey(model.isPlaying ? "Le métronome joue : arrêtez-le pour écouter les sons." : ""))
    }

    private func button(_ title: LocalizedStringKey, _ what: AppModel.Preview) -> some View {
        Button { model.preview(what, sound: sound) } label: { Label(title, systemImage: "play.fill").labelStyle(.titleAndIcon) }
    }
}

private struct RadioMark: View {
    @Environment(\.appAccentColor) private var accent
    let selected: Bool

    var body: some View {
        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
            .font(.system(size: 16))
            .foregroundStyle(selected ? accent : .secondary)
            .frame(width: 20)
    }
}

// MARK: waveform

/// The shape of a sound: thirty bars, as high as the loudest sample in each slice of its first moments.
private struct Waveform: View {
    let url: URL
    @State private var peaks: [Float] = []

    var body: some View {
        Canvas { context, size in
            guard !peaks.isEmpty else { return }
            let step = size.width / CGFloat(peaks.count)
            var path = Path()
            for (i, peak) in peaks.enumerated() {
                let x = step * (CGFloat(i) + 0.5)
                let half = max(1, CGFloat(peak) * size.height / 2)
                path.move(to: CGPoint(x: x, y: size.height / 2 - half))
                path.addLine(to: CGPoint(x: x, y: size.height / 2 + half))
            }
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .task(id: url) { peaks = await Self.peaks(of: url, bars: 30) }
        .accessibilityHidden(true)
    }

    private static func peaks(of url: URL, bars: Int) async -> [Float] {
        await Task.detached(priority: .utility) {
            guard let file = try? AVAudioFile(forReading: url) else { return [] }
            // The first quarter of a second is the click.
            let frames = AVAudioFrameCount(min(file.length, Int64(file.processingFormat.sampleRate * 0.25)))
            guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames),
                  (try? file.read(into: buffer, frameCount: frames)) != nil, let data = buffer.floatChannelData?[0] else { return [] }
            let count = Int(buffer.frameLength)
            let slice = max(1, count / bars)
            let values = (0..<bars).map { bar -> Float in
                let start = bar * slice
                guard start < count else { return 0 }
                var peak: Float = 0
                for i in start..<min(count, start + slice) { peak = max(peak, abs(data[i])) }
                return peak
            }
            let loudest = max(values.max() ?? 0, 0.0001)
            return values.map { $0 / loudest }
        }.value
    }
}
