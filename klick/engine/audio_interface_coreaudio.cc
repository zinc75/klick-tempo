/*
 * CoreAudio backend for the klick engine (macOS). See audio_interface_coreaudio.hh.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#include "audio_interface_coreaudio.hh"

#include <mach/mach_time.h>

#include <algorithm>
#include <cmath>
#include <cstring>


static void check(OSStatus err, char const * what)
{
    if (err != noErr) {
        throw AudioInterface::AudioError(std::string("CoreAudio: ") + what + " failed (" + std::to_string(static_cast<int>(err)) + ")");
    }
}


AudioInterfaceCoreAudio::AudioInterfaceCoreAudio(nframes_t rate)
  : _unit(NULL)
  , _samplerate(0)
  , _running(false)
  , _gaps(0)
  , _max_dev_us(0)
  , _expected_time(-1.0)
  , _last_host(0)
  , _host_to_us(1.0)
{
    mach_timebase_info_data_t tb;
    mach_timebase_info(&tb);
    _host_to_us = static_cast<double>(tb.numer) / tb.denom / 1000.0;

    AudioComponentDescription desc = {};
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_DefaultOutput;   // follows the system output device
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp) throw AudioError("CoreAudio: no default output unit");
    check(AudioComponentInstanceNew(comp, &_unit), "AudioComponentInstanceNew");

    AudioStreamBasicDescription dev = {};
    UInt32 size = sizeof(dev);
    check(AudioUnitGetProperty(_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &dev, &size), "get device format");

    // What we feed: 32-bit float, two channels, one buffer per channel. At the rate asked for, CoreAudio converting it to
    // the device (the sounds are then loaded once whatever the device does); if the unit refuses, at the rate of the device.
    AudioStreamBasicDescription fmt = {};
    fmt.mFormatID = kAudioFormatLinearPCM;
    fmt.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    fmt.mChannelsPerFrame = 2;
    fmt.mBitsPerChannel = 32;
    fmt.mBytesPerFrame = 4;
    fmt.mFramesPerPacket = 1;
    fmt.mBytesPerPacket = 4;
    fmt.mSampleRate = rate ? rate : dev.mSampleRate;
    if (AudioUnitSetProperty(_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fmt, sizeof(fmt)) != noErr) {
        fmt.mSampleRate = dev.mSampleRate;
        check(AudioUnitSetProperty(_unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &fmt, sizeof(fmt)), "set stream format");
    }
    _samplerate = static_cast<nframes_t>(fmt.mSampleRate);

    // Allocate once, here: the render callback must not allocate.
    UInt32 max_frames = 0;
    size = sizeof(max_frames);
    check(AudioUnitGetProperty(_unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &max_frames, &size), "get max frames");
    max_frames = std::max<UInt32>(max_frames, 4096);
    check(AudioUnitSetProperty(_unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &max_frames, sizeof(max_frames)), "set max frames");
    _buffer.assign(max_frames, 0.0f);

    AURenderCallbackStruct cb = { &AudioInterfaceCoreAudio::render_, this };
    check(AudioUnitSetProperty(_unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &cb, sizeof(cb)), "set render callback");
    check(AudioUnitInitialize(_unit), "AudioUnitInitialize");
}


AudioInterfaceCoreAudio::~AudioInterfaceCoreAudio()
{
    if (_unit) {
        stop();
        AudioUnitUninitialize(_unit);
        AudioComponentInstanceDispose(_unit);
    }
}


void AudioInterfaceCoreAudio::start()
{
    if (!_running) {
        _gaps = 0; _max_dev_us = 0; _expected_time = -1.0; _last_host = 0;
        check(AudioOutputUnitStart(_unit), "AudioOutputUnitStart");
        _running = true;
    }
}


void AudioInterfaceCoreAudio::stop()
{
    if (_running) {
        AudioOutputUnitStop(_unit);
        _running = false;
    }
}


OSStatus AudioInterfaceCoreAudio::render_(void * ref, AudioUnitRenderActionFlags *, AudioTimeStamp const * ts,
                                          UInt32, UInt32 nframes, AudioBufferList * data)
{
    AudioInterfaceCoreAudio * this_ = static_cast<AudioInterfaceCoreAudio *>(ref);
    sample_t * mono = this_->_buffer.data();

    // Delivery diagnostics (no allocation, no lock).
    if (ts) {
        if (ts->mFlags & kAudioTimeStampSampleTimeValid) {
            if (this_->_expected_time >= 0.0 && ts->mSampleTime != this_->_expected_time) ++this_->_gaps;
            this_->_expected_time = ts->mSampleTime + nframes;
        }
        if (ts->mFlags & kAudioTimeStampHostTimeValid) {
            if (this_->_last_host) {
                double dt = (ts->mHostTime - this_->_last_host) * this_->_host_to_us;
                double expected = nframes * 1.0e6 / this_->_samplerate;
                unsigned dev = static_cast<unsigned>(std::fabs(dt - expected));
                if (dev > this_->_max_dev_us.load(std::memory_order_relaxed)) this_->_max_dev_us.store(dev, std::memory_order_relaxed);
            }
            this_->_last_host = ts->mHostTime;
        }
    }

    if (nframes > this_->_buffer.size()) {
        // Cannot happen after the maximum was raised; stay silent rather than overrun.
        for (UInt32 i = 0; i < data->mNumberBuffers; ++i) std::memset(data->mBuffers[i].mData, 0, data->mBuffers[i].mDataByteSize);
        return noErr;
    }

    std::memset(mono, 0, nframes * sizeof(sample_t));
    if (this_->_process_cb) {
        this_->_process_cb(mono, nframes);
    }
    this_->process_mix(mono, nframes);
    if (this_->_monitor) {
        this_->_monitor(mono, nframes);
    }

    for (UInt32 i = 0; i < data->mNumberBuffers; ++i) {
        std::memcpy(data->mBuffers[i].mData, mono, nframes * sizeof(sample_t));
    }
    return noErr;
}
