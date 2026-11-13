// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import KlickEngine

/// Whether a backend can be used now.
public enum BackendAvailability: Equatable, Sendable {
    case available
    /// Why not, as the user reads it (the one that provides the backend translates it).
    case unavailable(String)
}

/// What a backend may ask of the application that hosts it: the settings it reads and writes, and a way to show a failure.
@MainActor
public protocol BackendHost: AnyObject {
    var settings: ClickSettings { get set }
    var errorMessage: String? { get set }
}

/// Where the sound goes: CoreAudio, JACK, ... The engine of klick runs on one of them; the application knows them only through
/// this protocol, so that a backend can come from another library (JACK, in the version of the collection).
@MainActor
public protocol AudioBackend: AnyObject {
    /// What is kept in the settings: "coreaudio", "jack".
    var id: String { get }
    /// The name shown to the user (a proper name, not translated).
    var name: String { get }
    var availability: BackendAvailability { get }
    /// A new engine on this backend.
    func makeEngine() throws -> Engine
    /// Called now and then (and when the output page opens): brings the engine to the output the user wants and reads what plays.
    /// Returns what the output says about itself, `nil` when it cannot be read.
    func refresh(player: Player, host: BackendHost) -> OutputInfo?
    /// The key of the delay of the display (kept per output): the name of the output unless the backend says otherwise.
    func displayOffsetKey(for info: OutputInfo) -> String
}

public extension AudioBackend {
    func displayOffsetKey(for info: OutputInfo) -> String { info.name }
}

/// An engine that renders only when asked, as a backend: for tests, and for trying the choice of the backend without a second
/// one. It has no output device.
@MainActor
public final class OfflineBackend: AudioBackend {
    public let id = "offline"
    public let name = "Offline (test)"
    public var availability: BackendAvailability { .available }

    public init() {}

    public func makeEngine() throws -> Engine { try Engine(offline: true, rate: 48000) }

    public func refresh(player: Player, host: BackendHost) -> OutputInfo? {
        var info = OutputInfo()
        info.name = "offline"
        info.sampleRate = Double(player.sampleRate)
        return info
    }
}
