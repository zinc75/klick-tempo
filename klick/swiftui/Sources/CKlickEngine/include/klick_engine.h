/*
 * C interface to the klick engine (the metronome of klick, patched, running on CoreAudio), for the Swift application.
 * Everything here is called from one control thread (the main thread of the application) except klick_engine_poll_beats,
 * which may be called from any single thread. No C++ exception crosses this interface: functions that can fail return 0
 * and write a message to the error buffer.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Licence of the program it belongs to (klick).
 */

#ifndef KLICK_ENGINE_H
#define KLICK_ENGINE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct KlickEngine KlickEngine;

typedef enum {
    KLICK_BEAT_ACCENT = 1,
    KLICK_BEAT_NORMAL = 2,
    KLICK_BEAT_SILENT = 3
} KlickBeatType;

typedef enum {
    KLICK_MODE_SIMPLE = 1,      // one meter and tempo, played until stopped
    KLICK_MODE_MAP = 2          // the tempo map, played once
} KlickMode;

/* One beat, sent by the audio thread when the beat is scheduled; silent beats are reported too. */
typedef struct {
    uint64_t frame;             /* position of the beat, in frames since the engine began rendering */
    int32_t section;            /* tempo map section, 0 for the simple metronome */
    int32_t bar;                /* bar in the section, counted from 0 */
    int32_t beat;               /* beat in the bar, counted from 0 */
    int32_t beats;              /* beats per bar */
    int32_t denom;              /* beat unit of the meter */
    int32_t type;               /* KlickBeatType */
    float tempo;                /* quarter notes per minute at this beat */
    float volume;               /* volume of the section, 1 for the simple metronome */
} KlickBeat;

/* One section of a tempo map. */
typedef struct {
    const char *label;          /* may be NULL */
    int32_t bars;               /* number of bars, or -1 to play forever (last section only) */
    int32_t beats;
    int32_t denom;
    float tempo;                /* quarter notes per minute */
    float tempo_end;            /* 0 for a constant tempo, else the tempo reached at the end of the section */
    const char *pattern;        /* one character per beat: X accent, x normal, . silent; NULL for the default pattern */
    float volume;               /* 1 normal, 0 silent */
} KlickSection;

/* Creates an engine. 'offline' = 0 plays on the default output device; 1 renders only when klick_engine_render is
 * called, at 'offline_rate' Hz (tests). Returns NULL on failure. */
KlickEngine *klick_engine_create(int offline, uint32_t offline_rate, char *error, size_t error_size);
void klick_engine_destroy(KlickEngine *);

uint32_t klick_engine_samplerate(const KlickEngine *);

/* Click sounds, from files (any format of libsndfile); a NULL or empty path gives silence. Volumes and pitch factors
 * are multipliers (1 = unchanged). Resampled to the rate of the output. */
int klick_engine_load_sound(KlickEngine *, const char *accent_path, const char *normal_path,
                            float accent_volume, float normal_volume, float accent_pitch, float normal_pitch,
                            char *error, size_t error_size);
void klick_engine_set_volume(KlickEngine *, float volume);

/* The simple metronome. May be called while it plays. 'pattern' has one character per beat (X, x, .) or is NULL.
 * Speed trainer: tempo_start, tempo_increment (quarter notes per bar) and tempo_limit, all 0 for none. */
int klick_engine_set_simple(KlickEngine *, float tempo, int32_t beats, int32_t denom, const char *pattern,
                            float tempo_start, float tempo_increment, float tempo_limit,
                            char *error, size_t error_size);

/* The tempo map. Takes effect at the next start. */
int klick_engine_set_map(KlickEngine *, const KlickSection *sections, size_t count, float tempo_multiplier,
                         char *error, size_t error_size);

int klick_engine_start(KlickEngine *, KlickMode mode, char *error, size_t error_size);
void klick_engine_stop(KlickEngine *);
/* 1 while something plays; a tempo map that has reached its end is no longer playing. */
int klick_engine_is_playing(const KlickEngine *);

/* Copies up to 'max' beats, oldest first, and returns how many. */
size_t klick_engine_poll_beats(KlickEngine *, KlickBeat *out, size_t max);
/* Beats lost because nobody polled fast enough. */
uint64_t klick_engine_lost_beats(const KlickEngine *);

/* Offline engines: renders 'frames' mono frames into 'out'. */
void klick_engine_render(KlickEngine *, float *out, uint32_t frames);

/* Delivery diagnostics of the output device since the engine was created (0 for offline engines). */
uint32_t klick_engine_dropouts(const KlickEngine *);
uint32_t klick_engine_max_lateness_us(const KlickEngine *);

#ifdef __cplusplus
}
#endif

#endif /* KLICK_ENGINE_H */
