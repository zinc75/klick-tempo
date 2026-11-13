/*
 * C interface to the klick engine: see klick_engine.h.
 *
 * Threads: the control thread (the application) calls the klick_engine_* functions; the audio thread runs process().
 * Changes made while the metronome plays are staged under a mutex and applied by the audio thread, which only ever
 * try-locks it (it never waits). The beats go to the application through a single-producer, single-consumer ring.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#include "klick_engine.h"

#include "audio_interface_coreaudio.hh"
#include "audio_interface_offline.hh"
#include "audio_chunk.hh"
#include "metronome_simple.hh"
#include "metronome_map.hh"
#include "tempomap.hh"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>


namespace {

void set_error(char * buf, size_t size, std::string const & message)
{
    if (buf && size) {
        std::strncpy(buf, message.c_str(), size - 1);
        buf[size - 1] = '\0';
    }
}

std::size_t const RING_SIZE = 2048;     // beats; a power of two

}


struct KlickEngine
{
    std::unique_ptr<AudioInterfaceCoreAudio> coreaudio;
    std::unique_ptr<AudioInterfaceOffline> offline;
    AudioInterface * audio;

    std::unique_ptr<MetronomeSimple> simple;
    std::unique_ptr<MetronomeMap> map;
    TempoMapConstPtr tempomap;
    float multiplier;

    // sounds in use, and every sound ever loaded (kept so that the audio thread never frees one)
    AudioChunkConstPtr accent, normal;
    std::vector<AudioChunkConstPtr> retired;

    // changes staged by the control thread, applied by the audio thread
    struct Pending {
        bool simple_dirty;
        float tempo; int beats, denom; TempoMap::Pattern pattern; float t_start, t_increment, t_limit;
        bool sound_dirty;
    } pending;
    std::mutex pending_mutex;
    std::atomic<bool> pending_flag;

    std::atomic<int> mode;                  // 0 stopped, KLICK_MODE_*
    std::atomic<unsigned> callbacks;
    std::uint64_t frames;                   // audio thread only: frames rendered before the current block

    std::vector<KlickBeat> ring;
    std::atomic<std::uint64_t> head, tail, lost;

    KlickEngine()
      : audio(NULL), multiplier(1.0f), pending(), pending_flag(false), mode(0), callbacks(0), frames(0),
        ring(RING_SIZE), head(0), tail(0), lost(0)
    {
        pending.tempo = 120.0f; pending.beats = 4; pending.denom = 4;
        pending.t_start = pending.t_increment = pending.t_limit = 0.0f;
    }

    void push_beat(Metronome::BeatEvent const & e)
    {
        std::uint64_t h = head.load(std::memory_order_relaxed);
        if (h - tail.load(std::memory_order_acquire) >= RING_SIZE) {
            lost.fetch_add(1, std::memory_order_relaxed);
            return;
        }
        KlickBeat & b = ring[h % RING_SIZE];
        b.frame = frames + e.offset;
        b.section = e.entry; b.bar = e.bar; b.beat = e.beat; b.beats = e.beats; b.denom = e.denom;
        b.type = e.type == TempoMap::BEAT_EMPHASIS ? KLICK_BEAT_ACCENT : e.type == TempoMap::BEAT_NORMAL ? KLICK_BEAT_NORMAL : KLICK_BEAT_SILENT;
        b.tempo = e.tempo; b.volume = e.volume;
        head.store(h + 1, std::memory_order_release);
    }

    void apply_pending()
    {
        if (!pending_flag.load(std::memory_order_acquire)) return;
        std::unique_lock<std::mutex> lock(pending_mutex, std::try_to_lock);
        if (!lock.owns_lock()) return;      // try again at the next block
        if (pending.simple_dirty) {
            simple->set_tempo(pending.tempo);
            simple->set_meter(pending.beats, pending.denom);
            simple->set_pattern(pending.pattern);   // (copies a few bytes)
            simple->set_tempo_start(pending.t_start);
            simple->set_tempo_increment(pending.t_increment);
            simple->set_tempo_limit(pending.t_limit);
            pending.simple_dirty = false;
        }
        if (pending.sound_dirty) {
            simple->set_sound(accent, normal);
            if (map) map->set_sound(accent, normal);
            pending.sound_dirty = false;
        }
        pending_flag.store(false, std::memory_order_release);
    }

    void process(sample_t * buffer, nframes_t nframes)
    {
        apply_pending();
        switch (mode.load(std::memory_order_acquire)) {
          case KLICK_MODE_SIMPLE: simple->process_callback(buffer, nframes); break;
          case KLICK_MODE_MAP:    map->process_callback(buffer, nframes); break;
          default: break;
        }
        frames += nframes;
        callbacks.fetch_add(1, std::memory_order_release);
    }

    // Waits until the audio thread has gone through a few blocks without the metronome that is being stopped.
    void wait_for_audio()
    {
        if (!coreaudio) return;
        unsigned start = callbacks.load(std::memory_order_acquire);
        for (int i = 0; i < 100 && callbacks.load(std::memory_order_acquire) - start < 3; ++i) {
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }
    }

    void stop()
    {
        mode.store(0, std::memory_order_release);
        wait_for_audio();
        simple->stop();
        if (map) { map->stop(); map.reset(); }
    }
};


extern "C" {

KlickEngine * klick_engine_create(int offline, uint32_t offline_rate, char * error, size_t error_size)
{
    try {
        std::unique_ptr<KlickEngine> e(new KlickEngine);
        if (offline) {
            e->offline.reset(new AudioInterfaceOffline(offline_rate ? offline_rate : 48000));
            e->audio = e->offline.get();
        } else {
            e->coreaudio.reset(new AudioInterfaceCoreAudio);
            e->audio = e->coreaudio.get();
        }
        e->simple.reset(new MetronomeSimple(*e->audio));
        KlickEngine * raw = e.get();
        e->simple->set_beat_callback([raw](Metronome::BeatEvent const & b) { raw->push_beat(b); });

        // Silent sounds until the application loads some: a metronome without a sound must not crash.
        e->accent.reset(new AudioChunk(e->audio->samplerate()));
        e->normal.reset(new AudioChunk(e->audio->samplerate()));
        e->retired.push_back(e->accent); e->retired.push_back(e->normal);
        e->simple->set_sound(e->accent, e->normal);

        e->audio->set_process_callback([raw](sample_t * buffer, nframes_t n) { raw->process(buffer, n); });
        if (e->coreaudio) e->coreaudio->start();    // the device stays open, silent until a metronome starts
        return e.release();
    } catch (std::exception const & ex) {
        set_error(error, error_size, ex.what());
        return NULL;
    }
}


void klick_engine_destroy(KlickEngine * e)
{
    if (!e) return;
    e->stop();
    if (e->coreaudio) e->coreaudio->stop();
    delete e;
}


uint32_t klick_engine_samplerate(KlickEngine const * e) { return e->audio->samplerate(); }


int klick_engine_load_sound(KlickEngine * e, char const * accent_path, char const * normal_path,
                            float accent_volume, float normal_volume, float accent_pitch, float normal_pitch,
                            char * error, size_t error_size)
{
    try {
        auto load = [&](char const * path, float volume, float pitch) -> AudioChunkConstPtr {
            std::shared_ptr<AudioChunk> c;
            if (path && *path) c.reset(new AudioChunk(path, e->audio->samplerate()));
            else c.reset(new AudioChunk(e->audio->samplerate()));
            if (c->length() > 0) {
                if (volume != 1.0f) c->adjust_volume(volume);
                if (pitch != 1.0f) c->adjust_pitch(pitch);
            }
            return c;
        };
        AudioChunkConstPtr a = load(accent_path, accent_volume, accent_pitch);
        AudioChunkConstPtr n = load(normal_path, normal_volume, normal_pitch);
        std::lock_guard<std::mutex> lock(e->pending_mutex);
        e->retired.push_back(a); e->retired.push_back(n);
        e->accent = a; e->normal = n;
        e->pending.sound_dirty = true;
        e->pending_flag.store(true, std::memory_order_release);
        return 1;
    } catch (std::exception const & ex) {
        set_error(error, error_size, ex.what());
        return 0;
    }
}


void klick_engine_set_volume(KlickEngine * e, float volume) { e->audio->set_volume(volume); }


int klick_engine_set_simple(KlickEngine * e, float tempo, int32_t beats, int32_t denom, char const * pattern,
                            float tempo_start, float tempo_increment, float tempo_limit, char * error, size_t error_size)
{
    try {
        if (!(tempo >= 10.0f && tempo <= 1000.0f)) throw std::runtime_error("tempo out of range (10 to 1000)");
        if (beats < 1 || denom < 1) throw std::runtime_error("invalid meter");
        TempoMap::Pattern p;
        if (pattern && *pattern) p = TempoMap::parse_pattern(pattern, beats);
        std::lock_guard<std::mutex> lock(e->pending_mutex);
        e->pending.tempo = tempo; e->pending.beats = beats; e->pending.denom = denom; e->pending.pattern = p;
        e->pending.t_start = tempo_start; e->pending.t_increment = tempo_increment; e->pending.t_limit = tempo_limit;
        e->pending.simple_dirty = true;
        e->pending_flag.store(true, std::memory_order_release);
        if (e->offline) { /* no audio thread: applied by the next render */ }
        return 1;
    } catch (std::exception const & ex) {
        set_error(error, error_size, ex.what());
        return 0;
    }
}


