/*
 * Steady test of the CoreAudio backend: 4/4 at 120 BPM for a given time, with the delivery diagnostics of the backend
 * (dropouts of the device clock, lateness of the blocks) and the regularity of the beats.
 * Usage: engine_steady_test <samples dir> [seconds] [engine rate, 0 = the rate of the device]
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#include "audio_interface_coreaudio.hh"
#include "audio_chunk.hh"
#include "metronome_simple.hh"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <thread>
#include <vector>


int main(int argc, char ** argv)
{
    if (argc < 2) { std::fprintf(stderr, "usage: %s <samples dir> [seconds]\n", argv[0]); return 2; }
    double seconds = argc > 2 ? std::atof(argv[2]) : 10.0;
    try {
        AudioInterfaceCoreAudio audio(argc > 3 ? static_cast<nframes_t>(std::atoi(argv[3])) : 0);
        AudioChunkConstPtr emphasis(new AudioChunk(std::string(argv[1]) + "/square_emphasis.wav", audio.samplerate()));
        AudioChunkConstPtr normal(new AudioChunk(std::string(argv[1]) + "/square_normal.wav", audio.samplerate()));
        MetronomeSimple metro(audio);
        metro.set_sound(emphasis, normal);
        metro.set_tempo(120.0f);
        audio.set_volume(0.2f);
        audio.set_process_callback(std::bind(&Metronome::process_callback, &metro, std::placeholders::_1, std::placeholders::_2));

        std::vector<double> frames(4096, 0.0);
        std::size_t n = 0, pos = 0;
        metro.set_beat_callback([&](Metronome::BeatEvent const & e) { if (n < frames.size()) frames[n++] = double(pos) + e.offset; });
        audio.set_monitor([&](sample_t const *, nframes_t k) { pos += k; });

        std::printf("engine at %u Hz, 4/4 at 120 BPM for %.0f s\n", audio.samplerate(), seconds);
        metro.start();
        audio.start();
        std::this_thread::sleep_for(std::chrono::duration<double>(seconds));
        audio.stop();

        double worst = 0.0;
        for (std::size_t i = 1; i < n; ++i) worst = std::max(worst, std::fabs((frames[i] - frames[i - 1]) - 0.5 * audio.samplerate()));
        std::printf("beats: %zu, worst deviation of a beat interval from 0.500 s: %.1f frames\n", n, worst);
        std::printf("dropouts of the device clock: %u\n", audio.discontinuities());
        std::printf("largest lateness of a block: %u microseconds (a block lasts %.0f)\n", audio.max_host_deviation_us(), 512 * 1.0e6 / audio.samplerate());
    } catch (std::exception const & e) {
        std::fprintf(stderr, "error: %s\n", e.what());
        return 1;
    }
    return 0;
}
