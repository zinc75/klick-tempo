/*
 * CoreAudio backend for the klick engine (macOS).
 * Same role as AudioInterfaceJack: it calls the process callback of the metronome with a mono buffer
 * and mixes the clicks into it; the buffer is copied to every channel of the default output device.
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
#include <vector>


class AudioInterfaceCoreAudio
  : public AudioInterface
{
  public:

    // Opens the default output device (it follows the system setting). Nothing plays until start().
    // 'rate' is the sample rate of the engine: CoreAudio converts it to the one of the device, so the sounds are
    // loaded once whatever the device does. 0 (or a rate the output unit refuses) means the rate of the device.
    explicit AudioInterfaceCoreAudio(nframes_t rate = 0);
    virtual ~AudioInterfaceCoreAudio();

    void start();
    void stop();

    virtual nframes_t samplerate() const { return _samplerate; }
    virtual bool is_shutdown() const { return false; }

    // Largest block the device may ask for; the real-time callback never allocates.
    nframes_t max_block() const { return static_cast<nframes_t>(_buffer.size()); }

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

    AudioComponentInstance _unit;
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
