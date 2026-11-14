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
#include <cmath>
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
    KlickBackend backend;       // owned from klick_engine_create_with_backend on
    AudioInterface * audio;     // the AudioInterface of the backend

    // The backends of this file are known by their id; the functions below are theirs, a no-op for any other.
    AudioInterfaceCoreAudio * coreaudio() const
    {
        return backend.id && !std::strcmp(backend.id, "coreaudio") ? static_cast<AudioInterfaceCoreAudio *>(audio) : NULL;
    }
    AudioInterfaceOffline * offline() const
    {
        return backend.id && !std::strcmp(backend.id, "offline") ? static_cast<AudioInterfaceOffline *>(audio) : NULL;
    }

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

    // count-in: set by the control thread, used at start
    int countin_bars, countin_beats_per_bar; float countin_volume;
    std::unique_ptr<MetronomeMap> countin;  // simple mode: the count-in is a small tempo map played beside the metronome
    bool joined;                            // map mode: the count-in is the first section of the map that plays
    bool transport_follow;                  // follow the transport of the backend (JACK): the metronome and the map play while it rolls
    AudioInterfaceTransport * transport;    // the transport of the backend, when it has one
    std::atomic<bool> timebase_on;          // the application asked to be the timebase master
    bool follow_active;                     // set at start (before the mode): the simple metronome is gated by the transport
    bool simple_runs;                       // audio thread: the simple metronome plays (always, unless it waits for the transport)
    bool was_rolling;                       // audio thread: the transport state at the previous block
    bool external_was;                      // audio thread: the tempo came from another timebase master at the previous block
    bool restore_wanted;                    // audio thread: put back the tempo and meter of the settings
    std::uint64_t synced_for;               // audio thread: block (frames + 1) the transport was last looked at
    std::uint64_t cb_frames;                // audio thread: block (frames + 1) our timebase callback ran for
    nframes_t last_pos_frame, last_block;   // audio thread: position of the transport at the previous block, and its size
    std::atomic<int> sync_state;            // for the application: 0 not following, 1 waiting for the transport, 2 rolling
    std::atomic<int> ext_present, ext_beats, ext_denom;
    std::atomic<float> ext_tempo;           // the timebase master is another client: its tempo (quarter notes per minute) and meter
    // BBT of the simple metronome, for the timebase callback (audio thread)
    bool lb_valid; int lb_bar, lb_beat, lb_beats, lb_denom; float lb_tempo; std::uint64_t lb_frame; std::int64_t tb_bar_start, tb_next_bar_start;
    int countin_total, countin_index;       // beats of the count-in, and how many were reported (audio thread)
    std::atomic<bool> countin_active;
    std::int64_t countin_frames_left;       // audio thread only

    std::atomic<int> mode;                  // 0 stopped, KLICK_MODE_*
    std::atomic<unsigned> callbacks;
    std::uint64_t frames;                   // audio thread only: frames rendered before the current block
    std::atomic<std::uint64_t> position;    // the same, after each block, for the control thread

    std::vector<KlickBeat> ring;
    std::atomic<std::uint64_t> head, tail, lost;

    KlickEngine()
      : backend(), audio(NULL), multiplier(1.0f), pending(), pending_flag(false),
        countin_bars(0), countin_beats_per_bar(4), countin_volume(0.0f), joined(false), transport_follow(false), transport(NULL), timebase_on(false), follow_active(false), simple_runs(true), was_rolling(false),
        external_was(false), restore_wanted(false), synced_for(0), cb_frames(0), last_pos_frame(0), last_block(0), sync_state(0), ext_present(0),
        ext_beats(4), ext_denom(4), ext_tempo(0.0f), lb_valid(false), lb_bar(0), lb_beat(0), lb_beats(4), lb_denom(4), lb_tempo(120.0f), lb_frame(0),
        tb_bar_start(0), tb_next_bar_start(0), countin_total(0), countin_index(0),
        countin_active(false), countin_frames_left(0), mode(0), callbacks(0), frames(0), position(0),
        ring(RING_SIZE), head(0), tail(0), lost(0)
    {
        pending.tempo = 120.0f; pending.beats = 4; pending.denom = 4;
        pending.t_start = pending.t_increment = pending.t_limit = 0.0f;
    }

    // The metronomes hold a reference to the audio interface: they go first, the backend last.
    ~KlickEngine()
    {
        countin.reset(); map.reset(); simple.reset();
        if (backend.audio && backend.destroy) backend.destroy(backend.audio);
    }

    void push_beat(Metronome::BeatEvent const & e, bool from_countin_metronome)
    {
        std::uint64_t h = head.load(std::memory_order_relaxed);
        if (h - tail.load(std::memory_order_acquire) >= RING_SIZE) {
            lost.fetch_add(1, std::memory_order_relaxed);
            return;
        }
        KlickBeat & b = ring[h % RING_SIZE];
        b.frame = frames + e.offset;
        bool in_countin = from_countin_metronome || (joined && e.entry == 0);
        b.count_in = in_countin ? 1 : 0;
        b.count_in_left = in_countin ? countin_total - countin_index++ : 0;
        b.section = in_countin ? 0 : e.entry - (joined ? 1 : 0); b.bar = e.bar; b.beat = e.beat; b.beats = e.beats; b.denom = e.denom;
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
          case KLICK_MODE_SIMPLE:
            if (follow_active) {
                sync_transport(false);
                if (!simple_runs) break;
            }
            if (countin_active.load(std::memory_order_acquire)) {
                countin->process_callback(buffer, nframes);
                if (countin_frames_left <= static_cast<std::int64_t>(nframes)) countin_active.store(false, std::memory_order_release);
                else countin_frames_left -= nframes;
            }
            simple->process_callback(buffer, nframes);
            break;
          case KLICK_MODE_MAP:
            if (follow_active) sync_transport(false);
            map->process_callback(buffer, nframes);
            break;
          default: break;
        }
        last_block = nframes;
        frames += nframes;
        position.store(frames, std::memory_order_release);
        callbacks.fetch_add(1, std::memory_order_release);
    }


    static constexpr double TPB = 1920.0;   // ticks per beat published to the transport (as klick does)

    // The tempo and the meter of the settings, put back when the tempo of another timebase master no longer applies.
    void restore_settings()
    {
        std::unique_lock<std::mutex> lock(pending_mutex, std::try_to_lock);
        if (!lock.owns_lock()) return;      // next block
        simple->set_tempo(pending.tempo);
        simple->set_meter(pending.beats, pending.denom);
        simple->set_pattern(pending.pattern);
        restore_wanted = false;
    }

    // Starts the simple metronome again with the transport that has just started or moved. Another client that is the timebase master
    // gives the position in bars and beats: the first click is the next beat of the song, not a first beat. Audio thread.
    void restart_simple(bool external, position_t const & p)
    {
        simple->stop();
        simple->set_start_delay(0);
        simple->set_start_position(0, 0);
        if (external) {
            double beat_frames = audio->samplerate() * 60.0 / p.beats_per_minute;   // (the beat of the master's meter)
            double done = p.tick / TPB;
            int bar = static_cast<int>(p.bar) - 1, beat = static_cast<int>(p.beat) - 1;
            nframes_t delay = 0;
            if (done > 0.0) {   // in the middle of a beat: the next one is the first click
                delay = static_cast<nframes_t>((1.0 - done) * beat_frames);
                if (++beat >= static_cast<int>(p.beats_per_bar)) { beat = 0; ++bar; }
            }
            simple->set_start_delay(delay);
            simple->set_start_position(std::max(bar, 0), std::max(beat, 0));
        }
        tb_bar_start = 0; tb_next_bar_start = 0; lb_valid = false;
        simple->start();
        simple_runs = true;
    }

    // Looks at the transport once per block: the simple metronome starts and stops with it, and takes the tempo and the meter of
    // another timebase master. `mine`: called by our own timebase callback (we are the master, nobody else gives a tempo). Audio thread.
    void sync_transport(bool mine)
    {
        if (!transport || synced_for == frames + 1) return;
        synced_for = frames + 1;
        int m = mode.load(std::memory_order_acquire);
        bool rolling = transport->transport_rolling();
        position_t p = position_t();
        bool external = false;
        if (cb_frames == frames + 1) mine = true;   // our callback has run for this block (a tempo map answers it without going through here)
        if (!mine && (!timebase_on.load(std::memory_order_relaxed) || rolling)) {
            // (a master that is us would have been called before this block: if it was not, another one has taken the place)
            p = transport->position();
            external = (p.valid & JackPositionBBT) && p.beats_per_minute > 0.0 && p.beat_type > 0.0f && p.beats_per_bar > 0.0f;
        }
        float tempo = external ? static_cast<float>(p.beats_per_minute * 4.0 / p.beat_type) : 0.0f;
        ext_present.store(external ? 1 : 0, std::memory_order_relaxed);
        if (external) {
            ext_tempo.store(tempo, std::memory_order_relaxed);
            ext_beats.store(static_cast<int>(p.beats_per_bar), std::memory_order_relaxed);
            ext_denom.store(static_cast<int>(p.beat_type), std::memory_order_relaxed);
        }
        if (m == KLICK_MODE_MAP) {   // the map has the position of the transport; the tempo is its own
            sync_state.store(rolling ? 2 : 1, std::memory_order_relaxed);
            return;
        }
        if (m != KLICK_MODE_SIMPLE) return;

        if (external) {
            if (std::fabs(tempo - simple->tempo()) > 0.001f) simple->set_tempo(tempo);
            int beats = static_cast<int>(p.beats_per_bar), denom = static_cast<int>(p.beat_type);
            if (beats != simple->beats() || denom != simple->denom()) simple->set_meter(beats, denom);
            external_was = true;
        } else if (external_was) {
            external_was = false;
            restore_wanted = true;
        }
        if (restore_wanted) restore_settings();

        bool moved = external && rolling && was_rolling && p.frame != last_pos_frame + last_block;   // relocated while rolling
        if (rolling && (!was_rolling || moved)) {
            restart_simple(external, p);
            sync_state.store(2, std::memory_order_relaxed);
        } else if (!rolling && was_rolling) {
            simple->stop();
            simple_runs = false;
            sync_state.store(1, std::memory_order_relaxed);
        }
        was_rolling = rolling;
        last_pos_frame = p.frame;
    }

    // The beat the simple metronome has just scheduled, for the timebase callback. Audio thread.
    void note_simple_beat(Metronome::BeatEvent const & b)
    {
        lb_valid = true; lb_bar = b.bar; lb_beat = b.beat; lb_beats = b.beats; lb_denom = b.denom; lb_tempo = b.tempo; lb_frame = frames + b.offset;
        if (b.beat == 0) {
            tb_bar_start = tb_next_bar_start;
            tb_next_bar_start += static_cast<std::int64_t>(b.beats * TPB);
        }
    }

    // Our timebase callback: the bars and beats of what plays, for the other clients. Audio thread, called before the block is processed.
    void timebase(position_t * p)
    {
        cb_frames = frames + 1;
        int m = mode.load(std::memory_order_acquire);
        if (m == KLICK_MODE_MAP && map) { map->timebase_callback(p); return; }
        if (m == KLICK_MODE_SIMPLE && follow_active) sync_transport(true);
        p->valid = JackPositionBBT;
        p->ticks_per_beat = TPB;
        if (m == KLICK_MODE_SIMPLE && simple_runs && lb_valid && lb_tempo > 0.0f && lb_denom > 0) {
            double d = audio->samplerate() * 240.0 / (lb_tempo * lb_denom);   // frames in the beat
            double done = std::max(0.0, std::min(0.999, (static_cast<double>(frames) - static_cast<double>(lb_frame)) / d));
            p->bar = lb_bar + 1; p->beat = lb_beat + 1; p->tick = static_cast<std::int32_t>(done * TPB);
            p->bar_start_tick = static_cast<double>(tb_bar_start);
            p->beats_per_bar = static_cast<float>(lb_beats); p->beat_type = static_cast<float>(lb_denom);
            p->beats_per_minute = lb_tempo * lb_denom / 4.0;
        } else {   // nothing plays yet: the start of the first bar, with the tempo of the settings
            p->bar = 1; p->beat = 1; p->tick = 0; p->bar_start_tick = 0.0;
            p->beats_per_bar = static_cast<float>(simple->beats()); p->beat_type = static_cast<float>(simple->denom());
            p->beats_per_minute = simple->tempo() * simple->denom() / 4.0;
        }
    }

    TempoMapPtr countin_map(float tempo, int denom) const
    {
        TempoMap::Pattern p(countin_beats_per_bar, TempoMap::BEAT_NORMAL);
        p[0] = TempoMap::BEAT_EMPHASIS;
        return TempoMap::new_simple(countin_bars, tempo, countin_beats_per_bar, denom, p, countin_volume);
    }

    // Waits until the audio thread has gone through a few blocks without the metronome that is being stopped.
    void wait_for_audio()
    {
        if (!backend.realtime) return;
        unsigned start = callbacks.load(std::memory_order_acquire);
        for (int i = 0; i < 100 && callbacks.load(std::memory_order_acquire) - start < 3; ++i) {
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }
    }

    void stop()
    {
        mode.store(0, std::memory_order_release);
        wait_for_audio();
        countin_active.store(false, std::memory_order_release);
        simple->stop();
        if (countin) { countin->stop(); countin.reset(); }
        if (map) { map->stop(); map.reset(); }
        joined = false;
        follow_active = false; simple_runs = true; was_rolling = false; external_was = false; restore_wanted = false;
        sync_state.store(0, std::memory_order_relaxed);
        ext_present.store(0, std::memory_order_relaxed);
    }
};


