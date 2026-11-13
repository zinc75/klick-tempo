// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import KlickEngine
import Observation

/// The output of the Mac through CoreAudio: the output device of the system, followed, or one that is chosen in the application.
@MainActor
@Observable
public final class CoreAudioBackend: AudioBackend {
    public let id = "coreaudio"
    public let name = "CoreAudio"
    public var availability: BackendAvailability { .available }

    /// The output devices the user can choose, read again by `refresh`.
    public private(set) var devices: [OutputDevice] = []
    /// The output chosen in the application is not there (unplugged): the output of the system plays meanwhile.
    public private(set) var isChosenOutputMissing = false

    @ObservationIgnored private var followsSystem = true

    public init() {}

    public func makeEngine() throws -> Engine {
        followsSystem = true   // a new engine plays on the output of the system
        return try Engine()
    }

    /// Puts the engine on the output that is wanted (the one chosen in the application when it is there, else the one of the system,
    /// followed), and reads what plays.
    public func refresh(player: Player, host: BackendHost) -> OutputInfo? {
        devices = OutputDevice.all()
        var wanted: UInt32 = 0
        isChosenOutputMissing = false
        if let uid = host.settings.outputDeviceUID {
            if let device = devices.first(where: { $0.uid == uid }) { wanted = device.id } else { isChosenOutputMissing = true }
        }
        do {
            if wanted != 0 {
                if player.outputDevice != wanted || followsSystem { try player.setOutputDevice(wanted) }
                followsSystem = false
            } else if !followsSystem {
                try player.setOutputDevice(0)
                followsSystem = true
            } else {
                try player.followSystemOutput()
            }
        } catch {
            // The device chosen cannot be used: the system's plays, and the choice is dropped.
            host.errorMessage = error.localizedDescription
            host.settings.outputDeviceUID = nil
            try? player.setOutputDevice(0)
            followsSystem = true
        }
        let playing = player.outputDevice
        return OutputInfo.current(device: playing == 0 ? nil : playing)
    }
}
