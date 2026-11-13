/*
 * Test of a change of output device while the engine plays: a metronome (4/4, 120 BPM) runs for a given time on the
 * default output device, and the beats, dropouts and name of the default device are printed every second. During the
 * test, change the output of the Mac (menu bar, Sound), and back. A change interrupts the sound for a moment (the system
 * reconfigures the device: about two seconds for Bluetooth); afterwards the beats must come again (2 per second) and the
 * clicks must follow the new device.
 * Usage: engine_device_test <sounds dir> [seconds] [volume, default 0.15]
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#include "klick_engine.h"

#include <CoreAudio/CoreAudio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void default_output_name(char *name, size_t size)
{
    AudioObjectPropertyAddress addr = { kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    AudioDeviceID device = 0; UInt32 n = sizeof device;
    snprintf(name, size, "?");
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &n, &device) != noErr) return;
    CFStringRef cf = NULL; n = sizeof cf;
    AudioObjectPropertyAddress na = { kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
    if (AudioObjectGetPropertyData(device, &na, 0, NULL, &n, &cf) == noErr && cf) {
        CFStringGetCString(cf, name, (CFIndex)size, kCFStringEncodingUTF8);
        CFRelease(cf);
    }
}

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: %s <sounds dir> [seconds] [volume]\n", argv[0]); return 2; }
    int seconds = argc > 2 ? atoi(argv[2]) : 40;
    float volume = argc > 3 ? (float)atof(argv[3]) : 0.15f;
    char err[256] = "", a[512], n[512], name[256], last_name[256] = "";
    snprintf(a, sizeof a, "%s/square_emphasis.wav", argv[1]);
    snprintf(n, sizeof n, "%s/square_normal.wav", argv[1]);

    KlickEngine *e = klick_engine_create(0, 48000, err, sizeof err);
    if (!e) { fprintf(stderr, "error: %s\n", err); return 1; }
    if (!klick_engine_load_sound(e, a, n, 1, 1, 1, 1, err, sizeof err) ||
        !klick_engine_set_simple(e, 120, 4, 4, NULL, 0, 0, 0, err, sizeof err) ||
        !klick_engine_start(e, KLICK_MODE_SIMPLE, err, sizeof err)) { fprintf(stderr, "error: %s\n", err); return 1; }
    klick_engine_set_volume(e, volume);

    printf("engine at %u Hz, %d s, volume %.2f. Change the output device of the Mac a few times while this runs.\n",
           klick_engine_samplerate(e), seconds, volume);
    KlickBeat beats[64];
    int stalls = 0, changes = 0, run = 0, longest = 0, tail_ok = 0;
    for (int s = 1; s <= seconds; ++s) {
        sleep(1);
        size_t k = klick_engine_poll_beats(e, beats, 64);
        default_output_name(name, sizeof name);
        int changed = last_name[0] && strcmp(name, last_name) != 0;
        if (changed) ++changes;
        int stalled = k < 1;
        if (stalled) { ++stalls; ++run; if (run > longest) longest = run; } else run = 0;
        tail_ok = !stalled && s > 2 ? tail_ok + 1 : 0;
        printf("%3d s  beats %zu  dropouts %u  lateness %u us  output: %s%s%s\n", s, k, klick_engine_dropouts(e), klick_engine_max_lateness_us(e),
               name, changed ? "   <-- output changed" : "", stalled ? "   <-- NO BEAT" : "");
        fflush(stdout);
        strcpy(last_name, name);
    }
    unsigned drop = klick_engine_dropouts(e);
    klick_engine_destroy(e);
    printf("\noutput changes seen: %d, seconds without a beat: %d, dropouts: %u\n", changes, stalls, drop);
    printf("longest silence without a beat: %d s\n", longest);
    int ok = changes > 0 && longest <= 3 && tail_ok >= 3;   /* back to normal after the last change */
    printf("RESULT: %s\n", changes == 0 ? "no change of output happened, nothing to conclude"
           : ok ? "the metronome resumed by itself after each change" : "the metronome did not come back after a change");
    return changes == 0 || ok ? 0 : 1;
}
