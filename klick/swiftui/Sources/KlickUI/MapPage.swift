// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import MatrixKit
import KlickKit
import AppearanceKit

/// The tempo map: the file it comes from, the course of the tempo, a bar of each section on a staff, and the table of the sections.
struct MapPage: View {
    @Environment(\.appAccentColor) private var accent
    @Environment(AppModel.self) private var model
    @State private var editing: SectionEdit?
    @State private var asksToClear = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                HStack(spacing: 10) {
                    Button("Ouvrir une carte…") { open() }
                    Menu("Exemples") {
                        ForEach(ExampleMap.all) { example in
                            Button(example.title) { openExample(example) }
                                .help(example.detail)
                        }
                    }
                    .menuIndicator(.visible)
                    .fixedSize()
                    Button("Enregistrer la carte") { save() }
                        .disabled(model.document.url != nil && !model.document.isModified)
                    // A map that has changes is not thrown away without asking.
                    Button("Vider") { if model.document.isModified { asksToClear = true } else { model.newMap() } }
                        .help("Repartir d'une carte à une seule section")
                    Spacer()
                    Text("Décompte").font(.callout).foregroundStyle(.secondary)
                    Picker("Décompte", selection: $model.settings.countIn) {
                        ForEach(CountIn.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Button("Ajouter une section") { editing = SectionEdit.new(after: model.selectedSection, in: model.document.sections) }
                }
                MapPanel(title: "Déroulement", subtitle: Text(verbatim: totalText + " · " + String(localized: "glissez le curseur pour choisir le départ"))) {
                    MapTimeline().frame(height: 150)
                }
                MapPanel(title: "Notation", subtitle: Text("une mesure type par section")) {
                    MapNotation()
                }
                MapPanel(title: "Sections", subtitle: Text("cliquez une ligne ; X accent, x normal, point silence")) {
                    SectionTable { index in editing = SectionEdit(index: index, draft: model.document.sections[index]) }
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .scrollEdgeEffectStyleIfAvailable()
        .sheet(item: $editing) { target in SectionEditor(target: target) }
        .confirmationDialog("Vider la carte ?", isPresented: $asksToClear, titleVisibility: .visible) {
            Button("Vider", role: .destructive) { model.newMap() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les modifications qui ne sont pas enregistrées seront perdues.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Carte de tempo").font(.title2).fontWeight(.semibold)
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                Text(verbatim: MapFiles.displayName(of: model.document))
                if model.document.isModified { Circle().fill(accent).frame(width: 6, height: 6).help("Modifiée depuis le dernier enregistrement") }
            }
            .font(.callout).foregroundStyle(.secondary)
            Text("Une suite de sections jouées l'une après l'autre : mesures, tempo ou rampe, accents. Comme une partition de métronome.")
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            HStack(spacing: 10) {
                TransportBadge()
                ExternalMasterNote(mode: .map)
            }
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private var totalText: String {
        "\(Plural.sections(model.document.sections.count)), \(Plural.bars(model.document.totalBars))"
    }

    private func open() {
        guard let url = MapFiles.chooseFileToOpen() else { return }
        do { try model.openMap(at: url); model.errorMessage = nil } catch { model.errorMessage = error.localizedDescription }
    }

    private func openExample(_ example: ExampleMap) {
        do { try model.openExample(example, in: KlickResources.examplesDirectory); model.errorMessage = nil } catch { model.errorMessage = error.localizedDescription }
    }

    private func save() {
        let target: URL?
        if model.document.url == nil {
            guard let chosen = MapFiles.chooseFileToSave(suggestedName: MapFiles.displayName(of: model.document)) else { return }
            target = chosen
        } else {
            target = nil
        }
        do { try model.saveMap(to: target); model.errorMessage = nil } catch { model.errorMessage = error.localizedDescription }
    }
}

/// The panels and file dialogs of the page.
enum MapFiles {
    static let type = UTType(filenameExtension: "klick") ?? .plainText

    /// The file name without its extension, or "Sans titre" until the map is saved.
    @MainActor static func displayName(of document: TempoMapDocument) -> String {
        document.displayName ?? String(localized: "Sans titre")
    }

    /// The folder the dialogs start in: `~/Documents/Klick` once it exists, else Documents.
    @MainActor private static var startDirectory: URL {
        let folder = AppModel.defaultMapsDirectory
        return FileManager.default.fileExists(atPath: folder.path) ? folder : folder.deletingLastPathComponent()
    }

    @MainActor static func chooseFileToOpen() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [type, .plainText]
        panel.allowsOtherFileTypes = true
        panel.directoryURL = startDirectory
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// The default folder is created the first time a map is saved.
    @MainActor static func chooseFileToSave(suggestedName: String) -> URL? {
        let folder = AppModel.defaultMapsDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.allowsOtherFileTypes = false
        panel.directoryURL = folder
        panel.nameFieldStringValue = suggestedName + ".klick"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// A block with a title and a small subtitle, as on the other pages.
private struct MapPanel<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: Text
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.headline)
                subtitle.font(.caption).foregroundStyle(.tertiary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blockBackground()
    }
}

// MARK: timeline

/// The sections side by side, as wide as their bars, with the tempo drawn across them (steps, ramps, one tempo per beat).
private struct MapTimeline: View {
    @Environment(\.appAccentColor) private var accent
    @Environment(AppModel.self) private var model
    /// The bar under the pointer while the cursor is dragged; the map moves only when it is let go.
    @State private var dragBar: Int?

    /// Where the cursor is, in bars from the start: where the map starts, or, while it plays, where it is.
    private var cursor: Double {
        if let dragBar { return Double(dragBar) }
        if model.isPlaying && model.player.mode == .map && model.player.phase == .playing { return model.player.mapPosition }
        return Double(model.mapStartBar)
    }

    var body: some View {
        let sections = model.document.sections
        let total = max(1, sections.reduce(0) { $0 + $1.bars })
        let range = Self.tempoRange(of: sections)
        let cursor = self.cursor
        Canvas { context, size in
            let top: CGFloat = 20, bottom: CGFloat = 8
            let plotHeight = size.height - top - bottom
            func y(_ tempo: Double) -> CGFloat {
                top + plotHeight * (1 - CGFloat((tempo - range.lowerBound) / max(range.upperBound - range.lowerBound, 1)))
            }
            var x: CGFloat = 0
            let gap: CGFloat = 3
            var previous: CGPoint?
            var cursorX: CGFloat?
            var barsBefore = 0
            for (index, section) in sections.enumerated() {
                let width = max(6, (size.width - gap * CGFloat(sections.count - 1)) * CGFloat(section.bars) / CGFloat(total))
                let rect = CGRect(x: x, y: 0, width: width, height: size.height)
                let selected = index == model.activeSection
                let shape = Path(roundedRect: rect, cornerRadius: 6)
                context.fill(shape, with: .color(selected ? accent.opacity(0.14) : Color.primary.opacity(0.06)))
                context.stroke(shape, with: .color(selected ? accent.opacity(0.7) : Color.primary.opacity(0.12)),
                               style: StrokeStyle(lineWidth: 1, dash: section.muted ? [4, 3] : []))
                let label = section.label.isEmpty ? String(localized: "suite") : section.label
                context.draw(Text(verbatim: label).font(.caption2).foregroundStyle(.secondary),
                             at: CGPoint(x: x + 6, y: 10), anchor: .leading)

                // the tempo across the section
                let points = Self.curve(of: section).enumerated().map { i, tempo -> CGPoint in
                    let count = max(Self.curve(of: section).count - 1, 1)
                    return CGPoint(x: rect.minX + 4 + (width - 8) * CGFloat(i) / CGFloat(count), y: y(tempo))
                }
                var path = Path()
                if let previous { path.move(to: previous); path.addLine(to: CGPoint(x: points[0].x, y: previous.y)); path.addLine(to: points[0]) } else { path.move(to: points[0]) }
                for point in points.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(accent.opacity(section.muted ? 0.4 : 1)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                context.draw(Text(verbatim: MapTimelineText.tempo(section)).font(.caption2).foregroundStyle(.primary),
                             at: CGPoint(x: x + 6, y: size.height - 6), anchor: .bottomLeading)
                previous = points.last
                if cursorX == nil, cursor < Double(barsBefore + section.bars) || index == sections.count - 1 {
                    let inside = min(max((cursor - Double(barsBefore)) / Double(max(section.bars, 1)), 0), 1)
                    cursorX = rect.minX + width * CGFloat(inside)
                }
                barsBefore += section.bars
                x += width + gap
            }

            // the cursor: a line and a small handle at the top
            if let cursorX {
                var line = Path()
                line.move(to: CGPoint(x: cursorX, y: 4)); line.addLine(to: CGPoint(x: cursorX, y: size.height))
                context.stroke(line, with: .foreground, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                var handle = Path()
                handle.move(to: CGPoint(x: cursorX - 5, y: 0)); handle.addLine(to: CGPoint(x: cursorX + 5, y: 0))
                handle.addLine(to: CGPoint(x: cursorX, y: 8)); handle.closeSubpath()
                context.fill(handle, with: .foreground)
            }
        }
        .contentShape(Rectangle())
        // A click or a drag puts the cursor on a bar; the map starts from there (a map that plays starts again from there).
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { drag in dragBar = bar(at: drag.location.x, sections: sections, total: total) }
            .onEnded { drag in
                let bar = bar(at: drag.location.x, sections: sections, total: total)
                dragBar = nil
                model.moveMapCursor(toBar: bar)
                select(at: drag.location.x, sections: sections, total: total)
            })
        .background(GeometryReader { geometry in Color.clear.preference(key: WidthKey.self, value: geometry.size.width) })
        .onPreferenceChange(WidthKey.self) { width = $0 }
        .accessibilityHidden(true)
    }

    @State private var width: CGFloat = 0
    private struct WidthKey: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }

    /// The bar under a horizontal position of the timeline.
    private func bar(at x: CGFloat, sections: [MapSection], total: Int) -> Int {
        guard width > 0 else { return 0 }
        let gap: CGFloat = 3
        var left: CGFloat = 0
        var barsBefore = 0
        for section in sections {
            let w = max(6, (width - gap * CGFloat(sections.count - 1)) * CGFloat(section.bars) / CGFloat(total))
            if x <= left + w + gap / 2 {
                let inside = min(max((x - left) / w, 0), 0.999)
                return barsBefore + Int(inside * CGFloat(section.bars))
            }
            left += w + gap
            barsBefore += section.bars
        }
        return max(0, total - 1)
    }

    private func select(at x: CGFloat, sections: [MapSection], total: Int) {
        guard width > 0 else { return }
        let gap: CGFloat = 3
        var left: CGFloat = 0
        for (index, section) in sections.enumerated() {
            let w = max(6, (width - gap * CGFloat(sections.count - 1)) * CGFloat(section.bars) / CGFloat(total))
            if x <= left + w + gap / 2 { model.select(section: index); return }
            left += w + gap
        }
        model.select(section: sections.indices.last)
    }

    /// The tempos a section goes through, for the line: one value for a constant tempo, two for a ramp, one per beat when listed.
    static func curve(of section: MapSection) -> [Double] {
        if let tempi = section.tempi, tempi.count > 1 { return tempi }
        return [section.tempo, section.tempoEnd ?? section.tempo]
    }

    static func tempoRange(of sections: [MapSection]) -> ClosedRange<Double> {
        let all = sections.flatMap { curve(of: $0) }
        let low = all.min() ?? 60, high = all.max() ?? 120
        let margin = max(10, (high - low) * 0.15)
        return (low - margin)...(high + margin)
    }
}

// MARK: notation

/// One bar of each section on a staff.
private struct MapNotation: View {
    @Environment(\.appAccentColor) private var accent
    @Environment(AppModel.self) private var model
    @State private var position = ScrollPosition()
    @State private var metrics = ScrollMetrics()

    /// Where the scroll stands: what is hidden on the left and on the right.
    private struct ScrollMetrics: Equatable {
        var offset: CGFloat = 0, content: CGFloat = 0, container: CGFloat = 0
        var hasLeft: Bool { offset > 1 }
        var hasRight: Bool { offset + container < content - 1 }
    }

    var body: some View {
        let sections = model.document.sections
        ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(sections.indices, id: \.self) { i in
                    let s = sections[i]
                    let shows = i == 0 || sections[i - 1].beats != s.beats || sections[i - 1].denominator != s.denominator
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: caption(s)).font(.caption2).foregroundStyle(.secondary)
                        StaffView(layout: StaffLayout(beats: s.beats, denominator: s.denominator, pattern: s.pattern,
                                                      width: shows ? 250 : 210, showsSignature: shows),
                                  lit: nil, scale: 1)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(i == model.activeSection ? accent.opacity(0.12) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(i == model.activeSection ? accent.opacity(0.45) : .clear, lineWidth: 0.5))
                    .opacity(s.muted ? 0.5 : 1)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { model.select(section: i) }
                    .id(i)
                }
            }
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
            ScrollMetrics(offset: geometry.contentOffset.x, content: geometry.contentSize.width, container: geometry.containerSize.width)
        } action: { _, new in metrics = new }
        // An arrow on each side that has more to show: also the way to scroll with a mouse.
        .overlay(alignment: .leading) { if metrics.hasLeft { EdgeArrow(systemName: "chevron.left") { scroll(by: -1) } } }
        .overlay(alignment: .trailing) { if metrics.hasRight { EdgeArrow(systemName: "chevron.right") { scroll(by: 1) } } }
        .animation(.easeOut(duration: 0.15), value: metrics.hasLeft)
        .animation(.easeOut(duration: 0.15), value: metrics.hasRight)
        // The selected section comes into view, whichever way it was chosen (the timeline, the table, a new section).
        .onChange(of: model.activeSection) { _, selected in
            guard let selected else { return }
            withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(selected, anchor: .center) }
        }
        }
    }

    /// A page to the left or to the right (80 % of what is shown).
    private func scroll(by direction: CGFloat) {
        let target = min(max(0, metrics.offset + direction * metrics.container * 0.8), max(0, metrics.content - metrics.container))
        withAnimation(.easeInOut(duration: 0.25)) { position.scrollTo(x: target) }
    }

    private func caption(_ s: MapSection) -> String {
        let name = s.label.isEmpty ? String(localized: "suite") : s.label
        return "\(name) · × \(s.bars)" + (s.muted ? " · " + String(localized: "silencieux") : "")
    }
}

