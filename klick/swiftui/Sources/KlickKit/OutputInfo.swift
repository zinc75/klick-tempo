// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).
import Foundation
import CoreAudio

/// The output device of the system, as the page "Sortie" shows it: the one klick plays on (it follows the choice of the system).
public struct OutputInfo: Equatable, Sendable {
    public var name = "default"
    public var sampleRate = 0.0
    /// Frames the device holds before the sound comes out: its latency, its safety offset, its buffer and its stream's latency.
    public var latencyFrames = 0
    public var bufferFrames = 0
    public var isBluetooth = false

    public init() {}

    /// What the system announces, in milliseconds.
    public var latencyMilliseconds: Double { sampleRate > 0 ? Double(latencyFrames) * 1000 / sampleRate : 0 }

    /// The output device `id` (an AudioDeviceID), or, for `nil`, the default output device now; `nil` when there is none.
    public static func current(device id: UInt32? = nil) -> OutputInfo? {
        var device = AudioObjectID(id ?? UInt32(kAudioObjectUnknown))
        if id == nil || id == 0 {
            var system = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                    mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var size = UInt32(MemoryLayout<AudioObjectID>.size)
            guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &system, 0, nil, &size, &device) == noErr,
                  device != kAudioObjectUnknown else { return nil }
        }

        func number<T: Numeric & BitwiseCopyable>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope, as: T.Type) -> T? {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
            var value: T = 0
            var n = UInt32(MemoryLayout<T>.size)
            return AudioObjectGetPropertyData(object, &address, 0, nil, &n, &value) == noErr ? value : nil
        }

        var info = OutputInfo()
        var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: kAudioObjectPropertyElementMain)
        var cfName: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        if AudioObjectGetPropertyData(device, &nameAddress, 0, nil, &nameSize, &cfName) == noErr, let cfName {
            info.name = cfName.takeRetainedValue() as String
        }
        info.sampleRate = number(device, kAudioDevicePropertyNominalSampleRate, scope: kAudioObjectPropertyScopeGlobal, as: Float64.self) ?? 0
        info.bufferFrames = Int(number(device, kAudioDevicePropertyBufferFrameSize, scope: kAudioObjectPropertyScopeGlobal, as: UInt32.self) ?? 0)
        var frames = Int(number(device, kAudioDevicePropertyLatency, scope: kAudioDevicePropertyScopeOutput, as: UInt32.self) ?? 0)
        frames += Int(number(device, kAudioDevicePropertySafetyOffset, scope: kAudioDevicePropertyScopeOutput, as: UInt32.self) ?? 0)
        frames += info.bufferFrames
        var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var stream = AudioStreamID(kAudioObjectUnknown)
        var streamSize = UInt32(MemoryLayout<AudioStreamID>.size)
        if AudioObjectGetPropertyData(device, &streams, 0, nil, &streamSize, &stream) == noErr, stream != kAudioObjectUnknown {
            frames += Int(number(stream, kAudioStreamPropertyLatency, scope: kAudioObjectPropertyScopeGlobal, as: UInt32.self) ?? 0)
        }
        info.latencyFrames = frames
        let transport = number(device, kAudioDevicePropertyTransportType, scope: kAudioObjectPropertyScopeGlobal, as: UInt32.self) ?? 0
        info.isBluetooth = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        return info
    }
}

/// An output device of the system that the user can choose.
public struct OutputDevice: Identifiable, Equatable, Sendable {
    /// The AudioDeviceID (changes when the device is unplugged and plugged again).
    public let id: UInt32
    /// The stable identifier, what is kept in the settings.
    public let uid: String
    public let name: String

    /// The devices that have outputs, in the order of the system.
    public static func all() -> [OutputDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { device(id: $0) }
    }

    private static func device(id: AudioObjectID) -> OutputDevice? {
        var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &size) == noErr, size > 0 else { return nil }   // no output
        func string(_ selector: AudioObjectPropertySelector) -> String? {
            var a = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var value: Unmanaged<CFString>?
            var n = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &a, 0, nil, &n, &value) == noErr, let value else { return nil }
            return value.takeRetainedValue() as String
        }
        guard let uid = string(kAudioDevicePropertyDeviceUID), let name = string(kAudioObjectPropertyName) else { return nil }
        return OutputDevice(id: id, uid: uid, name: name)
    }
}
