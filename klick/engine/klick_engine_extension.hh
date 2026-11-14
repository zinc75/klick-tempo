/*
 * Extension point of the klick engine (C++): what an add-on that drives the metronome from outside uses, for instance a backend that
 * starts and stops what plays with a signal of its own. The engine knows nothing of what the extension does: it asks it, once per block,
 * before the audio is made, and lets it start and stop the simple metronome, read what plays and follow its beats.
 *
 * Threads: gates_start() and the on_* functions run on the control thread (the application), attached() too; before_block() and
 * on_simple_beat() run on the audio thread (no allocation, no lock, no I/O).
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#ifndef KLICK_ENGINE_EXTENSION_HH
#define KLICK_ENGINE_EXTENSION_HH

#include "klick_engine.h"
#include "audio_interface.hh"
#include "metronome_simple.hh"
#include "metronome_map.hh"

#include <cstdint>

/// What the engine lets an extension do and see. Implemented by the engine.
class KlickEngineControl
{
  public:
    virtual ~KlickEngineControl() { }

    virtual AudioInterface & audio() = 0;
    virtual MetronomeSimple & simple() = 0;
    /// The tempo map that plays, or NULL.
    virtual MetronomeMap * map() = 0;
    /// 0 when nothing plays, else KLICK_MODE_SIMPLE or KLICK_MODE_MAP.
    virtual int mode() const = 0;
    /// Frames rendered before the current block (audio thread).
    virtual std::uint64_t frames() const = 0;
    /// While true, the simple metronome makes no click (it waits for the extension to start it). Audio thread.
    virtual void set_simple_waiting(bool waiting) = 0;
    /// Puts back the tempo, meter and pattern of the settings in the simple metronome. False when the settings are being changed
    /// at that moment (try again at the next block). Audio thread.
    virtual bool reapply_settings() = 0;
};

class KlickEngineExtension
{
  public:
    virtual ~KlickEngineExtension() { }

    /// Called once, when the engine takes the extension.
    virtual void attached(KlickEngineControl &) { }
    /// True when what starts waits for the extension: the metronome and the map are armed by the start, and play when the extension
    /// says so (there is no count-in then). Read at each start.
    virtual bool gates_start() const = 0;
    /// A start (after gates_start() was read, before anything plays), and a stop.
    virtual void on_start(KlickEngineControl &, int /* KlickMode */) { }
    virtual void on_stop(KlickEngineControl &) { }
    /// Before each block, while something plays and after the staged changes were applied: may start and stop the simple metronome.
    virtual void before_block(KlickEngineControl &, nframes_t) { }
    /// The simple metronome has scheduled a beat.
    virtual void on_simple_beat(KlickEngineControl &, Metronome::BeatEvent const &) { }
};

/// Gives the engine an extension, which it owns from then on (destroyed before the backend). Control thread, before anything plays.
void klick_engine_set_extension(KlickEngine * e, KlickEngineExtension * extension);
KlickEngineExtension * klick_engine_extension(KlickEngine const * e);

#endif // KLICK_ENGINE_EXTENSION_HH
