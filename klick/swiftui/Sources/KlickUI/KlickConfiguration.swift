// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import KlickKit
import AppearanceKit

/// A backend that an application adds to CoreAudio (JACK, in the version of the collection): the backend itself and what the
/// window shows of it.
public struct BackendOffer {
    public var backend: AudioBackend
    public var interface: BackendInterface

    public init(backend: AudioBackend, interface: BackendInterface) {
        self.backend = backend
        self.interface = interface
    }
}

/// What makes one application of the family: its name, its colour, and the backends it adds to CoreAudio. The window, the pages and
/// the engine are the same for all.
public struct KlickConfiguration {
    /// The title of the window and the subtitle under it.
    public var title: String
    public var subtitle: String
    /// What the "About" panel says, and the page the help menu opens (see `CollectionMenus`).
    public var about: AboutInfo
    public var documentationTitle: String
    public var documentationURL: URL
    /// The colour of the application: one of the palette, or an own colour that stands for it.
    public var accent: AccentChoice
    public var accentColor: Color?
    /// CoreAudio is always offered, first; these come after it.
    public var additionalBackends: [BackendOffer]
    /// Whether the window offers the command line of `klick`. Only for the application that installs the program: Klick Tempo
    /// does not, so a command line would be of no use there.
    public var showsCommandLine: Bool

    public init(title: String, subtitle: String, about: AboutInfo, documentationTitle: String, documentationURL: URL,
                accent: AccentChoice, accentColor: Color? = nil, additionalBackends: [BackendOffer] = [], showsCommandLine: Bool = false) {
        self.about = about
        self.documentationTitle = documentationTitle
        self.documentationURL = documentationURL
        self.showsCommandLine = showsCommandLine
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.accentColor = accentColor
        self.additionalBackends = additionalBackends
    }
}