/// A round button at the edge of a scrolling area, on a soft fade, to say that there is more and to go there.
private struct EdgeArrow: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.quaternary, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .transition(.opacity)
        .accessibilityLabel(LocalizedStringKey(systemName == "chevron.left" ? "Vers la gauche" : "Vers la droite"))
    }
}

// MARK: table

/// The sections as a table; a row is selected by a click and edited by its button or a double click.
private struct SectionTable: View {
    @Environment(\.appAccentColor) private var accent
    @Environment(AppModel.self) private var model
    let edit: (Int) -> Void

    var body: some View {
        let sections = model.document.sections
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(["Étiquette", "Mesures", "Mesure", "Tempo", "Motif", "Volume", "Silencieux", ""], id: \.self) { title in
                    Text(LocalizedStringKey(title)).font(.caption).foregroundStyle(.tertiary).padding(.horizontal, 7)
                }
            }
            .padding(.bottom, 6)
            Divider().gridCellColumns(8)
            ForEach(sections.indices, id: \.self) { i in
                let s = sections[i]
                GridRow {
                    Group {
                    Text(verbatim: s.label.isEmpty ? "—" : s.label).foregroundStyle(s.label.isEmpty ? .tertiary : .primary)
                    Text(verbatim: "\(s.bars)").monospacedDigit()
                    Text(verbatim: "\(s.beats)/\(s.denominator)").monospacedDigit()
                    Text(verbatim: MapTimelineText.tempo(s)).monospacedDigit()
                    Text(verbatim: s.pattern).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                    Text(verbatim: s.volume.formatted(.number.precision(.fractionLength(2)))).monospacedDigit()
                    Toggle("Silencieux", isOn: Binding(get: { s.muted }, set: { value in model.updateSection(at: i) { $0.muted = value } }))
                        .labelsHidden().toggleStyle(.switch).accentTint().controlSize(.small)
                    HStack(spacing: 6) {
                        Button("Éditer") { model.select(section: i); edit(i) }
                        Button("Lire d'ici") { model.select(section: i); model.startMap(from: i) }
                            .help("Jouer la carte à partir de cette section")
                    }
                    .controlSize(.small)
                    }
                    // the cells touch each other so that the tint of the selected row has no gaps
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 7).padding(.vertical, 6)
                    .background(i == model.activeSection ? accent.opacity(0.12) : .clear)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { model.select(section: i); edit(i) }
                .onTapGesture { model.select(section: i) }
                .opacity(s.muted ? 0.55 : 1)
                Divider().gridCellColumns(8)
            }
        }
    }
}

