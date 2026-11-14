// SPDX-License-Identifier: MIT

import AppKit

/// The real icon of an application and its main colour, found from its bundle identifier and kept: the boxes that
/// JackMoebius makes for CoreAudio applications carry that identifier, and the matrix shows the icon in place of the
/// two-letter badge.
@MainActor
public enum AppIcons {
    private static var images: [String: NSImage?] = [:]
    private static var accents: [String: BadgeStyle.RGB?] = [:]

    /// The picto of JackMoebius in colour (the one of JackMate for its system box, the shared input of the CoreAudio applications), as a
    /// badge; nil if the resource is missing.
    public static let jackMoebiusPicto: NSImage? = resourceBundle()?.url(forResource: "JackMoebiusPicto", withExtension: "png").flatMap { NSImage(contentsOf: $0) }

    private final class BundleToken {}

    /// The resource bundle of the package, in the Resources of the application (where its build script puts it), or next to the
    /// program of a run from the build folder, or beside a test bundle. `Bundle.module` is not used: it stops the program when the bundle is not found.
    private static func resourceBundle() -> Bundle? {
        let name = "MatrixKit_MatrixKit.bundle"
        // (The last one is the folder of a test bundle: swift test puts the resource bundle beside it.)
        let own = Bundle(for: BundleToken.self).bundleURL
        let folders = [Bundle.main.resourceURL, Bundle.main.bundleURL, own.deletingLastPathComponent(), own.appendingPathComponent("Contents/Resources")]
        for folder in folders {
            if let url = folder?.appendingPathComponent(name), let bundle = Bundle(url: url) { return bundle }
        }
        return nil
    }

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
