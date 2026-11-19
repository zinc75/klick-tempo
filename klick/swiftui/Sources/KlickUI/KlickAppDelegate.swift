// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import AppearanceKit

/// Makes the application a regular one when it is run from the build folder; applies the look the user chose. The menus are cleaned
/// by `MenuPruner`.
public final class KlickAppDelegate: NSObject, NSApplicationDelegate {
    /// The look chosen by the user; given by the application before the first window, applied at launch.
    static var appearance: AppearanceSettings?

    public override init() { super.init() }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run from the build folder, without a bundle, the application is not a regular one: make it so, and active.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Self.appearance?.applyAppearance()
    }
}
