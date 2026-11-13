// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit
import KlickKit

/// What the window shows while it plays: the tempo (or the count-in), the beats and the notation, and for a tempo map the
/// section and the timeline. Nothing here changes a setting: the button "Configuration" and the key Escape go back to them.
struct LivePage: View {
    @Environment(AppModel.self) private var model
    @State private var lit: Int?

    var body: some View {
        let player = model.player
        let counting = player.phase == .countIn && player.countInRemaining > 0
        let section = currentSection
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    if player.mode == .map { MapNameButton() }
                    Text(verbatim: meta(counting: counting, section: section))
                }
                .font(.callout).foregroundStyle(.secondary)
                if player.mode == .map, !counting, let section {
                    Text(verbatim: section.label.isEmpty ? String(localized: "Section \(player.sectionIndex + 1)") : section.label)
                        .font(.title2).fontWeight(.semibold)
                }
                Text(verbatim: counting ? "\(player.countInRemaining)" : "\(Int(shownTempo.rounded()))")
                    .font(.system(size: 190, weight: .ultraLight))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                Text(LocalizedStringKey(counting ? "DÉCOMPTE" : "BATTEMENTS PAR MINUTE")).font(.caption).tracking(1.5).foregroundStyle(.tertiary)
                if !counting {
                    Text(verbatim: TempoWord.name(for: shownTempo)).font(.title3).italic().foregroundStyle(.secondary)
                }

                Lamps(pattern: pattern(of: section), lit: lit)
                    .padding(.top, 16)

                if !counting {
                    StaffView(layout: StaffLayout(beats: beats(of: section), denominator: denominator(of: section), pattern: pattern(of: section)),
                              lit: lit)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: 820)

            if player.mode == .map {
                Timeline()
                    .frame(maxWidth: 760)
                    .padding(.top, 18).padding(.horizontal, 26)
            }

            Spacer(minLength: 12)

