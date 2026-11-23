// SPDX-License-Identifier: MIT

import SwiftUI
import AppKit

/// What the "About" panel of an application says. The texts arrive already translated: each application owns its catalog.
public struct AboutInfo {
    /// The name of the application ("Zita Network Bridge").
    public var name: String
    /// The version line ("0.4.8 macOS Edition").
    public var version: String
    /// The collection the application belongs to, under the version; nil for an application that is not part of it.
    public var collection: String? = "Jack Apps Collection for macOS"
    /// The page of the collection: the name of the collection links to it.
    public var collectionURL: URL? = URL(string: "https://github.com/zinc75/jack-apps-collection-macos")
    /// One sentence on what the application is ("Unofficial interface for zita-njbridge, by Fons Adriaensen.").
    public var summary: String
    /// The credits and the licence, one line each.
    public var lines: [String]
    /// The copyright line.
    public var copyright: String
    /// The page of the source code, and the page that supports the author; nil hides the button.
    public var sourceURL: URL?
    public var supportURL: URL?
    /// The licence text shipped in `Contents/Resources/Licenses` (opened by the "Licence" button), and the address to open when the
    /// file is not there (a build that did not write the licences).
    public var licenseFile: String?
    public var licenseURL: URL?

    /// The version line with the revision of the package and the day it was built, when the bundle says them (`JACRevision` and `JACBuildDate`, written by
    /// the build): "0.4.8 macOS Edition · révision 3 · 24 novembre 2026".
    public var versionLine: String {
        var parts = [version]
        let bundle = Bundle.main
        if let revision = bundle.object(forInfoDictionaryKey: "JACRevision") as? String, !revision.isEmpty {
            parts.append(String(localized: "révision") + " " + revision)
        }
        if let text = bundle.object(forInfoDictionaryKey: "JACBuildDate") as? String,
           let date = try? Date(text, strategy: .iso8601.year().month().day()) {
            parts.append(date.formatted(date: .long, time: .omitted))
        }
        return parts.joined(separator: " · ")
    }

    public init(name: String, version: String, summary: String, lines: [String] = [], copyright: String,
                sourceURL: URL? = nil, supportURL: URL? = nil, licenseFile: String? = nil, licenseURL: URL? = nil) {
        self.name = name
        self.version = version
        self.summary = summary
        self.lines = lines
        self.copyright = copyright
        self.sourceURL = sourceURL
        self.supportURL = supportURL
        self.licenseFile = licenseFile
        self.licenseURL = licenseURL
    }
}

/// The "About" panel of the applications of the collection: the layout of JackMate (icon on the left; name, version, texts and
/// buttons on the right), in a panel without a title bar that follows the appearance of the application.
@MainActor
public enum AboutPanel {
    private static var panel: NSPanel?

    /// Shows the panel, or brings the one that is already open to the front.
    public static func show(_ info: AboutInfo, appearance: AppearanceSettings) {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = info.name
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.appearance = NSApp.appearance
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        let content = AboutContent(info: info) { [weak panel] in panel?.close() }
            .environment(appearance)
            .appAccent(appearance)
        let host = NSHostingView(rootView: content)
        // The panel has the size of the content; the hosting view must not grow it by the height of the transparent title bar.
        let size = host.fittingSize
        host.sizingOptions = []
        // The hosting view sits in a plain view of the panel: as the content view itself, it asks the window for room for the
        // title bar it ignores.
        let container = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        panel.contentView = container
        panel.setFrame(NSRect(origin: .zero, size: size), display: false)
        panel.center()
        // Forget the panel when it is closed, so the next opening follows the appearance chosen in the meantime.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { _ in
            MainActor.assumeIsolated { AboutPanel.panel = nil }
        }
        panel.makeKeyAndOrderFront(nil)
        Self.panel = panel
    }

    fileprivate static func openLicense(_ info: AboutInfo) {
        if let file = info.licenseFile,
           let url = Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "Licenses") {
            NSWorkspace.shared.open(url)
        } else if let url = info.licenseURL {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct AboutContent: View {
    let info: AboutInfo
    let close: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 0) {
                Text(info.name)
                    .font(.system(size: 22, weight: .bold))
                    .padding(.bottom, 3)
                Text(info.versionLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if let collection = info.collection {
                    Group {
                        if let url = info.collectionURL {
                            Link(collection, destination: url).accentTint()
                        } else {
                            Text(collection).foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 12))
                    .padding(.top, 2)
                    .padding(.bottom, 14)
                } else {
                    Spacer().frame(height: 14 - 2)
                }

                Text(info.summary)
                    .font(.system(size: 12))
                    .padding(.bottom, 4)
                ForEach(info.lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 12))
                        .padding(.bottom, 4)
                }
                Text(info.copyright)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .padding(.bottom, 16)

                HStack(spacing: 8) {
                    if let url = info.sourceURL {
                        Button(String(localized: "Code source")) { NSWorkspace.shared.open(url) }
                    }
                    if info.licenseFile != nil || info.licenseURL != nil {
                        Button(String(localized: "Licence")) { AboutPanel.openLicense(info) }
                    }
                    if let url = info.supportURL {
                        Button(String(localized: "Soutenir ☕")) { NSWorkspace.shared.open(url) }
                    }
                    Spacer(minLength: 16)
                    Button(String(localized: "Fermer"), action: close)
                        .keyboardShortcut(.defaultAction)
                        .accentTint()
                }
            }
            .frame(maxWidth: 400, alignment: .leading)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .fixedSize()
        .background(Color(NSColor.windowBackgroundColor))
        .ignoresSafeArea()
    }
}