namespace {

// The CoreAudio backend: the interface of klick_engine.cpp's own library, opened on the device of the system.
// (The backend holds a pointer to the AudioInterface base class, as a void pointer: that is what the engine casts it back to.)
AudioInterfaceCoreAudio * as_coreaudio(void * a) { return static_cast<AudioInterfaceCoreAudio *>(static_cast<AudioInterface *>(a)); }
void coreaudio_start(void * a) { as_coreaudio(a)->start(); }
void coreaudio_stop(void * a) { as_coreaudio(a)->stop(); }
void coreaudio_destroy(void * a) { delete as_coreaudio(a); }
uint32_t coreaudio_latency(void * a) { return as_coreaudio(a)->output_latency_frames(); }

KlickBackend make_coreaudio_backend(uint32_t rate)
{
    KlickBackend b = KlickBackend();
    AudioInterface * audio = new AudioInterfaceCoreAudio(rate ? rate : 48000);
    b.audio = audio;
    b.id = "coreaudio";
    b.realtime = 1;
    b.start = coreaudio_start; b.stop = coreaudio_stop; b.destroy = coreaudio_destroy; b.output_latency = coreaudio_latency;
    return b;
}

// The offline backend: renders only when klick_engine_render is called.
void offline_destroy(void * a) { delete static_cast<AudioInterfaceOffline *>(static_cast<AudioInterface *>(a)); }

KlickBackend make_offline_backend(uint32_t rate)
{
    KlickBackend b = KlickBackend();
    AudioInterface * audio = new AudioInterfaceOffline(rate ? rate : 48000);
    b.audio = audio;
    b.id = "offline";
    b.realtime = 0;
    b.destroy = offline_destroy;
    return b;
}

}