enum MapTimelineText {
    static func tempo(_ s: MapSection) -> String {
        if s.hasTempoPerBeat { return String(localized: "variable") }
        let start = Int(s.tempo.rounded())
        if let end = s.tempoEnd, Int(end.rounded()) != start { return "\(start) → \(Int(end.rounded()))" }
        return "\(start)"
    }
}

// MARK: editor

/// A section being edited (`index` is `nil` for a new one).
struct SectionEdit: Identifiable {
    let id = UUID()
    var index: Int?
    var draft: MapSection

    /// A new section after the selected one: same meter, starting where it ends.
    static func new(after selected: Int?, in sections: [MapSection]) -> SectionEdit {
        let base = selected.flatMap { sections.indices.contains($0) ? sections[$0] : nil }
        let draft = MapSection(label: "", bars: 8, beats: base?.beats ?? 4, denominator: base?.denominator ?? 4,
                               tempo: base?.tempoEnd ?? base?.tempo ?? 120)
        return SectionEdit(index: nil, draft: draft)
    }
}

/// The sheet that edits one section.
private struct SectionEditor: View {
    @Environment(\.appAccentColor) private var accent
    let target: SectionEdit
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MapSection
    @State private var startText: String
    @State private var endText: String

    init(target: SectionEdit) {
        self.target = target
        _draft = State(initialValue: target.draft)
        _startText = State(initialValue: String(Int(target.draft.tempo.rounded())))
        _endText = State(initialValue: String(Int((target.draft.tempoEnd ?? target.draft.tempo).rounded())))
    }