int klick_engine_set_map(KlickEngine * e, KlickSection const * sections, size_t count, float multiplier,
                         char * error, size_t error_size)
{
    try {
        if (!sections || count == 0) throw std::runtime_error("empty tempo map");
        if (!(multiplier > 0.0f)) throw std::runtime_error("invalid tempo multiplier");
        auto map = std::make_shared<TempoMap>();
        for (size_t i = 0; i < count; ++i) {
            KlickSection const & s = sections[i];
            std::string where = "section " + std::to_string(i + 1) + ": ";
            if (s.bars == 0 || s.bars < -1 || (s.bars == -1 && i + 1 != count)) throw std::runtime_error(where + "invalid number of bars");
            if (s.beats < 1 || s.denom < 1) throw std::runtime_error(where + "invalid meter");
            if (!(s.tempo >= 10.0f && s.tempo <= 1000.0f) || (s.tempo_end != 0.0f && !(s.tempo_end >= 10.0f && s.tempo_end <= 1000.0f)))
                throw std::runtime_error(where + "tempo out of range (10 to 1000)");
            if (s.tempo_end != 0.0f && s.bars < 1) throw std::runtime_error(where + "a tempo change needs a number of bars");
            TempoMap::Entry en;
            en.label = s.label ? s.label : "";
            en.bars = s.bars; en.tempo = s.tempo; en.tempo2 = s.tempo_end; en.beats = s.beats; en.denom = s.denom;
            if (s.pattern && *s.pattern) en.pattern = TempoMap::parse_pattern(s.pattern, s.beats);
            en.volume = s.volume;
            map->add(en);
        }
        e->tempomap = map;
        e->multiplier = multiplier;
        return 1;
    } catch (std::exception const & ex) {
        set_error(error, error_size, ex.what());
        return 0;
    }
}


