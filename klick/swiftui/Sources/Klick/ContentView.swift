// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit
import KlickKit

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
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        // The silent mode first, so that it is at hand from every page; then the output; then the look. On macOS 26
        // neighbouring items share one glass capsule: the two buttons leave it and take a capsule of their own.
        if #available(macOS 26, *) {
            ToolbarItem(placement: .primaryAction) { QuietButton(ownGlass: true) }
                .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { StatusPill() }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            // While it plays and the settings are in view: the way to the live view, by the look button.
            if model.isPlaying && !model.showsLiveView {
                ToolbarItem(placement: .primaryAction) { LiveViewButton(ownGlass: true) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            ToolbarItem(placement: .primaryAction) { AppearanceButton(ownGlass: true) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .primaryAction) { QuietButton() }
            ToolbarItem(placement: .primaryAction) { StatusPill() }
            if model.isPlaying && !model.showsLiveView {
                ToolbarItem(placement: .primaryAction) { LiveViewButton() }
            }
            ToolbarItem(placement: .primaryAction) { AppearanceButton() }
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

/// The audio engine in use, with its light (green when it works, red when it does not). A click opens a list to choose the output,
/// from any page and from the live view; the page "Sortie" has the rest. With JACK the pill will say JACK.
struct StatusPill: View {
    @Environment(AppModel.self) private var model
    @State private var isOpen = false

    var body: some View {
        // The rate of the engine (the one that was always shown); the device may run at another, CoreAudio converting.
        let kHz = (Double(model.player.sampleRate) / 1000).formatted(.number.precision(.fractionLength(0...1)))
        let deviceKHz = (model.output.sampleRate / 1000).formatted(.number.precision(.fractionLength(0...1)))
        Button { isOpen.toggle() } label: {
            HStack(spacing: 6) {
                Circle().fill(model.errorMessage == nil && !model.isChosenOutputMissing ? Color.green : Color.red).frame(width: 8, height: 8)
                Text(verbatim: "CoreAudio · \(kHz) kHz").font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) { OutputChoice(close: { isOpen = false }) }
        .help("\(model.output.name) · \(deviceKHz) kHz : choisir la sortie")
        .accessibilityLabel("Sortie audio")
    }
}

/// The outputs to choose from: the system's, followed, or one of the devices.
private struct OutputChoice: View {
    let close: () -> Void
    @Environment(AppModel.self) private var model

    private var rate: String {
        (model.output.sampleRate / 1000).formatted(.number.precision(.fractionLength(0...1))) + " kHz"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Sortie").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.bottom, 4)
            row(Text("Suivre le système"), detail: model.settings.outputDeviceUID == nil ? model.output.name : nil, selected: model.settings.outputDeviceUID == nil) {
                model.chooseOutput(uid: nil)
            }
            ForEach(model.outputDevices) { device in
                row(Text(verbatim: device.name), detail: nil, selected: model.settings.outputDeviceUID == device.uid) {
                    model.chooseOutput(uid: device.uid)
                }
            }
            if model.isChosenOutputMissing {
                Label("La sortie choisie n'est pas branchée.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(Color.alert).padding(.horizontal, 10).padding(.vertical, 4)
            }
            Divider().padding(.vertical, 4)
            // What plays now: the output, the rate of the device (the engine works at its own rate, CoreAudio converts) and the
            // latency it announces.
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: model.output.name).font(.caption).fontWeight(.medium)
                Text(verbatim: "CoreAudio · \(rate) · \(Int(model.output.latencyMilliseconds.rounded())) ms")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.bottom, 4)
            row(Text("Réglages de la sortie…"), detail: nil, selected: nil) { model.show(.output) }
        }
        .padding(8)
        .frame(width: 300)
    }

    private func row(_ title: Text, detail: String?, selected: Bool?, action: @escaping () -> Void) -> some View {
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
        @State private var hovered = false
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(RoundedRectangle(cornerRadius: 6).fill(configuration.isPressed ? Color.accentColor.opacity(0.3) : hovered ? Color.primary.opacity(0.1) : .clear))
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
