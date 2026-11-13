// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import MatrixKit
import KlickKit
import AppearanceKit

/// Writes the metronome or the tempo map to a file: audio (WAV, rendered without a sound device) or MIDI (the tempos and the meters,
/// and the clicks on a percussion track).
struct ExportPage: View {
    @Environment(AppModel.self) private var model
    @State private var run = ExportRun()

    enum Source: String { case metronome, map }
    enum Format: String { case wav, midi }

    @AppStorage("export.source") private var sourceRaw = Source.metronome.rawValue
    @AppStorage("export.format") private var formatRaw = Format.wav.rawValue
    @AppStorage("export.bars") private var bars = 8
    @AppStorage("export.rate") private var rate = 48000
    @AppStorage("export.depth") private var depth = 24
    @AppStorage("export.fromCursor") private var fromCursor = false
    @AppStorage("export.countIn") private var includeCountIn = false
    @AppStorage("export.midiClicks") private var midiClicks = true

    private var source: Source { Source(rawValue: sourceRaw) ?? .metronome }
    private var format: Format { Format(rawValue: formatRaw) ?? .wav }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exporter").font(.title2).fontWeight(.semibold)
                    Text("Écrit le métronome ou la carte dans un fichier, sans passer par la sortie du Mac.").foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                VStack(spacing: 0) {
                    ExportRow(title: "Source") {
                        Picker("Source", selection: $sourceRaw) {
                            Text("Métronome").tag(Source.metronome.rawValue)
                            Text("Carte de tempo").tag(Source.map.rawValue)
                        }
                        .pickerStyle(.segmented).accentTint().labelsHidden().fixedSize()
                    }
                    Divider()
                    if source == .metronome {
                        ExportRow(title: "Mesures", detail: Text(verbatim: "\(model.settings.beats)/\(model.settings.denominator), \(Int(model.settings.tempo.rounded())) BPM")) {
                            Stepper(value: $bars, in: 1...999) { Text(verbatim: "\(bars)").monospacedDigit().frame(minWidth: 36, alignment: .trailing) }
                        }
                    } else {
                        ExportRow(title: "Départ", detail: Text("Le curseur de la frise est à la mesure \(model.mapStartBar + 1).")) {
                            Picker("Départ", selection: $fromCursor) {
                                Text("Du début").tag(false)
                                Text("Du curseur").tag(true)
                            }
                            .pickerStyle(.segmented).accentTint().labelsHidden().fixedSize()
                        }
                    }
                    Divider()
                    ExportRow(title: "Format") {
                        Picker("Format", selection: $formatRaw) {
                            Text("Audio (WAV)").tag(Format.wav.rawValue)
                            Text("MIDI").tag(Format.midi.rawValue)
                        }
                        .pickerStyle(.segmented).accentTint().labelsHidden().fixedSize()
                    }
                    if format == .wav {
                        Divider()
                        ExportRow(title: "Fréquence") {
                            Picker("Fréquence", selection: $rate) {
                                Text(verbatim: "44,1 kHz").tag(44100)
                                Text(verbatim: "48 kHz").tag(48000)
                                Text(verbatim: "96 kHz").tag(96000)
                            }
                            .labelsHidden().fixedSize()
                        }
                        Divider()
                        ExportRow(title: "Profondeur") {
                            Picker("Profondeur", selection: $depth) {
                                Text(verbatim: "16 bits").tag(16)
                                Text(verbatim: "24 bits").tag(24)
                                Text("32 bits flottants").tag(32)
                            }
                            .labelsHidden().fixedSize()
                        }
                        Divider()
                        ExportRow(title: "Décompte", detail: Text("Celui de la page Métronome ou de la carte, entendu au début du fichier.")) {
                            Toggle("Décompte", isOn: $includeCountIn).labelsHidden().toggleStyle(.switch).accentTint()
                                .disabled(model.settings.countIn == .none)
                        }
                    } else {
                        Divider()
                        ExportRow(title: "Clics", detail: Text("Une piste de percussions avec les accents ; sans elle, seulement les tempos et les mesures.")) {
                            Toggle("Clics", isOn: $midiClicks).labelsHidden().toggleStyle(.switch).accentTint()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .blockBackground()

                Text(verbatim: summary).font(.caption).foregroundStyle(.tertiary)

                HStack(spacing: 12) {
                    Button(LocalizedStringKey(run.isRunning ? "Annuler" : "Exporter…")) { run.isRunning ? run.cancel() : start() }
                        .buttonStyle(.borderedProminent).accentTint()
                        .disabled(!run.isRunning && !canExport)
                    if run.isRunning {
                        ProgressView(value: run.progress).accentTint().frame(width: 220)
                        Text("Écriture… \(Int((run.progress * 100).rounded())) %").font(.callout).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)

                // How it ended, in a block that stays until the next export: written (with the file), cancelled, or failed.
                if !run.isRunning, let result = run.result {
                    HStack(spacing: 12) {
                        Image(systemName: result.isError ? "exclamationmark.triangle.fill" : result.url == nil ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(result.isError ? Color.alert : result.url == nil ? Color.secondary : Color.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: result.title).fontWeight(.semibold)
                            if let detail = result.detail { Text(verbatim: detail).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer(minLength: 12)
                        if let url = result.url {
                            Button("Afficher dans le Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.controlSize(.small)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .blockBackground()
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .scrollEdgeEffectStyleIfAvailable()
    }

    // MARK: what is written

    private var sections: [MapSection] {
        switch source {
        case .map:
            return model.document.sections
        case .metronome:
            let s = model.settings
            return [MapSection(label: "", bars: bars, beats: s.beats, denominator: s.denominator, tempo: s.tempo, pattern: s.pattern)]
        }
    }

    private var startBar: Int { source == .map && fromCursor ? model.mapStartBar : 0 }

    private var canExport: Bool { !sections.isEmpty }

    /// "Durée : 1 min 52 s, 78 mesures. Taille estimée : 20 Mo."
    private var summary: String {
        let played = MapSection.played(sections, fromBar: startBar).sections
        let seconds = played.reduce(0) { $0 + $1.seconds }
        let barCount = played.reduce(0) { $0 + $1.bars }
        let minutes = Int(seconds) / 60, rest = Int(seconds.rounded()) % 60
        let duration = minutes > 0 ? String(localized: "\(minutes) min \(rest) s") : String(localized: "\(rest) s")
        let bytes = format == .wav ? seconds * Double(rate) * Double(depth / 8) : Double(barCount * 24 + 200)
        let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        return String(localized: "Durée : \(duration), \(Plural.bars(barCount)). Taille estimée : \(size).")
    }

    private var suggestedName: String {
        source == .map ? MapFiles.displayName(of: model.document) : String(localized: "Métronome")
    }

    // MARK: writing

    private func start() {
        let fileExtension = format == .wav ? "wav" : "mid"
        let folder = AppModel.defaultMapsDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .wav ? .wav : UTType(filenameExtension: "mid") ?? .midi]
        panel.directoryURL = folder
        panel.nameFieldStringValue = suggestedName + "." + fileExtension
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if format == .midi {
            let data = MidiExport.data(sections: sections, fromBar: startBar, withClicks: midiClicks)
            do {
                try data.write(to: url)
                run.result = ExportRun.written(url)
            } catch {
                run.result = ExportRun.Result(title: String(localized: "L'export a échoué"), detail: error.localizedDescription, url: nil, isError: true)
            }
            return
        }

        var options = AudioExportOptions()
        options.rate = rate
        options.bitDepth = AudioExportOptions.BitDepth(rawValue: depth) ?? .int24
        options.includeCountIn = includeCountIn
        let job: ExportSource = source == .map ? .map(fromBar: startBar) : .metronome(bars: bars)
        run.start(source: job, settings: model.settings, map: model.document.sections, options: options,
                  soundsDirectory: KlickResources.soundsDirectory, url: url)
    }
}

/// A row of the group: title, optional detail, controls at the right.
private struct ExportRow<Controls: View>: View {
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

/// The export that is running: its progress, how to stop it, and how it ended.
@Observable
final class ExportRun {
    struct Result { var title: String; var detail: String?; var url: URL?; var isError: Bool }

    /// The outcome of a file that has been written: its name and its size.
    static func written(_ url: URL) -> Result {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64).flatMap { $0 } ?? 0
        return Result(title: String(localized: "Export terminé"),
                      detail: "\(url.lastPathComponent) · " + ByteCountFormatter.string(fromByteCount: size, countStyle: .file), url: url, isError: false)
    }

    private(set) var isRunning = false
    private(set) var progress = 0.0
    var result: Result?
    private let cancelFlag = CancelFlag()

    final class CancelFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
        func set(_ v: Bool) { lock.lock(); value = v; lock.unlock() }
    }

    func cancel() { cancelFlag.set(true) }

    func start(source: ExportSource, settings: ClickSettings, map: [MapSection], options: AudioExportOptions, soundsDirectory: URL, url: URL) {
        isRunning = true; progress = 0; result = nil
        cancelFlag.set(false)
        let flag = cancelFlag
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try AudioExporter.export(source: source, settings: settings, map: map, options: options, soundsDirectory: soundsDirectory, to: url,
                                         progress: { p in Task { @MainActor in self?.progress = p } },
                                         isCancelled: { flag.isSet })
                await self?.finish(Self.written(url))
            } catch is CancellationError {
                await self?.finish(Result(title: String(localized: "Export annulé"), detail: String(localized: "Aucun fichier n'a été écrit."), url: nil, isError: false))
            } catch {
                await self?.finish(Result(title: String(localized: "L'export a échoué"), detail: error.localizedDescription, url: nil, isError: true))
            }
        }
    }

    @MainActor private func finish(_ outcome: Result) {
        isRunning = false
        result = outcome
    }
}