int klick_engine_start(KlickEngine * e, KlickMode mode, char * error, size_t error_size)
{
    try {
        e->stop();
        if (e->offline) e->apply_pending();
        else {   // let the audio thread take the staged changes first
            for (int i = 0; i < 50 && e->pending_flag.load(std::memory_order_acquire); ++i) std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }
        KlickEngine * raw = e;
        if (mode == KLICK_MODE_SIMPLE) {
            e->simple->start();
            e->mode.store(KLICK_MODE_SIMPLE, std::memory_order_release);
        } else if (mode == KLICK_MODE_MAP) {
            if (!e->tempomap) throw std::runtime_error("no tempo map");
            e->map.reset(new MetronomeMap(*e->audio, e->tempomap, e->multiplier, false, -1, ""));
            e->map->set_sound(e->accent, e->normal);
            e->map->set_beat_callback([raw](Metronome::BeatEvent const & b) { raw->push_beat(b); });
            e->map->start();
            e->mode.store(KLICK_MODE_MAP, std::memory_order_release);
        } else {
            throw std::runtime_error("unknown mode");
        }
        return 1;
    } catch (std::exception const & ex) {
        set_error(error, error_size, ex.what());
        return 0;
    }
}


void klick_engine_stop(KlickEngine * e) { e->stop(); }


int klick_engine_is_playing(KlickEngine const * e)
{
    switch (e->mode.load(std::memory_order_acquire)) {
      case KLICK_MODE_SIMPLE: return 1;
      case KLICK_MODE_MAP:    return e->map && e->map->running() ? 1 : 0;
      default:                return 0;
    }
}


size_t klick_engine_poll_beats(KlickEngine * e, KlickBeat * out, size_t max)
{
    std::uint64_t t = e->tail.load(std::memory_order_relaxed);
    std::uint64_t h = e->head.load(std::memory_order_acquire);
    size_t n = 0;
    while (t != h && n < max) out[n++] = e->ring[t++ % RING_SIZE];
    e->tail.store(t, std::memory_order_release);
    return n;
}


uint64_t klick_engine_lost_beats(KlickEngine const * e) { return e->lost.load(std::memory_order_relaxed); }


void klick_engine_render(KlickEngine * e, float * out, uint32_t frames)
{
    if (e->offline) e->offline->render(out, frames);
}


uint32_t klick_engine_dropouts(KlickEngine const * e) { return e->coreaudio ? e->coreaudio->discontinuities() : 0; }
uint32_t klick_engine_max_lateness_us(KlickEngine const * e) { return e->coreaudio ? e->coreaudio->max_host_deviation_us() : 0; }

}