extern "C" {

KlickEngine * klick_engine_create_with_backend(KlickBackend const * backend, char * error, size_t error_size)
{
    if (!backend || !backend->audio) { set_error(error, error_size, "no backend"); return NULL; }
    std::unique_ptr<KlickEngine> e(new KlickEngine);
    e->backend = *backend;      // owned from here on: ~KlickEngine destroys it, whatever happens next
    try {
        e->audio = static_cast<AudioInterface *>(e->backend.audio);
        e->simple.reset(new MetronomeSimple(*e->audio));
        KlickEngine * raw = e.get();
        e->transport = dynamic_cast<AudioInterfaceTransport *>(e->audio);
        e->simple->set_beat_callback([raw](Metronome::BeatEvent const & b) { raw->push_beat(b, false); raw->note_simple_beat(b); });

        // Silent sounds until the application loads some: a metronome without a sound must not crash.
        e->accent.reset(new AudioChunk(e->audio->samplerate()));
        e->normal.reset(new AudioChunk(e->audio->samplerate()));
        e->retired.push_back(e->accent); e->retired.push_back(e->normal);
        e->simple->set_sound(e->accent, e->normal);

        e->audio->set_process_callback([raw](sample_t * buffer, nframes_t n) { raw->process(buffer, n); });
        if (e->backend.start) e->backend.start(e->backend.audio);    // the output stays open, silent until a metronome starts
        return e.release();
    } catch (std::exception const & ex) {
        set_error(error, error_size, ex.what());
        return NULL;
    }
}


KlickEngine * klick_engine_create(int offline, uint32_t rate, char * error, size_t error_size)
{
    try {
        KlickBackend b = offline ? make_offline_backend(rate) : make_coreaudio_backend(rate);
        return klick_engine_create_with_backend(&b, error, error_size);
    } catch (std::exception const & ex) {
        set_error(error, error_size, ex.what());
        return NULL;
    }
}


char const * klick_engine_backend_id(KlickEngine const * e) { return e->backend.id ? e->backend.id : ""; }
void * klick_engine_backend_audio(KlickEngine const * e) { return e->backend.audio; }
int klick_engine_backend_is_shutdown(KlickEngine const * e)
{
    return e->backend.is_shutdown ? e->backend.is_shutdown(e->backend.audio) : 0;
}


void klick_engine_destroy(KlickEngine * e)
{
    if (!e) return;
    e->stop();
    if (e->backend.stop) e->backend.stop(e->backend.audio);
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
            auto in_range = [](float t) { return t >= 10.0f && t <= 1000.0f; };
            TempoMap::Entry en;
            if (s.tempi) {   // one tempo per beat
                if (s.bars < 1) throw std::runtime_error(where + "a list of tempos needs a number of bars");
                if (s.tempo_count != s.bars * s.beats) throw std::runtime_error(where + "number of tempo values doesn't match number of beats");
                for (int32_t k = 0; k < s.tempo_count; ++k) {
                    if (!in_range(s.tempi[k])) throw std::runtime_error(where + "tempo out of range (10 to 1000)");
                    en.tempi.push_back(s.tempi[k]);
                }
                en.tempo = 0.0f; en.tempo2 = 0.0f;       // klick: a tempo of zero means one tempo per beat
            } else {
                if (!in_range(s.tempo) || (s.tempo_end != 0.0f && !in_range(s.tempo_end))) throw std::runtime_error(where + "tempo out of range (10 to 1000)");
                if (s.tempo_end != 0.0f && s.bars < 1) throw std::runtime_error(where + "a tempo change needs a number of bars");
                en.tempo = s.tempo; en.tempo2 = s.tempo_end;
            }
            en.label = s.label ? s.label : "";
            en.bars = s.bars; en.beats = s.beats; en.denom = s.denom;
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


int klick_engine_set_countin(KlickEngine * e, int32_t bars, int32_t beats_per_bar, float volume, char * error, size_t error_size)
{
    if (bars < 0 || bars > 64 || (bars > 0 && (beats_per_bar < 1 || beats_per_bar > 64)) || !(volume >= 0.0f && volume <= 2.0f)) {
        set_error(error, error_size, "invalid count-in");
        return 0;
    }
    e->countin_bars = bars; e->countin_beats_per_bar = bars > 0 ? beats_per_bar : 4; e->countin_volume = volume;
    return 1;
}


int klick_engine_start(KlickEngine * e, KlickMode mode, char * error, size_t error_size)
{
    try {
        e->stop();
        if (!e->backend.realtime) e->apply_pending();
        else {   // let the audio thread take the staged changes first
            for (int i = 0; i < 50 && e->pending_flag.load(std::memory_order_acquire); ++i) std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }
        KlickEngine * raw = e;
        e->follow_active = e->transport_follow && e->transport;
        if (mode == KLICK_MODE_SIMPLE) {
            e->simple->set_start_delay(0);
            e->simple->set_start_position(0, 0);
            e->lb_valid = false; e->tb_bar_start = 0; e->tb_next_bar_start = 0;
            // with the transport, the metronome waits for it to roll: no count-in, and the first click is the first beat
            if (e->countin_bars > 0 && !e->follow_active) {
                float tempo = e->pending.tempo;
                if (e->pending.t_increment != 0.0f && e->pending.t_start != 0.0f) tempo = e->pending.t_start;   // the speed trainer starts slower
                e->countin.reset(new MetronomeMap(*e->audio, e->countin_map(tempo, e->pending.denom), 1.0f, false, -1, ""));
                e->countin->set_sound(e->accent, e->normal);
                e->countin->set_beat_callback([raw](Metronome::BeatEvent const & b) { raw->push_beat(b, true); });
                e->countin_total = e->countin_bars * e->countin_beats_per_bar; e->countin_index = 0;
                e->countin->start();
                nframes_t delay = e->countin->total_frames();
                e->simple->set_start_delay(delay);
                e->countin_frames_left = delay;
                e->countin_active.store(true, std::memory_order_release);
            }
            if (e->follow_active) {
                e->simple_runs = false; e->was_rolling = false;
                e->sync_state.store(1, std::memory_order_relaxed);
            } else {
                e->simple->start();
            }
            e->mode.store(KLICK_MODE_SIMPLE, std::memory_order_release);
        } else if (mode == KLICK_MODE_MAP) {
            if (!e->tempomap) throw std::runtime_error("no tempo map");
            TempoMapConstPtr played = e->tempomap;
            e->joined = e->countin_bars > 0 && !e->follow_active;   // (with the transport, the map has the time of the song: no count-in before it)
            if (e->joined) {   // the count-in is the first section: same tempo, meter unit and timing as the map
                TempoMap::Entry const & first = e->tempomap->entry(0);
                e->countin_total = e->countin_bars * e->countin_beats_per_bar; e->countin_index = 0;
                played = TempoMap::join(e->countin_map(first.tempo ? first.tempo : first.tempi[0], first.denom), e->tempomap);
            }
            e->map.reset(new MetronomeMap(*e->audio, played, e->multiplier, e->follow_active, -1, ""));
            e->map->set_sound(e->accent, e->normal);
            e->map->set_beat_callback([raw](Metronome::BeatEvent const & b) { raw->push_beat(b, false); });
            e->map->start();
            if (e->follow_active) { e->was_rolling = false; e->sync_state.store(1, std::memory_order_relaxed); }
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


void klick_engine_set_transport_follow(KlickEngine * e, int follow) { e->transport_follow = follow != 0 && e->transport; }


int klick_engine_set_timebase_master(KlickEngine * e, int on, char * error, size_t error_size)
{
    if (!e->transport) { if (!on) return 1; set_error(error, error_size, "no transport"); return 0; }
    try {
        KlickEngine * raw = e;
        e->timebase_on.store(on != 0, std::memory_order_relaxed);
        e->transport->set_timebase_callback(on ? AudioInterfaceTransport::TimebaseCallback([raw](position_t * p) { raw->timebase(p); })
                                               : AudioInterfaceTransport::TimebaseCallback());
        return 1;
    } catch (std::exception const & ex) {
        e->timebase_on.store(false, std::memory_order_relaxed);
        set_error(error, error_size, ex.what());
        return 0;
    }
}


void klick_engine_transport_info(KlickEngine const * e, KlickTransportInfo * info)
{
    info->state = e->sync_state.load(std::memory_order_relaxed);
    info->external = e->ext_present.load(std::memory_order_relaxed);
    info->tempo = e->ext_tempo.load(std::memory_order_relaxed);
    info->beats = e->ext_beats.load(std::memory_order_relaxed);
    info->denom = e->ext_denom.load(std::memory_order_relaxed);
}


int klick_engine_is_playing(KlickEngine const * e)
{
    switch (e->mode.load(std::memory_order_acquire)) {
      case KLICK_MODE_SIMPLE: return 1;
      case KLICK_MODE_MAP:    return e->map && e->map->running() ? 1 : 0;
      default:                return 0;
    }
}


uint64_t klick_engine_position(KlickEngine const * e) { return e->position.load(std::memory_order_acquire); }


uint32_t klick_engine_output_latency(KlickEngine const * e)
{
    return e->backend.output_latency ? e->backend.output_latency(e->backend.audio) : 0;
}


uint32_t klick_engine_output_device(KlickEngine const * e) { return e->coreaudio() ? e->coreaudio()->current_device() : 0; }


int klick_engine_set_output_device(KlickEngine * e, uint32_t device, char * error, size_t error_size)
{
    if (!e->coreaudio()) return 1;   // another backend: nothing to move
    try {
        e->coreaudio()->set_device(device);
        return 1;
    } catch (std::exception const & ex) {
        set_error(error, error_size, ex.what());
        return 0;
    }
}


int klick_engine_follow_system_output(KlickEngine * e, char * error, size_t error_size)
{
    if (!e->coreaudio()) return 0;
    try {
        return e->coreaudio()->sync_with_system() ? 1 : 0;
    } catch (std::exception const & ex) {
        set_error(error, error_size, ex.what());
        return -1;
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
    if (e->offline()) e->offline()->render(out, frames);
}


uint32_t klick_engine_dropouts(KlickEngine const * e) { return e->coreaudio() ? e->coreaudio()->discontinuities() : 0; }
uint32_t klick_engine_max_lateness_us(KlickEngine const * e) { return e->coreaudio() ? e->coreaudio()->max_host_deviation_us() : 0; }

}
