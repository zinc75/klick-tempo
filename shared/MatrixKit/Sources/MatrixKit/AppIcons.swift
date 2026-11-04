// SPDX-License-Identifier: MIT

import AppKit

/// The real icon of an application and its main colour, found from its bundle identifier and kept: the boxes that
/// JackMoebius makes for CoreAudio applications carry that identifier, and the matrix shows the icon in place of the
/// two-letter badge.
@MainActor
public enum AppIcons {
    private static var images: [String: NSImage?] = [:]
    private static var accents: [String: BadgeStyle.RGB?] = [:]

    /// nil when no installed application has this identifier.
    public static func icon(forBundleID id: String) -> NSImage? {
        if let cached = images[id] { return cached }
        let image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { NSWorkspace.shared.icon(forFile: $0.path) }
        images[id] = image
        return image
    }

    /// The main colour of the icon, brought into the range of the other accents; nil when the icon has none or is not found.
    public static func accent(forBundleID id: String) -> BadgeStyle.RGB? {
        if let cached = accents[id] { return cached }
        let rgb = icon(forBundleID: id)
            .flatMap { $0.cgImage(forProposedRect: nil, context: nil, hints: nil) }
            .flatMap { DominantColor.accent(of: $0) }
        accents[id] = rgb
        return rgb
    }
}
