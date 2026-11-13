// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit
import KlickKit

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            PageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // The metronome page has its own big button.
                    if model.page != .metronome { FooterBar() }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let message = model.errorMessage { ErrorBanner(message: message) { model.errorMessage = nil } }
                }
        }
        // Plain window background: only the blocks are Liquid Glass.
        .containerBackground(Color.windowFill, for: .window)
        .navigationTitle("Klick")
        .navigationSubtitle("Jack Apps Collection for macOS")
        .toolbar { MainToolbar() }
        // The space bar starts and stops, unless a text field has the keyboard.
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) { model.togglePlayback(); return .handled }
        // On the metronome page: the arrows change the tempo (up and down by ten, left and right by one), T taps it.
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
            guard model.page == .metronome else { return .ignored }
            switch press.key {
            case .upArrow: model.nudgeTempo(10)
            case .downArrow: model.nudgeTempo(-10)
            case .rightArrow: model.nudgeTempo(1)
            default: model.nudgeTempo(-1)
            }
            return .handled
        }
        .onKeyPress("t") {
            guard model.page == .metronome else { return .ignored }
            model.tap()
            return .handled
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in model.stop() }
        #if DEBUG
        .task {
            // A development run started from a Terminal in the background must still look active (accent colour, focus).
            NSApp.activate(ignoringOtherApps: true)
        }
        .task {
            // Development aid: KLICK_PAGE=map opens that page (metronome, map, sounds, output, export).
            if let page = ProcessInfo.processInfo.environment["KLICK_PAGE"].flatMap(Page.init(rawValue:)) {
                try? await Task.sleep(for: .milliseconds(800))
                model.show(page)
            }
        }
        #endif
    }
}

/// The page shown in the detail area.
struct PageView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.page {
        case .metronome: MetronomePage()
        case .map: PagePlaceholder(title: "Carte de tempo", text: "Une suite de sections jouées l'une après l'autre.")
        case .sounds: PagePlaceholder(title: "Sons", text: "Un son pour l'accent et un pour les autres temps.")
        case .output: PagePlaceholder(title: "Sortie", text: "Où va le son du métronome.")
        case .export: PagePlaceholder(title: "Exporter", text: "Une piste de clics dans un fichier audio.")
        }
    }
}

/// A page that is not drawn yet.
struct PagePlaceholder: View {
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2).fontWeight(.semibold)
            Text(text).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 26).padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Toolbar items: the state of the output and the look of the application, each on its own capsule.
struct MainToolbar: ToolbarContent {
    var body: some ToolbarContent {
        // The silent mode first, so that it is at hand from every page; then the output; then the look. On macOS 26
        // neighbouring items share one glass capsule: the two buttons leave it and take a capsule of their own.
        if #available(macOS 26, *) {
            ToolbarItem(placement: .primaryAction) { QuietButton(ownGlass: true) }
                .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { StatusPill() }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { AppearanceButton(ownGlass: true) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .primaryAction) { QuietButton() }
            ToolbarItem(placement: .primaryAction) { StatusPill() }
            ToolbarItem(placement: .primaryAction) { AppearanceButton() }
        }
    }
}

/// The silent mode: no click is heard, the lamps and the count-in are only seen. In the toolbar, so that it is reachable from
/// every page.
struct QuietButton: View {
    /// On macOS 26 the button draws the glass disc itself, as it is kept out of the capsule of its neighbours.
    var ownGlass = false
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.settings.isQuiet.toggle()
        } label: {
            Image(systemName: model.settings.isQuiet ? "speaker.slash.fill" : "speaker.wave.2")
                .foregroundStyle(model.settings.isQuiet ? Color.accentColor : .secondary)
                .frame(width: ownGlass ? 30 : nil, height: ownGlass ? 30 : nil)
                .modifier(OwnGlass(enabled: ownGlass))
        }
        .buttonStyle(.plain)
        .help(model.settings.isQuiet ? "Silencieux : seulement les lampes (⌥⌘M)" : "Passer en mode silencieux (⌥⌘M)")
        .accessibilityLabel("Silencieux")
    }
}

/// The audio output in use. CoreAudio for now; JACK comes later.
struct StatusPill: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let kHz = (Double(model.player.sampleRate) / 1000).formatted(.number.precision(.fractionLength(0...1)))
        HStack(spacing: 6) {
            Circle().fill(model.errorMessage == nil ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(verbatim: "CoreAudio · \(kHz) kHz").font(.caption).fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .help("Sortie audio du système")
    }
}

/// A failure to start or to apply a setting, in the colour of the alerts.
struct ErrorBanner: View {
    let message: String
    let close: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(verbatim: message).textSelection(.enabled)
            Spacer(minLength: 12)
            Button("Fermer", action: close).buttonStyle(.borderless)
        }
        .foregroundStyle(Color.alert)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.alert.opacity(0.12))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.alert.opacity(0.35)).frame(height: 0.5) }
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}