    private static let limits = 20.0...300.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(target.index == nil ? "Nouvelle section" : "Éditer la section")).font(.title3).fontWeight(.semibold)
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                row("Étiquette", detail: "Facultative : sert à repartir de cette section.") {
                    TextField("", text: Binding(get: { draft.label }, set: { draft.label = Self.cleaned($0) }))
                        .textFieldStyle(.roundedBorder).frame(width: 150)
                }
                row("Mesures") {
                    Stepper(value: $draft.bars, in: 1...999) { Text(verbatim: "\(draft.bars)").monospacedDigit().frame(minWidth: 36, alignment: .trailing) }
                }
                row("Mesure") {
                    HStack(spacing: 8) {
                        Picker("Temps par mesure", selection: Binding(get: { draft.beats }, set: { setBeats($0) })) {
                            ForEach(MeterRules.numerators(for: draft.denominator, including: draft.beats), id: \.self) { Text(verbatim: "\($0)").tag($0) }
                        }
                        .labelsHidden().frame(width: 64)
                        Text(verbatim: "/").foregroundStyle(.secondary)
                        Picker("Valeur du temps", selection: Binding(get: { draft.denominator }, set: { setDenominator($0) })) {
                            ForEach(MeterRules.denominators, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented).accentTint().labelsHidden().fixedSize()
                    }
                }
                row("Tempo", detail: LocalizedStringKey(draft.hasTempoPerBeat ? "Un tempo par temps : à modifier dans le fichier." : "Deux valeurs différentes : accélération ou ralentissement progressif.")) {
                    HStack(spacing: 6) {
                        TextField("", text: $startText).textFieldStyle(.roundedBorder).frame(width: 56).multilineTextAlignment(.trailing)
                            .onChange(of: startText) { applyTempo() }
                        Text(verbatim: "→").foregroundStyle(.secondary)
                        TextField("", text: $endText).textFieldStyle(.roundedBorder).frame(width: 56).multilineTextAlignment(.trailing)
                            .onChange(of: endText) { applyTempo() }
                        Text(verbatim: "BPM").font(.caption).foregroundStyle(.secondary)
                    }
                    .disabled(draft.hasTempoPerBeat)
                }
                row("Motif", detail: "Un clic sur un temps : accent, normal, silence.") {
                    HStack(spacing: 4) {
                        ForEach(Array(draft.pattern.enumerated()), id: \.offset) { i, c in
                            Button { cyclePattern(i) } label: {
                                Text(verbatim: c == "." ? "·" : String(c)).frame(width: 18)
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                            .tint(c == "X" ? accent : nil)
                        }
                    }
                }
                row("Volume") {
                    Slider(value: $draft.volume, in: 0...1).accentTint().frame(width: 140)
                }
                row("Silencieux", detail: "Écrit comme un volume de 0 dans le fichier.", last: true) {
                    Toggle("Silencieux", isOn: $draft.muted).labelsHidden().toggleStyle(.switch).accentTint()
                }
            }
            .padding(.horizontal, 14)
            .blockBackground()

            HStack {
                if let index = target.index, model.document.sections.count > 1 {
                    Button("Supprimer", role: .destructive) { model.removeSection(at: index); dismiss() }
                }
                Spacer()
                Button("Annuler") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("OK") { commit() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).accentTint()
            }
            .padding(.top, 16)
        }
        .padding(20)
        .frame(width: 520)
    }

    private var subtitle: String {
        guard let index = target.index else { return String(localized: "Elle sera ajoutée après la section sélectionnée.") }
        let total = model.document.sections.count
        let name = target.draft.label.isEmpty ? "" : " : \(target.draft.label)"
        return String(localized: "Section \(index + 1) sur \(total)") + name
    }

    private func row<Control: View>(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, last: Bool = false,
                                    @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    if let detail { Text(detail).font(.caption).foregroundStyle(.tertiary) }
                }
                Spacer(minLength: 12)
                control()
            }
            .padding(.vertical, 8)
            if !last { Divider() }
        }
    }

    /// Letters, digits, `_` and `-`: what the file format allows; a space or a colon becomes `_`.
    private static func cleaned(_ text: String) -> String {
        String(text.map { $0 == " " || $0 == ":" ? "_" : $0 }.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") })
    }

    private func setBeats(_ beats: Int) {
        draft.beats = beats
        draft.pattern = MapSection.resized(pattern: draft.pattern, to: beats)
        draft.fitTempi()
    }

    private func setDenominator(_ denominator: Int) {
        draft.denominator = denominator
        setBeats(MeterRules.numerator(draft.beats, for: denominator))
    }

    private func cyclePattern(_ i: Int) {
        var chars = Array(draft.pattern)
        chars[i] = chars[i] == "X" ? "x" : chars[i] == "x" ? "." : "X"
        draft.pattern = String(chars)
    }

    /// A tempo typed in a field is taken when it is a number within the limits; the field keeps what is typed meanwhile.
    private func applyTempo() {
        guard !draft.hasTempoPerBeat else { return }
        if let start = Double(startText), Self.limits.contains(start) { draft.tempo = start.rounded() }
        if let end = Double(endText), Self.limits.contains(end) {
            draft.tempoEnd = end.rounded() == draft.tempo ? nil : end.rounded()
        }
    }

    private func commit() {
        applyTempo()
        if let index = target.index { model.updateSection(at: index) { $0 = draft } } else { model.addSection(draft) }
        dismiss()
    }
}
