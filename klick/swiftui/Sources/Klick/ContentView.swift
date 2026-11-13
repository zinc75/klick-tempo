// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit
import KlickKit
import AppearanceKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var columns: NavigationSplitViewVisibility = {
        #if DEBUG
        // Development aid: KLICK_SIDEBAR=hidden starts with the sidebar folded.
        if ProcessInfo.processInfo.environment["KLICK_SIDEBAR"] == "hidden" { return .detailOnly }
        #endif
        return .automatic
    }()

    /// The settings: the sidebar and the page, with the footer running under both over the whole width of the window. The
    /// metronome page has its own big button.
    private var settingsView: some View {
        // The footer is below the split view, not over it: the pages and their scroll bars end where it begins.
        VStack(spacing: 0) {
            splitView
            if model.page != .metronome { FooterBar() }
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columns) {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            PageView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let message = model.errorMessage { ErrorBanner(message: message) { model.errorMessage = nil } }
                }
        }
    }

    var body: some View {
        // While it plays, the live view takes the whole window: no sidebar, no footer.
        Group {
            if model.showsLiveView { LivePage() } else { settingsView }
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
        .onKeyPress(.escape) {
            guard model.showsLiveView else { return .ignored }
            model.leaveLiveView()
            return .handled
        }
        // On the metronome page: the arrows change the tempo (up and down by ten, left and right by one), T taps it.
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
            guard model.page == .metronome, !model.showsLiveView else { return .ignored }
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
        .task {
            // The user may change the output in the settings of the system: look again now and then.
            while !Task.isCancelled {
                model.refreshOutput()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in model.stop() }
        #if DEBUG
        .task {
            // Development aid: KLICK_AUTOPLAY=1 starts playing once the window is up (for screenshots of the playing state).
            guard ProcessInfo.processInfo.environment["KLICK_AUTOPLAY"] != nil else { return }
            try? await Task.sleep(for: .milliseconds(2500))
            model.start(model.mode)
        }
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
        case .map: MapPage()
        case .sounds: SoundsPage()
        case .output: OutputPage()
        case .export: ExportPage()
        case .appearance: AppearancePage()
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

/// Toolbar items: the silent mode, the state of the output, and while it plays the way to the live view.
struct MainToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        // The silent mode first, so that it is at hand from every page; then the output. On macOS 26 neighbouring
        // items share one glass capsule: the buttons leave it and take a capsule of their own.
        if #available(macOS 26, *) {
            ToolbarItem(placement: .primaryAction) { QuietButton(ownGlass: true) }
                .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { StatusPill() }
            // While it plays and the settings are in view: the way to the live view.
            if model.isPlaying && !model.showsLiveView {
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { LiveViewButton(ownGlass: true) }
                    .sharedBackgroundVisibility(.hidden)
            }
        } else {
            ToolbarItem(placement: .primaryAction) { QuietButton() }
            ToolbarItem(placement: .primaryAction) { StatusPill() }
            if model.isPlaying && !model.showsLiveView {
                ToolbarItem(placement: .primaryAction) { LiveViewButton() }
            }
        }
    }
}

/// The way to the live view: four corners, as in a button that enlarges, and a word.
struct LiveViewButton: View {
    var ownGlass = false
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.enterLiveView() } label: {
            Label("Vue simplifiée", systemImage: "arrow.up.left.and.arrow.down.right")
                .labelStyle(.titleAndIcon)
                .font(.callout)
                .padding(.horizontal, ownGlass ? 12 : 0)
                .frame(height: ownGlass ? 30 : nil)
                .modifier(OwnGlass(enabled: ownGlass, capsule: true))
        }
        .buttonStyle(.plain)
        .help("Ne montrer que ce qui joue (⌘0)")
    }
}

/// The silent mode: no click is heard, the lamps and the count-in are only seen. In the toolbar, so that it is reachable from
/// every page.
struct QuietButton: View {
    @Environment(\.appAccentColor) private var accent
    /// On macOS 26 the button draws the glass disc itself, as it is kept out of the capsule of its neighbours.
    var ownGlass = false
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.settings.isQuiet.toggle()
        } label: {
            Image(systemName: model.settings.isQuiet ? "speaker.slash.fill" : "speaker.wave.2")
                .foregroundStyle(model.settings.isQuiet ? accent : .secondary)
                .frame(width: ownGlass ? 30 : nil, height: ownGlass ? 30 : nil)
                .modifier(OwnGlass(enabled: ownGlass))
        }
        .buttonStyle(.plain)
        .help(LocalizedStringKey(model.settings.isQuiet ? "Silencieux : seulement les lampes (⌥⌘M)" : "Passer en mode silencieux (⌥⌘M)"))
        .accessibilityLabel("Silencieux")
    }
}

/// The audio backend in use (CoreAudio, JACK), with its light (green when it works, red when it does not). A click opens a menu to
/// choose the backend, when there are several, and the output; the page "Sortie" has the rest.
struct StatusPill: View {
    @Environment(AppModel.self) private var model
    @State private var isOpen = false

    var body: some View {
        // The rate of the engine (the one that was always shown); the device may run at another, CoreAudio converting.
        let kHz = (Double(model.player.sampleRate) / 1000).formatted(.number.precision(.fractionLength(0...1)))
        let deviceKHz = (model.output.sampleRate / 1000).formatted(.number.precision(.fractionLength(0...1)))
        let healthy = model.errorMessage == nil && !model.isChosenOutputMissing && !model.player.isBackendShutdown
        Button { isOpen.toggle() } label: {
            HStack(spacing: 6) {
                Circle().fill(healthy ? Color.green : Color.red).frame(width: 8, height: 8)
                Text(verbatim: "\(model.backend.name) · \(kHz) kHz").font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) { PillMenu(close: { isOpen = false }) }
        .help("\(model.output.name) · \(deviceKHz) kHz : choisir la sortie")
        .accessibilityLabel("Sortie audio")
    }
}

/// What the pill opens: the backends to choose from when there are several, then what the backend in use offers.
private struct PillMenu: View {
    let close: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if model.backends.count > 1 {
                Text("Moteur audio").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.bottom, 4)
                ForEach(model.backends, id: \.id) { backend in
                    PillRow(title: Text(verbatim: backend.name), detail: unavailableReason(backend), selected: model.backend.id == backend.id, close: close) {
                        model.switchBackend(to: backend.id)
                    }
                }
                Divider().padding(.vertical, 4)
            }
            BackendRegistry.interface(for: model.backend.id).pillMenu(model: model, close: close)
        }
        .padding(8)
        .frame(width: 300)
    }

    private func unavailableReason(_ backend: AudioBackend) -> String? {
        if case .unavailable(let reason) = backend.availability { return reason }
        return nil
    }
}

/// A row of the menu of the pill: a check mark when it is the choice, a title, a line under it.
struct PillRow: View {
    let title: Text
    var detail: String?
    var selected: Bool?
    let close: () -> Void
    let action: () -> Void

    var body: some View {
        Button {
            action()
            close()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).opacity(selected == true ? 1 : 0).frame(width: 14)
                VStack(alignment: .leading, spacing: 0) {
                    title
                    if let detail { Text(verbatim: detail).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowStyle())
    }

    private struct RowStyle: ButtonStyle {
        @Environment(\.appAccentColor) private var accent
        @State private var hovered = false
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(RoundedRectangle(cornerRadius: 6).fill(configuration.isPressed ? accent.opacity(0.3) : hovered ? Color.primary.opacity(0.1) : .clear))
                .onHover { hovered = $0 }
        }
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
