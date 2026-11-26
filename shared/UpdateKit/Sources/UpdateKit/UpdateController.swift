// SPDX-License-Identifier: MIT

import SwiftUI
import AppKit
import AppearanceKit

/// What an application tells the kit about itself.
public struct UpdateConfiguration {
    /// The name shown in the texts ("Jack Capture").
    public var appName: String
    /// The GitHub repository that holds the releases ("zinc75/jack-apps-collection-macos").
    public var repository: String
    /// What the tags of this tool begin with ("jack_capture-v"): a repository holds the releases of several tools.
    public var tagPrefix: String
    /// The team that signs the packages; a package signed by another is refused.
    public var teamID: String
    /// True while the application does something that an installation would cut (a recording, a playback): the installation waits.
    public var isBusy: @MainActor () -> Bool

    public init(appName: String, repository: String, tagPrefix: String, teamID: String = "R98ZGK7FWR", isBusy: @escaping @MainActor () -> Bool = { false }) {
        self.appName = appName
        self.repository = repository
        self.tagPrefix = tagPrefix
        self.teamID = teamID
        self.isBusy = isBusy
    }
}

/// Looks for a newer release of the tool on GitHub, downloads its package, checks it and opens it in the Installer.
///
/// The check is made at most once a day by itself (the answer is kept), and when the person asks for it in the menu. It never installs
/// anything silently: the package is opened in the Installer, which asks for the password, and the application is quit by the person.
@MainActor
public final class UpdateController: ObservableObject {
    public enum Problem: Equatable {
        case network
        case checksum
        case signature
    }

