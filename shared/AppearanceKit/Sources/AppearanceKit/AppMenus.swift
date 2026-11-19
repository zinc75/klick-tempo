// SPDX-License-Identifier: MIT

import SwiftUI
import AppKit

/// The menus every application of the collection shares, cleaned as JackMate's are: only what the application uses stays.
///
/// - The application menu: "About", with the panel of the collection, and no "Services".
/// - The window menu: Minimize and Zoom stay; "Move & Resize" and tiling go (see `MenuPruner`).
/// - The help menu: one item, which opens the page of the tool in the repository.
///
/// The items the system adds by itself (emoji, dictation, writing tools, AutoFill, window tiling) are turned off by
/// `disableSystemMenuAdditions()`, which also starts the `MenuPruner`.
public struct CollectionMenus: Commands {
    let about: AboutInfo
    let appearance: AppearanceSettings
    let documentationTitle: String
    let documentationURL: URL

    public init(about: AboutInfo, appearance: AppearanceSettings, documentationTitle: String, documentationURL: URL) {
        self.about = about
        self.appearance = appearance
        self.documentationTitle = documentationTitle
        self.documentationURL = documentationURL
    }

    public var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "À propos de \(about.name)")) { AboutPanel.show(about, appearance: appearance) }
        }
        CommandGroup(replacing: .systemServices) {}
        CommandGroup(replacing: .help) {
            Button(documentationTitle) { NSWorkspace.shared.open(documentationURL) }
        }
    }

    /// Turns off the items macOS adds to the edit menu on its own (emoji and symbols, dictation), and the tabs of windows. To be
    /// called from the initialiser of the application, before the first window opens.
    public static func disableSystemMenuAdditions() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "NSDisabledDictationMenuItem")
        defaults.set(true, forKey: "NSDisabledCharacterPaletteMenuItem")
        NSWindow.allowsAutomaticWindowTabbing = false
        MenuPruner.start()
    }
}

/// Removes what the system adds to the menus of its own accord and no application of the collection uses: the empty menus (Format),
/// the submenus of the edit menu (writing tools, AutoFill) and of the window menu (move and resize, tiling), and the separators
/// left alone. Items are recognised by their kind, never by their title, which changes with the language.
@MainActor
public enum MenuPruner {
    private static var started = false

    /// Prunes once the application has launched, whenever it becomes active, and whenever a menu is about to open (the system
    /// adds some of its items only then).
    public static func start() {
        guard !started else { return }
        started = true
        let center = NotificationCenter.default
        center.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { prune(afterDelay: 0.5) }
        }
        center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { prune(afterDelay: 0.2) }
        }
        center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { prune(afterDelay: 0) }
        }
    }

    private static func prune(afterDelay delay: TimeInterval) {
        if delay == 0 { prune(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { prune() }
    }

    public static func prune() {
        guard let main = NSApp.mainMenu else { return }
        for top in main.items {
            guard let menu = top.submenu else { continue }
            let actions = menu.items.compactMap(\.action).map(NSStringFromSelector)
            // The edit menu holds the cut-copy-paste items; the window menu "bring all to front".
            if actions.contains("paste:") || actions.contains("arrangeInFront:") {
                for item in menu.items.reversed() where item.hasSubmenu { menu.removeItem(item) }
            }
            tidySeparators(of: menu)
        }
        for top in main.items.reversed() {
            if let menu = top.submenu, menu.items.allSatisfy(\.isSeparatorItem) { main.removeItem(top) }
        }
    }

    /// No separator at either end, none twice in a row.
    private static func tidySeparators(of menu: NSMenu) {
        var previousWasSeparator = true
        for item in menu.items {
            if item.isSeparatorItem {
                if previousWasSeparator { menu.removeItem(item) }
                previousWasSeparator = true
            } else {
                previousWasSeparator = false
            }
        }
        while let last = menu.items.last, last.isSeparatorItem { menu.removeItem(last) }
    }
}
