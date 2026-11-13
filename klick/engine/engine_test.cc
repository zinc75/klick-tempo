/*
 * Test program of the CoreAudio backend: plays the klick engine (MetronomeSimple) through the default output
 * device at 120 BPM, then 240 BPM, records the signal handed to CoreAudio and measures the clicks in it.
 * Usage: engine_test <samples dir> [seconds per tempo]
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
    if (argc < 2) { std::fprintf(stderr, "usage: %s <samples dir> [seconds per tempo]\n", argv[0]); return 2; }
    std::string dir = argv[1];
    double seconds = argc > 2 ? std::atof(argv[2]) : 3.0;

    try {
        AudioInterfaceCoreAudio audio;
        std::printf("device sample rate: %u Hz, largest block: %u frames\n", audio.samplerate(), audio.max_block());

        AudioChunkConstPtr emphasis(new AudioChunk(dir + "/square_emphasis.wav", audio.samplerate()));
        AudioChunkConstPtr normal(new AudioChunk(dir + "/square_normal.wav", audio.samplerate()));

        MetronomeSimple metro(audio);
        metro.set_sound(emphasis, normal);
        metro.set_tempo(120.0f);
        audio.set_volume(0.2f);
        audio.set_process_callback(std::bind(&Metronome::process_callback, &metro, std::placeholders::_1, std::placeholders::_2));

        // Everything the audio thread needs is allocated before it starts.
        std::vector<float> rec(static_cast<std::size_t>((2 * seconds + 2) * audio.samplerate()), 0.0f);
        std::size_t pos = 0, callbacks = 0;
        nframes_t min_block = ~0u, max_block = 0;
        audio.set_monitor([&](sample_t const * buf, nframes_t n) {
            if (pos + n <= rec.size()) { std::copy(buf, buf + n, rec.begin() + pos); pos += n; }
            ++callbacks; min_block = std::min(min_block, n); max_block = std::max(max_block, n);
        });

        metro.start();
        audio.start();
        std::this_thread::sleep_for(std::chrono::duration<double>(seconds));
        metro.set_tempo(240.0f);
        std::size_t tempo_change = pos;
        std::this_thread::sleep_for(std::chrono::duration<double>(seconds));
        audio.stop();

        // Find the clicks in the recorded signal.
        float peak = 0.0f; for (std::size_t i = 0; i < pos; ++i) peak = std::max(peak, std::fabs(rec[i]));
        std::vector<double> t; std::size_t last = 0; bool any = false;
        for (std::size_t i = 0; i < pos; ++i)
            if (std::fabs(rec[i]) > peak * 0.3f && (!any || i - last > audio.samplerate() * 0.08)) { t.push_back(double(i) / audio.samplerate()); last = i; any = true; }
        std::printf("callbacks: %zu, block sizes %u..%u, recorded %.2f s, peak %.3f\n", callbacks, min_block, max_block, double(pos) / audio.samplerate(), peak);
        std::printf("clicks: %zu, tempo changed at %.2f s\nintervals:", t.size(), double(tempo_change) / audio.samplerate());
        for (std::size_t i = 1; i < t.size(); ++i) std::printf(" %.3f", t[i] - t[i - 1]);
        std::printf("\n");
    } catch (std::exception const & e) {
        std::fprintf(stderr, "error: %s\n", e.what());
        return 1;
    }
    return 0;
}