    public enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(UpdateOffer)
        case downloading(Double)
        case verifying
        case opened
        case failed(Problem)
    }

    @Published public private(set) var phase: Phase = .idle
    /// Whether the application looks for an update by itself, once a day. On unless the person turns it off.
    @Published public var automaticChecks: Bool {
        didSet { defaults.set(automaticChecks, forKey: Key.automatic) }
    }

    public let configuration: UpdateConfiguration
    public let installed: ReleaseLabel?
    let appearance: AppearanceSettings
    private let defaults: UserDefaults

    private enum Key {
        static let automatic = "UpdateKit.automaticChecks"
        static let skipped = "UpdateKit.skippedTag"
        static let cache = "UpdateKit.cache"
    }

    private struct Cache: Codable {
        var date: Date
        var offer: UpdateOffer?
    }

    private static let cacheLifetime: TimeInterval = 24 * 3600

    public init(configuration: UpdateConfiguration, appearance: AppearanceSettings, defaults: UserDefaults = .standard) {
        self.configuration = configuration
        self.appearance = appearance
        self.defaults = defaults
        self.installed = ReleaseLabel.installed()
        self.automaticChecks = defaults.object(forKey: Key.automatic) as? Bool ?? true
    }

    // MARK: - Checking

    /// To be called once at launch: after a few seconds, looks for an update if the person did not turn it off and the last answer is a day old.
    /// A newer version that the person did not skip opens the panel; anything else (up to date, no network) stays silent.
    public func startAutomaticChecks(after delay: TimeInterval = 5) {
        #if DEBUG
        // Development aids: UPDATEKIT_MENU=1 chooses the item of the menu bar at launch (and says in the log where it found it),
        // UPDATEKIT_AUTOINSTALL=1 installs the offer that is made.
        let environment = ProcessInfo.processInfo.environment
        if environment["UPDATEKIT_MENU"] != nil {
            Task {
                try? await Task.sleep(for: .seconds(delay))
                Self.chooseMenuItem()
            }
            return
        }
        if environment["UPDATEKIT_AUTOINSTALL"] != nil {
            Task {
                try? await Task.sleep(for: .seconds(delay))
                await check(manual: true)
                showPanel()
                try? await Task.sleep(for: .seconds(1))
                install()
            }
            return
        }
        #endif
        guard automaticChecks, installed != nil else { return }
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await check(manual: false)
        }
    }

    /// The menu item: opens the panel and looks for an update, unless one is already known or being installed.
    public func checkFromMenu() {
        showPanel()
        switch phase {
        case .idle, .upToDate, .failed: Task { await check(manual: true) }
        case .checking, .available, .downloading, .verifying, .opened: break
        }
    }

    /// Looks for a newer release. A manual check ignores the answer kept and the version skipped, and says what it finds.
    public func check(manual: Bool) async {
        switch phase {
        case .checking, .downloading, .verifying: return
        default: break
        }
        guard let installed else {
            if manual { phase = .failed(.network) }
            return
        }
        if manual { phase = .checking }
        let offer: UpdateOffer?
        do {
            if !manual, let cache = freshCache() {
                offer = cache.offer
            } else {
                let data = try await Self.load(feedURL)
                offer = UpdateFeed.newestOffer(in: try UpdateFeed.decode(data), tagPrefix: configuration.tagPrefix)
                store(Cache(date: Date(), offer: offer))
            }
        } catch {
            if manual { phase = .failed(.network) }
            return
        }
        guard let offer, offer.label.version > installed.version else {
            if manual { phase = .upToDate }
            return
        }
        if !manual, defaults.string(forKey: Key.skipped) == offer.tag { return }
        phase = .available(offer)
        if !manual { showPanel() }
    }

    #if DEBUG
    /// Chooses "Check for Updates…" in the menu bar, as a click would, to see that the item is in the menu of the application.
    private static func chooseMenuItem() {
        let title = String(localized: "Rechercher les mises à jour…")
        for top in NSApp.mainMenu?.items ?? [] {
            guard let menu = top.submenu, let index = menu.items.firstIndex(where: { $0.title == title }) else { continue }
            NSLog("UpdateKit: item '%@' found in the menu '%@', at %d", title, menu.title, index)
            menu.performActionForItem(at: index)
            return
        }
        NSLog("UpdateKit: no item '%@' in the menu bar", title)
        for top in NSApp.mainMenu?.items ?? [] {
            NSLog("UpdateKit: menu '%@': %@", top.submenu?.title ?? "?", (top.submenu?.items.map { $0.isSeparatorItem ? "-" : $0.title } ?? []).joined(separator: " | "))
        }
    }
    #endif

    private var feedURL: URL {
        #if DEBUG
        // A development aid: UPDATEKIT_FEED is a file or an address with the JSON that GitHub would give.
        if let text = ProcessInfo.processInfo.environment["UPDATEKIT_FEED"] {
            return text.hasPrefix("/") ? URL(fileURLWithPath: text) : (URL(string: text) ?? UpdateFeed.feedURL(repository: configuration.repository))
        }
        #endif
        return UpdateFeed.feedURL(repository: configuration.repository)
    }

    private func freshCache() -> Cache? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UPDATEKIT_FEED"] != nil { return nil }
        #endif
        guard let data = defaults.data(forKey: Key.cache), let cache = try? JSONDecoder().decode(Cache.self, from: data),
              Date().timeIntervalSince(cache.date) < Self.cacheLifetime else { return nil }
        return cache
    }

    private func store(_ cache: Cache) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UPDATEKIT_FEED"] != nil { return }
        #endif
        defaults.set(try? JSONEncoder().encode(cache), forKey: Key.cache)
    }

    nonisolated static func load(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
        return data
    }

    // MARK: - Installing

    /// The person does not want this version: the panel will not open by itself for it (the menu still offers it).
    public func skipVersion() {
        if case .available(let offer) = phase { defaults.set(offer.tag, forKey: Key.skipped) }
        phase = .idle
    }

    public var isBusy: Bool { configuration.isBusy() }

    /// Downloads the package of the offer, checks it, and opens it in the Installer.
    public func install() {
        guard case .available(let offer) = phase, !isBusy else { return }
        phase = .downloading(0)
        Task { await perform(offer) }
    }

    private func perform(_ offer: UpdateOffer) async {
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("JackAppsCollectionUpdate", isDirectory: true)
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let package = folder.appendingPathComponent(offer.packageName)
            let downloader = PackageDownloader(destination: package) { [weak self] value in
                Task { @MainActor in self?.progress(value) }
            }
            try await downloader.run(from: offer.packageURL)
            phase = .verifying
            if let checksumURL = offer.checksumURL {
                let text = String(decoding: try await Self.load(checksumURL), as: UTF8.self)
                let actual = try await Task.detached { try PackageVerifier.sha256(of: package) }.value
                guard PackageVerifier.expectedChecksum(in: text) == actual else { throw PackageVerifier.Failure.checksum }
            }
            #if DEBUG
            let checksSignature = ProcessInfo.processInfo.environment["UPDATEKIT_ALLOW_UNSIGNED"] == nil
            let opensInstaller = ProcessInfo.processInfo.environment["UPDATEKIT_NO_OPEN"] == nil
            #else
            let checksSignature = true
            let opensInstaller = true
            #endif
            if checksSignature { try await PackageVerifier.verifySignature(of: package, teamID: configuration.teamID) }
            if opensInstaller { NSWorkspace.shared.open(package) }
            phase = .opened
        } catch PackageVerifier.Failure.checksum {
            phase = .failed(.checksum)
        } catch PackageVerifier.Failure.signature {
            phase = .failed(.signature)
        } catch {
            phase = .failed(.network)
        }
    }

    private func progress(_ value: Double) {
        guard case .downloading(let current) = phase, value - current >= 0.01 || value >= 1 else { return }
        phase = .downloading(min(value, 1))
    }

    /// Quits the application, which asks what it runs first, as for any other quit.
    public func quitApplication() { NSApp.terminate(nil) }

    public var releasesPage: URL { URL(string: "https://github.com/\(configuration.repository)/releases")! }

    // MARK: - Panel

    public func showPanel() { UpdatePanel.show(controller: self) }

    /// The panel was closed: what it said about a check that is over is forgotten, so that the next opening looks again.
    func panelClosed() {
        switch phase {
        case .upToDate, .failed, .opened: phase = .idle
        default: break
        }
    }
}

/// The menu item, under "About": add it to the scene with `.commands { UpdateCommands(controller: updates) }`.
public struct UpdateCommands: Commands {
    private let controller: UpdateController?

    /// With no controller, the menu has no item (an application that does not look for updates).
    public init(controller: UpdateController?) { self.controller = controller }

    public var body: some Commands {
        CommandGroup(after: .appInfo) {
            if let controller {
                Button(String(localized: "Rechercher les mises à jour…")) { controller.checkFromMenu() }
            }
        }
    }
}
