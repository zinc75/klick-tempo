/*
 * CoreAudio backend for the klick engine (macOS).
 * Same role as AudioInterfaceJack: it calls the process callback of the metronome with a mono buffer
 * and mixes the clicks into it; the buffer is copied to every channel of the output device (the one of the system, or one
 * that is chosen).
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#ifndef KLICK_AUDIO_INTERFACE_COREAUDIO_HH
#define KLICK_AUDIO_INTERFACE_COREAUDIO_HH

#include "audio_interface.hh"

#include <AudioToolbox/AudioToolbox.h>

#include <atomic>
#include <functional>
#include <mutex>
#include <vector>


class AudioInterfaceCoreAudio
  : public AudioInterface
{
  public:

    // Opens the output device: 'device' (an AudioDeviceID), or, for 0, the output device of the system, which is followed
    // (see sync_with_system). Nothing plays until start().
    // 'rate' is the sample rate of the engine: CoreAudio converts it to the one of the device, so the sounds are
    // loaded once whatever the device does. 0 (or a rate the output unit refuses) means the rate of the device.
    explicit AudioInterfaceCoreAudio(nframes_t rate = 0, AudioDeviceID device = 0);
    virtual ~AudioInterfaceCoreAudio();

    void start();
    void stop();

    // Plays on 'device', or, for 0, on the output device of the system, followed from now on. Can be called while it plays: the
    // output is interrupted for a moment. If the device cannot be used the previous one stays and AudioError is thrown.
    void set_device(AudioDeviceID device);

    // When following the system: moves to its output device if it is not the one in use. Returns true if the output changed.
    // To be called now and then from the control thread (a notification would have to be handled on a thread of CoreAudio).
    bool sync_with_system();

    // The device in use now.
    AudioDeviceID current_device() const { return _current.load(); }

    virtual nframes_t samplerate() const { return _samplerate; }
    virtual bool is_shutdown() const { return false; }

    // Largest block the device may ask for; the real-time callback never allocates.
    nframes_t max_block() const { return static_cast<nframes_t>(_buffer.size()); }

    // Frames, at the rate of the engine, between the moment a block is handed to CoreAudio and the moment it is heard:
    // latency of the device in use and of its stream, safety offset and buffer. Asks the system, so not for the audio thread.
    nframes_t output_latency_frames() const;

    // Delivery diagnostics, filled by the audio thread since the last start(): jumps of the device sample clock
    // between two blocks (a dropout), and the largest gap between the host time of a block and the expected one.
    unsigned discontinuities() const { return _gaps.load(); }
    unsigned max_host_deviation_us() const { return _max_dev_us.load(); }

    // Optional tap on the mixed mono signal, called from the audio thread after mixing (levels, tests).
    typedef std::function<void (sample_t const *, nframes_t)> MonitorCallback;
    void set_monitor(MonitorCallback cb) { _monitor = cb; }

  private:

    static OSStatus render_(void *, AudioUnitRenderActionFlags *, AudioTimeStamp const *,
                            UInt32, UInt32, AudioBufferList *);

    static AudioDeviceID system_output_device();
    void apply_device(AudioDeviceID device);       // _control held

    AudioComponentInstance _unit;
    AudioStreamBasicDescription _format;
    std::mutex _control;                           // start, stop and the change of device; never taken by the audio thread
    bool _follow;
    std::atomic<AudioDeviceID> _current;
    nframes_t _samplerate;
    std::vector<sample_t> _buffer;
    MonitorCallback _monitor;
    bool _running;

    std::atomic<unsigned> _gaps;
    std::atomic<unsigned> _max_dev_us;
    double _expected_time;          // audio thread only
    UInt64 _last_host;              // audio thread only
    double _host_to_us;
};


#endif // KLICK_AUDIO_INTERFACE_COREAUDIO_HH
