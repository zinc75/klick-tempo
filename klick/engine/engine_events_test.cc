/*
 * Test of the beat events (patch 0002) through the CoreAudio backend: plays the simple metronome and a short tempo map
 * on the default output device, collects the events sent from the audio thread, and checks them against the clicks
 * found in the signal handed to CoreAudio (beat position, silence, tempo, section).
 * Usage: engine_events_test <samples dir> <tempo map file>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#include "audio_interface_coreaudio.hh"
#include "audio_chunk.hh"
#include "metronome_simple.hh"
#include "metronome_map.hh"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <functional>
#include <thread>
#include <vector>


struct Recorded {
    Metronome::BeatEvent e;
    double frame;      // frame of the beat in the recorded signal
};


// Plays 'metro' for 'seconds' and returns the beat events with the clicks found in the signal.
static bool run(AudioInterfaceCoreAudio & audio, Metronome & metro, double seconds, char const * label, int expected_clicks)
{
    std::vector<float> rec(static_cast<std::size_t>((seconds + 1) * audio.samplerate()), 0.0f);
    std::vector<Recorded> events(1024);
    std::atomic<std::size_t> n_events(0);
    std::size_t pos = 0;   // frames handed to CoreAudio so far; only the audio thread writes it

    metro.set_beat_callback([&](Metronome::BeatEvent const & e) {
        std::size_t i = n_events.load(std::memory_order_relaxed);
        if (i < events.size()) { events[i] = { e, static_cast<double>(pos) + e.offset }; n_events.store(i + 1, std::memory_order_release); }
    });
    audio.set_process_callback(std::bind(&Metronome::process_callback, &metro, std::placeholders::_1, std::placeholders::_2));
    audio.set_monitor([&](sample_t const * buf, nframes_t n) {
        if (pos + n <= rec.size()) std::copy(buf, buf + n, rec.begin() + pos);
        pos += n;
    });

    metro.start();
    audio.start();
    std::this_thread::sleep_for(std::chrono::duration<double>(seconds));
    audio.stop();
    metro.stop();
    audio.set_monitor(nullptr);

    // clicks in the signal
    float peak = 0.0f; for (std::size_t i = 0; i < rec.size(); ++i) peak = std::max(peak, std::fabs(rec[i]));
    std::vector<double> clicks; std::size_t last = 0;
    for (std::size_t i = 0; i < rec.size(); ++i)
        if (std::fabs(rec[i]) > peak * 0.3f && (clicks.empty() || i - last > audio.samplerate() * 0.05)) { clicks.push_back(double(i)); last = i; }

    std::size_t n = n_events.load(std::memory_order_acquire);
    std::printf("\n== %s: %zu beat events, %zu clicks in the signal\n", label, n, clicks.size());
    std::printf("   entry bar beat/beats denom  tempo  type      time(s)\n");
    std::size_t k = 0, matched = 0, silent = 0; double worst = 0.0;
    for (std::size_t i = 0; i < n && i < static_cast<std::size_t>(expected_clicks) + 6; ++i) {
        Recorded const & r = events[i];
        char const * type = r.e.type == TempoMap::BEAT_EMPHASIS ? "accent" : r.e.type == TempoMap::BEAT_NORMAL ? "normal" : "silent";
        std::printf("   %5d %3d %4d/%-5d %3d %7.2f  %-7s %7.3f\n", r.e.entry, r.e.bar, r.e.beat, r.e.beats, r.e.denom, r.e.tempo, type, r.frame / audio.samplerate());
        if (r.e.type == TempoMap::BEAT_SILENT) { ++silent; continue; }
        if (k < clicks.size()) { worst = std::max(worst, std::fabs(clicks[k] - r.frame)); if (std::fabs(clicks[k] - r.frame) <= 2.0) ++matched; ++k; }
    }
    std::printf("   audible events matched to the clicks within 2 frames: %zu of %zu (worst gap %.1f frames), silent events: %zu\n", matched, k, worst, silent);
    return matched == k && k > 0;
}


int main(int argc, char ** argv)
{
    if (argc < 3) { std::fprintf(stderr, "usage: %s <samples dir> <tempo map file>\n", argv[0]); return 2; }
    std::string dir = argv[1];
    bool ok = true;
    try {
        AudioInterfaceCoreAudio audio;
        std::printf("device sample rate: %u Hz\n", audio.samplerate());
        AudioChunkConstPtr emphasis(new AudioChunk(dir + "/square_emphasis.wav", audio.samplerate()));
        AudioChunkConstPtr normal(new AudioChunk(dir + "/square_normal.wav", audio.samplerate()));
        audio.set_volume(0.2f);

        {   // simple metronome: 3/4 at 150, pattern X.x (the second beat is silent)
            MetronomeSimple metro(audio);
            metro.set_sound(emphasis, normal);
            metro.set_meter(3, 4);
            metro.set_tempo(150.0f);
            TempoMap::Pattern p; p.push_back(TempoMap::BEAT_EMPHASIS); p.push_back(TempoMap::BEAT_SILENT); p.push_back(TempoMap::BEAT_NORMAL);
            metro.set_pattern(p);
            ok &= run(audio, metro, 2.2, "simple 3/4, 150 BPM, pattern X.x", 6);
        }
        {   // tempo map
            MetronomeMap metro(audio, TempoMap::new_from_file(argv[2]), 1.0f, false, -1, "");
            metro.set_sound(emphasis, normal);
            ok &= run(audio, metro, 5.2, "tempo map", 12);
        }
    } catch (std::exception const & e) {
        std::fprintf(stderr, "error: %s\n", e.what());
        return 1;
    }
    std::printf("\nRESULT: %s\n", ok ? "all matched" : "MISMATCH");
    return ok ? 0 : 1;
}
