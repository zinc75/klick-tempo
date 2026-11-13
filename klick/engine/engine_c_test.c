/*
 * Test of the C interface of the engine (klick_engine.h) on an offline engine: no audio device, no sound played.
 * Usage: engine_c_test <sounds dir>
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#include "klick_engine.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RATE 48000
#define BLOCK 512

static int failures = 0;
static char err[256];   /* error buffer of the last call; cleared after each check */
static void check(int ok, const char *label, const char *detail)
{
    printf("%s %s%s%s\n", ok ? "PASS" : "FAIL", label, detail && *detail ? "  " : "", detail ? detail : "");
    if (!ok) ++failures;
    err[0] = 0;
}

static float *signal_buf; static size_t signal_len;
static uint64_t rendered, play_base;   /* frames rendered so far, and at the start of the last play() */

/* Renders about 'seconds' of audio into signal_buf (appending) and collects the beats. */
static size_t play(KlickEngine *e, double seconds, KlickBeat *beats, size_t max_beats)
{
    size_t n = 0, blocks = (size_t)(seconds * RATE / BLOCK) + 1;
    signal_len = 0; play_base = rendered;
    for (size_t b = 0; b < blocks; ++b) {
        klick_engine_render(e, signal_buf + signal_len, BLOCK);
        signal_len += BLOCK; rendered += BLOCK;
        n += klick_engine_poll_beats(e, beats + n, max_beats - n);
    }
    return n;
}

