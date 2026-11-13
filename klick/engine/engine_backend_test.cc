/*
 * Test of klick_engine_create_with_backend: the engine on a backend that comes from outside (a fake one, written here, at a sample
 * rate that is not 48 kHz). Checks what a library that provides a backend (JACK) relies on: the id, the AudioInterface handed
 * back, the start / stop / destroy calls, the latency and the shutdown reports, the engine working at the rate of the backend, and
 * clicks at the right place. No audio device is needed.
 * Usage: engine_backend_test <sounds dir>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#include "klick_engine.h"
#include "audio_interface.hh"

#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace {

int failures = 0;

#define CHECK(cond) do { if (!(cond)) { std::printf("FAIL line %d: %s\n", __LINE__, #cond); ++failures; } } while (0)

int started = 0, stopped = 0, destroyed = 0;
bool gone = false;

class FakeInterface : public AudioInterface
{
  public:
    explicit FakeInterface(nframes_t rate) : _rate(rate) { }
    virtual nframes_t samplerate() const { return _rate; }
    virtual bool is_shutdown() const { return gone; }
    // What a backend does for each block: silence, the process callback, the mix of the clicks.
    void pump(sample_t * out, nframes_t n)
    {
        std::memset(out, 0, n * sizeof(sample_t));
        if (_process_cb) _process_cb(out, n);
        process_mix(out, n);
    }
  private:
    nframes_t _rate;
};

void fake_start(void *) { ++started; }
void fake_stop(void *) { ++stopped; }
void fake_destroy(void * a) { ++destroyed; delete static_cast<FakeInterface *>(a); }
uint32_t fake_latency(void *) { return 123; }
int fake_shutdown(void *) { return gone ? 1 : 0; }

KlickBackend fake_backend(uint32_t rate)
{
    KlickBackend b = KlickBackend();
    b.id = "fake";
    b.audio = new FakeInterface(rate);
    b.realtime = 0;
    b.start = fake_start; b.stop = fake_stop; b.destroy = fake_destroy;
    b.output_latency = fake_latency; b.is_shutdown = fake_shutdown;
    return b;
}

}

int main(int argc, char ** argv)
{
    if (argc < 2) { std::fprintf(stderr, "usage: %s <sounds dir>\n", argv[0]); return 2; }
    std::string dir = argv[1];
    char err[256] = "";

    // no backend, or one without an interface: NULL and a message
    CHECK(klick_engine_create_with_backend(NULL, err, sizeof err) == NULL);
    KlickBackend empty = KlickBackend();
    err[0] = 0;
    CHECK(klick_engine_create_with_backend(&empty, err, sizeof err) == NULL);
    CHECK(err[0] != 0);

    const uint32_t rate = 44100;
    KlickBackend b = fake_backend(rate);
    FakeInterface * fake = static_cast<FakeInterface *>(b.audio);
    KlickEngine * e = klick_engine_create_with_backend(&b, err, sizeof err);
    CHECK(e != NULL);
    if (!e) return 1;

    CHECK(std::string(klick_engine_backend_id(e)) == "fake");
    CHECK(klick_engine_backend_audio(e) == static_cast<void *>(fake));
    CHECK(klick_engine_samplerate(e) == rate);
    CHECK(started == 1 && stopped == 0 && destroyed == 0);
    CHECK(klick_engine_output_latency(e) == 123);
    CHECK(klick_engine_backend_is_shutdown(e) == 0);
    // the functions that belong to CoreAudio do nothing on another backend
    CHECK(klick_engine_output_device(e) == 0);
    CHECK(klick_engine_follow_system_output(e, err, sizeof err) == 0);
    CHECK(klick_engine_set_output_device(e, 0, err, sizeof err) == 1);
    CHECK(klick_engine_dropouts(e) == 0);

    CHECK(klick_engine_load_sound(e, (dir + "/square_emphasis.wav").c_str(), (dir + "/square_normal.wav").c_str(), 1, 1, 1, 1, err, sizeof err));
    CHECK(klick_engine_set_simple(e, 120.0f, 4, 4, "Xxxx", 0, 0, 0, err, sizeof err));
    CHECK(klick_engine_start(e, KLICK_MODE_SIMPLE, err, sizeof err));

    // two seconds, in blocks of 512 frames, as the backend would call the engine
    const uint32_t total = 2 * rate;
    std::vector<float> signal(total + 512, 0.0f);
    for (uint32_t pos = 0; pos < total; pos += 512) fake->pump(&signal[pos], 512);

    std::vector<uint32_t> onsets;
    for (uint32_t i = 0; i < total; ++i) {
        if (std::fabs(signal[i]) > 0.01f && (onsets.empty() || i - onsets.back() > 4000)) onsets.push_back(i);
    }
    std::printf("clicks heard: %zu\n", onsets.size());
    CHECK(onsets.size() == 4);
    for (size_t i = 1; i < onsets.size(); ++i) CHECK(onsets[i] - onsets[i - 1] == rate / 2);   // 120 BPM: exactly half a second

    KlickBeat beats[64];
    size_t n = klick_engine_poll_beats(e, beats, 64);
    std::printf("beat events: %zu\n", n);
    CHECK(n >= 4);
    for (size_t i = 0; i < n && i < onsets.size(); ++i) {
        CHECK(beats[i].frame == onsets[i] || (beats[i].frame + 1 == onsets[i]) || (beats[i].frame == onsets[i] + 1));   // the click starts at its beat
        CHECK(beats[i].beat == static_cast<int>(i % 4));
        CHECK((i % 4 == 0) == (beats[i].type == KLICK_BEAT_ACCENT));
    }

    gone = true;
    CHECK(klick_engine_backend_is_shutdown(e) == 1);
    gone = false;

    klick_engine_destroy(e);
    CHECK(stopped == 1);
    CHECK(destroyed == 1);

    // an engine that is destroyed without having played: the backend is destroyed all the same
    KlickBackend b2 = fake_backend(48000);
    KlickEngine * e2 = klick_engine_create_with_backend(&b2, err, sizeof err);
    CHECK(e2 != NULL);
    klick_engine_destroy(e2);
    CHECK(destroyed == 2);

    // an engine of klick on the offline backend still renders
    KlickEngine * off = klick_engine_create(1, 48000, err, sizeof err);
    CHECK(off != NULL);
    if (off) {
        CHECK(std::string(klick_engine_backend_id(off)) == "offline");
        klick_engine_destroy(off);
    }

    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("ok\n");
    return 0;
}