            GoButton(diameter: 84)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The way back, a glass pill at the top left of the window, under the title bar.
        .overlay(alignment: .topLeading) {
            BackButton { model.leaveLiveView() }
                .padding(.top, 12).padding(.leading, 16)
        }
        // The choice of what plays, at the bottom right, in answer to the way back at the top left.
        .overlay(alignment: .bottomTrailing) {
            ModePicker()
                .padding(.bottom, 44).padding(.trailing, 24)
        }
        // A soft glow of the accent at the top while it plays.
        .background {
            RadialGradient(colors: [Color.accentColor.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onChange(of: player.beatCount) {
            guard let beat = player.beat else { return }
            let index = beat.beat
            lit = index
            Task {
                try? await Task.sleep(for: .milliseconds(110))
                if lit == index { lit = nil }
            }
        }
    }

    /// What is playing: the metronome and its bar, or the map, the section and the bar in it; the count-in while it runs.
    private func meta(counting: Bool, section: MapSection?) -> String {
        let player = model.player
        if player.mode == .map {
            if counting { return String(localized: "décompte") }
            let total = model.document.sections.count
            var parts = [String(localized: "section \(player.sectionIndex + 1) sur \(total)")]
            if let section, player.phase == .playing, player.beat != nil {
                parts.append(String(localized: "mesure \(player.sectionBar + 1) sur \(section.bars)"))
            }
            return parts.joined(separator: " · ")
        }
        let name = String(localized: "Métronome") + " \(model.settings.beats)/\(model.settings.denominator)"
        if counting { return "\(name) · " + String(localized: "décompte") }
        return player.barCount > 0 ? name + " · " + String(localized: "mesure \(player.barCount)") : name
    }

    /// The tempo heard; the one that is set until the first beat comes.
    private var shownTempo: Double {
        model.player.tempo > 0 ? model.player.tempo : (currentSection?.tempo ?? model.settings.tempo)
    }

    /// The section being played, for a map.
    private var currentSection: MapSection? {
        guard model.player.mode == .map else { return nil }
        let sections = model.document.sections
        return sections.indices.contains(model.player.sectionIndex) ? sections[model.player.sectionIndex] : nil
    }

    /// The count-in has its own bar: an accent, then normal beats.
    private func beats(of section: MapSection?) -> Int {
        if model.player.phase == .countIn { return max(model.player.beat?.beats ?? 4, 1) }
        return section?.beats ?? model.settings.beats
    }

    private func denominator(of section: MapSection?) -> Int { section?.denominator ?? model.settings.denominator }

    private func pattern(of section: MapSection?) -> String {
        if model.player.phase == .countIn { return MapSection.defaultPattern(beats: beats(of: section)) }
        return section?.pattern ?? model.settings.pattern
    }
}

/// One lamp per beat, as large as the window allows; they only show.
private struct Lamps: View {
    let pattern: String
    let lit: Int?

    var body: some View {
        let chars = Array(pattern)
        let small = chars.count > 8
        HStack(spacing: small ? 10 : 18) {
            ForEach(chars.indices, id: \.self) { i in
                let size: CGFloat = chars[i] == "X" ? (small ? 46 : 62) : (small ? 38 : 50)
                Text(verbatim: chars[i] == "." ? "·" : "\(i + 1)")
                    .font(.system(size: small ? 14 : 19, weight: .semibold))
                    .frame(width: size, height: size)
                    .background(Circle().fill(chars[i] == "." ? Color.clear : lit == i ? Color.accentColor : Color.primary.opacity(0.12)))
                    .overlay { if chars[i] == "." { Circle().strokeBorder(.quaternary, lineWidth: 1.5) } }
                    .foregroundStyle(lit == i ? Color.white : .secondary)
                    .shadow(color: lit == i ? Color.accentColor.opacity(0.7) : .clear, radius: 14)
                    .scaleEffect(lit == i ? 1.1 : 1)
                    .frame(minWidth: 50, minHeight: 72)
            }
        }
        .animation(.easeOut(duration: 0.08), value: lit)
        .accessibilityHidden(true)
    }
}

/// The sections of the map side by side, as wide as their number of bars: the ones played are filled, the one playing fills as
/// the bars go by, and the next one is named.
private struct Timeline: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let sections = model.document.sections
        let total = max(1, sections.reduce(0) { $0 + $1.bars })
        let player = model.player
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let gaps = CGFloat(max(0, sections.count - 1)) * 3
                let unit = max(0, geometry.size.width - gaps) / CGFloat(total)
                HStack(spacing: 3) {
                    ForEach(sections.indices, id: \.self) { i in
                        let s = sections[i]
                        let fraction = fill(of: i)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(s.muted ? 0.05 : 0.12))
                            RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(i == player.sectionIndex ? 1 : 0.55))
                                .frame(width: max(0, unit * CGFloat(s.bars) * fraction))
                        }
                        .frame(width: max(4, unit * CGFloat(s.bars)))
                    }
                }
            }
            .frame(height: 26)
            if let next = nextSection {
                HStack(spacing: 6) {
                    Text("Ensuite").foregroundStyle(.tertiary)
                    Text(verbatim: next.label.isEmpty ? "\(Int(next.tempo.rounded()))" : "\(next.label) · \(Int(next.tempo.rounded()))")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .accessibilityHidden(true)
    }

    /// How much of a section is behind: all of the ones before the current, the bars heard of the current, none after.
    private func fill(of index: Int) -> Double {
        let player = model.player
        guard player.phase == .playing else { return 0 }
        if index < player.sectionIndex { return 1 }
        if index > player.sectionIndex { return 0 }
        let before = model.document.sections.prefix(index).reduce(0) { $0 + $1.bars }
        let bars = max(1, model.document.sections[index].bars)
        return min(1, max(0, (player.mapPosition - Double(before)) / Double(bars)))
    }

    private var nextSection: MapSection? {
        let sections = model.document.sections
        let next = model.player.sectionIndex + 1
        return model.player.phase == .playing && sections.indices.contains(next) ? sections[next] : nil
    }
}

/// The name of the map (its file, or "Sans titre" until it is saved), as a button that opens the map in its editor while it plays on.
private struct MapNameButton: View {
    @Environment(AppModel.self) private var model
    @State private var hovered = false

    var body: some View {
        let url = model.document.url
        let name = url?.deletingPathExtension().lastPathComponent ?? String(localized: "Sans titre")
        HStack(spacing: 6) {
            Button { model.show(.map) } label: {
                Label(name, systemImage: "doc.text")
                    .foregroundStyle(hovered ? Color.accentColor : .primary)
                    .underline(hovered)
            }
            .buttonStyle(.plain)
            .onHover { hovered = $0 }
            .help("Ouvrir la carte dans l'éditeur")
            Text(verbatim: "·")
        }
    }
}

/// "Configuration": back to the settings, the playing goes on.
private struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Configuration", systemImage: "chevron.left")
                .font(.callout)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .modifier(LivePill())
        }
        .buttonStyle(.plain)
        .help("Revenir aux réglages (Échap)")
    }
}

/// A glass capsule on macOS 26, a soft fill before.
private struct LivePill: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *), GlassSupport.enabled {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content.background(Capsule().fill(Color.primary.opacity(0.1)))
                .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
        }
    }
}