static float peak_around(uint64_t frame, size_t width)
{
    float p = 0;
    frame -= play_base;
    for (size_t i = (size_t)frame; i < (size_t)frame + width && i < signal_len; ++i) p = fmaxf(p, fabsf(signal_buf[i]));
    return p;
}

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: %s <sounds dir>\n", argv[0]); return 2; }
    char accent[512], normal[512], detail[256];
    snprintf(accent, sizeof accent, "%s/square_emphasis.wav", argv[1]);
    snprintf(normal, sizeof normal, "%s/square_normal.wav", argv[1]);
    signal_buf = calloc(RATE * 30, sizeof(float));
    KlickBeat *beats = calloc(1024, sizeof(KlickBeat));

    KlickEngine *e = klick_engine_create(1, RATE, err, sizeof err);
    check(e != NULL, "offline engine created", err);
    if (!e) return 1;
    check(klick_engine_samplerate(e) == RATE, "sample rate", "");

    check(!klick_engine_start(e, KLICK_MODE_MAP, err, sizeof err) && strstr(err, "no tempo map"), "a map cannot start before it is set", err);
    check(!klick_engine_set_simple(e, 5.0f, 4, 4, NULL, 0, 0, 0, err, sizeof err), "tempo 5 is refused", err);
    check(!klick_engine_set_simple(e, 120.0f, 3, 4, "Xx", 0, 0, 0, err, sizeof err), "a pattern of the wrong length is refused", err);
    check(!klick_engine_load_sound(e, "/nonexistent.wav", NULL, 1, 1, 1, 1, err, sizeof err) && err[0], "a missing sound file is reported", err);
    check(klick_engine_load_sound(e, accent, normal, 1.0f, 1.0f, 1.0f, 1.0f, err, sizeof err), "sounds loaded", err);

    /* simple metronome, 3/4 at 150 BPM, pattern X.x */
    check(klick_engine_set_simple(e, 150.0f, 3, 4, "X.x", 0, 0, 0, err, sizeof err), "simple metronome set", err);
    check(klick_engine_start(e, KLICK_MODE_SIMPLE, err, sizeof err), "simple metronome started", err);
    size_t n = play(e, 2.1, beats, 1024);
    check(n >= 6, "six beats in two seconds", "");
    check(beats[0].type == KLICK_BEAT_ACCENT && beats[1].type == KLICK_BEAT_SILENT && beats[2].type == KLICK_BEAT_NORMAL, "types X . x", "");
    check(beats[0].beats == 3 && beats[0].denom == 4 && fabsf(beats[0].tempo - 150.0f) < 0.01f, "meter and tempo of the events", "");
    check(beats[3].bar == 1 && beats[3].beat == 0, "second bar starts at bar 1, beat 0", "");
    snprintf(detail, sizeof detail, "frames %llu %llu %llu", (unsigned long long)beats[0].frame, (unsigned long long)beats[1].frame, (unsigned long long)beats[2].frame);
    check(beats[1].frame - beats[0].frame == 19200 && beats[2].frame - beats[1].frame == 19200, "beats 0.400 s apart", detail);
    check(peak_around(beats[0].frame, 200) > 0.3f && peak_around(beats[1].frame, 200) == 0.0f && peak_around(beats[2].frame, 200) > 0.2f, "clicks on X and x, nothing on the silent beat", "");

    /* a change while it plays: 300 BPM */
    check(klick_engine_set_simple(e, 300.0f, 3, 4, "Xxx", 0, 0, 0, err, sizeof err), "tempo changed while playing", err);
    n = play(e, 1.0, beats, 1024);
    int fast = 0; for (size_t i = 1; i < n; ++i) if (beats[i].frame - beats[i - 1].frame == 9600) ++fast;
    check(n >= 4 && fast >= (int)n - 2, "beats now 0.200 s apart", "");
    check(beats[n - 1].type != KLICK_BEAT_SILENT && fabsf(beats[n - 1].tempo - 300.0f) < 0.01f, "new pattern and tempo reach the events", "");
    klick_engine_stop(e);
    check(!klick_engine_is_playing(e), "stopped", "");

    /* tempo map: 1 bar 4/4 at 120, 1 bar 3/4 from 90 to 120, a silent 5/8 bar at 140 */
    KlickSection map[3] = {
        { "intro", 1, 4, 4, 120.0f, 0.0f, "Xxxx", 1.0f },
        { NULL, 1, 3, 4, 90.0f, 120.0f, NULL, 1.0f },
        { "quiet", 1, 5, 8, 140.0f, 0.0f, "X.xxx", 0.0f },
    };
    check(klick_engine_set_map(e, map, 3, 1.0f, err, sizeof err), "tempo map set", err);
    KlickSection bad = { NULL, 0, 4, 4, 120.0f, 0.0f, NULL, 1.0f };
    check(!klick_engine_set_map(e, &bad, 1, 1.0f, err, sizeof err) && strstr(err, "section 1"), "a section without bars is refused", err);
    check(klick_engine_start(e, KLICK_MODE_MAP, err, sizeof err), "map started", err);
    check(klick_engine_is_playing(e), "map playing", "");
    n = play(e, 5.5, beats, 1024);
    check(n == 12, "12 beats in the map", "");
    check(beats[0].section == 0 && beats[4].section == 1 && beats[7].section == 2, "section numbers", "");
    check(fabsf(beats[7].tempo - 140.0f) < 0.05f && beats[7].denom == 8 && beats[7].beats == 5, "5/8 at 140", "");
    check(beats[4].tempo > 90.0f && beats[4].tempo < beats[6].tempo && beats[6].tempo < 120.0f, "the tempo rises through the ramp", "");
    check(beats[7].volume == 0.0f && beats[0].volume == 1.0f, "volume of the sections in the events", "");
    check(peak_around(beats[7].frame, 200) == 0.0f && peak_around(beats[0].frame, 200) > 0.3f, "the silent section makes no sound", "");
    check(!klick_engine_is_playing(e), "the map is over", "");
    klick_engine_stop(e);

    /* start again: the positions begin again from zero */
    check(klick_engine_start(e, KLICK_MODE_MAP, err, sizeof err), "map restarted", err);
    n = play(e, 0.6, beats, 1024);
    check(n >= 2 && beats[0].section == 0 && beats[0].bar == 0 && beats[0].beat == 0, "restart from the first beat", "");
    klick_engine_stop(e);

    check(klick_engine_lost_beats(e) == 0, "no beat lost", "");
    klick_engine_destroy(e);
    printf("\nRESULT: %s\n", failures ? "FAILURES" : "all passed");
    return failures ? 1 : 0;
}
