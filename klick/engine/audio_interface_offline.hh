/*
 * Audio interface that renders only when asked: for tests, without any audio device.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#ifndef KLICK_AUDIO_INTERFACE_OFFLINE_HH
#define KLICK_AUDIO_INTERFACE_OFFLINE_HH

#include "audio_interface.hh"

#include <cstring>


class AudioInterfaceOffline
  : public AudioInterface
{
  public:

    explicit AudioInterfaceOffline(nframes_t rate) : _rate(rate) { }

    virtual nframes_t samplerate() const { return _rate; }
    virtual bool is_shutdown() const { return false; }

    // Same steps as the real backends: silence, process callback, mix of the clicks.
    void render(sample_t * out, nframes_t nframes)
    {
        std::memset(out, 0, nframes * sizeof(sample_t));
        if (_process_cb) {
            _process_cb(out, nframes);
        }
        process_mix(out, nframes);
    }

  private:

    nframes_t _rate;
};


#endif // KLICK_AUDIO_INTERFACE_OFFLINE_HH
