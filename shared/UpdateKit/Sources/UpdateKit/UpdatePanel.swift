// SPDX-License-Identifier: MIT

import SwiftUI
import AppKit
import AppearanceKit

/// The window of the updates: one at a time, which follows the appearance of the application.
@MainActor
enum UpdatePanel {
    private static var window: NSWindow?

    /// Gives the window the height of its content, keeping its top where it is.
    static func fit(toHeight height: CGFloat) {
        DispatchQueue.main.async {
            guard let window, abs(window.contentRect(forFrameRect: window.frame).height - height) > 0.5 else { return }
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: CGSize(width: UpdateView.width, height: height)))
            frame.origin.x = window.frame.origin.x
            frame.origin.y = window.frame.maxY - frame.height
            window.setFrame(frame, display: true, animate: window.isVisible)
        }
    }

    static func show(controller: UpdateController) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let content = UpdateView(controller: controller, close: { UpdatePanel.window?.close() }, heightChanged: { UpdatePanel.fit(toHeight: $0) })
            .environment(controller.appearance)
            .appAccent(controller.appearance)
        // The hosting view sits in a plain view of a window that has its own size, as in the About panel: a hosting controller that
        // follows its content changes the constraints of the window while they are being computed, which AppKit refuses (the
        // application stops). The view tells its height when it changes, and the window is resized after the layout, not during it.
        let host = NSHostingView(rootView: content)
        let container = NSView(frame: NSRect(origin: .zero, size: CGSize(width: UpdateView.width, height: UpdateView.initialHeight)))
        host.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        let panel = NSWindow(contentRect: NSRect(origin: .zero, size: CGSize(width: UpdateView.width, height: UpdateView.initialHeight)), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.contentView = container
        panel.title = String(localized: "Mises à jour")
        panel.isReleasedWhenClosed = false
        panel.appearance = NSApp.appearance
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { [weak controller] _ in
            MainActor.assumeIsolated {
                UpdatePanel.window = nil
                controller?.panelClosed()
            }
        }
        panel.makeKeyAndOrderFront(nil)
        window = panel
    }
}

struct UpdateView: View {
    @ObservedObject var controller: UpdateController
    let close: () -> Void
    /// Called with the height that the content needs, each time it changes.
    let heightChanged: (CGFloat) -> Void
    @State private var busy = false
    @Environment(\.appAccentColor) private var accent

    static let width: CGFloat = 540
    /// The height of the window before the content has said its own.
    static let initialHeight: CGFloat = 230

    private var name: String { controller.configuration.appName }
    private var installedText: String {
        controller.installed?.text(revisionWord: String(localized: "révision")) ?? "?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 8) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            Toggle(String(localized: "Rechercher automatiquement les mises à jour"), isOn: $controller.automaticChecks)
                .toggleStyle(.checkbox)
                .accentTint()
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                buttons
            }
        }
        .padding(20)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heightChanged($0) }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { busy = controller.isBusy }
        // The application may start or stop something while the panel is open.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in busy = controller.isBusy }
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
    }

    private func detail(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var content: some View {
        switch controller.phase {
        case .idle, .checking:
            title(String(localized: "Recherche d'une mise à jour…"))
            ProgressView().controlSize(.small)
        case .upToDate:
            title(String(localized: "\(name) est à jour."))
            detail(String(localized: "Version installée : \(installedText)"))
        case .available(let offer):
            title(String(localized: "Une nouvelle version de \(name) est disponible."))
            detail(String(localized: "Version installée : \(installedText)"))
            detail(String(localized: "Nouvelle version : \(offer.label.text(revisionWord: String(localized: "révision")))"))
            Link(String(localized: "Notes de version"), destination: offer.page)
                .font(.system(size: 12))
                .foregroundStyle(accent)
            if busy {
                Label(String(localized: "Arrêtez ce qui est en cours avant d'installer."), systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
        case .downloading(let value):
            title(String(localized: "Téléchargement…"))
            ProgressView(value: value).accentTint()
            detail("\(Int((value * 100).rounded())) %")
        case .verifying:
            title(String(localized: "Vérification du paquet…"))
            ProgressView().controlSize(.small)
        case .opened:
            title(String(localized: "L'installateur est ouvert."))
            detail(String(localized: "Quittez \(name), puis suivez les étapes de l'installateur. Rouvrez l'application ensuite."))
        case .failed(let problem):
            title(String(localized: "La mise à jour a échoué."))
            switch problem {
            case .network: detail(String(localized: "Impossible de joindre GitHub."))
            case .checksum: detail(String(localized: "Le paquet téléchargé est corrompu."))
            case .signature: detail(String(localized: "Le paquet n'est pas signé et notarisé par l'auteur."))
            }
        }
    }

    @ViewBuilder private var buttons: some View {
        switch controller.phase {
        case .available:
            Button(String(localized: "Ignorer cette version")) {
                controller.skipVersion()
                close()
            }
            Button(String(localized: "Plus tard"), action: close)
            Button(String(localized: "Télécharger et installer")) { controller.install() }
                .keyboardShortcut(.defaultAction)
                .accentTint()
                .disabled(busy)
        case .opened:
            Button(String(localized: "Fermer"), action: close)
            Button(String(localized: "Quitter \(name)")) { controller.quitApplication() }
                .keyboardShortcut(.defaultAction)
                .accentTint()
        case .failed:
            Button(String(localized: "Page des versions")) { NSWorkspace.shared.open(controller.releasesPage) }
            Button(String(localized: "Fermer"), action: close)
            Button(String(localized: "Réessayer")) { Task { await controller.check(manual: true) } }
                .keyboardShortcut(.defaultAction)
                .accentTint()
        case .idle, .checking, .upToDate, .downloading, .verifying:
            Button(String(localized: "Fermer"), action: close)
                .keyboardShortcut(.defaultAction)
                .accentTint()
        }
    }
}
