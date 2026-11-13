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
    float volume;               /* volume of the section (of the count-in for its beats), 1 for the simple metronome */
    int32_t count_in;           /* 1 for a beat of the count-in; then 'section' is 0 and 'bar' counts from 0 */
    int32_t count_in_left;      /* beats of the count-in still to come, this one included (0 outside the count-in) */
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
    const float *tempi;         /* NULL, or one tempo per beat of the section (then 'tempo' and 'tempo_end' are ignored) */
    int32_t tempo_count;        /* number of values in 'tempi': bars * beats, and the section must have a number of bars */
} KlickSection;

/* Where the audio goes. The engine does not know CoreAudio or JACK: it talks to a backend, an object of klick that derives from
 * AudioInterface (C++, see audio_interface.hh of klick) and the few functions below. CoreAudio and the offline engine of
 * klick_engine_create are two backends of this kind; another one (JACK, in another library) is passed to
 * klick_engine_create_with_backend. The structure is copied; the engine owns 'audio' from the call on. */
typedef struct KlickBackend {
    const char *id;                     /* "coreaudio", "offline", "jack", ...; a string that stays valid */
    void *audio;                        /* the AudioInterface of the backend, as a void pointer */
    int realtime;                       /* 1 when the backend has an audio thread of its own, 0 when nothing runs unless asked */
    void (*start)(void *audio);         /* opens the stream once the engine has set its process callback; may be NULL */
    void (*stop)(void *audio);          /* may be NULL; called before destroy */
    void (*destroy)(void *audio);       /* called once, after the metronomes are gone; may be NULL */
    uint32_t (*output_latency)(void *audio);   /* frames between a block being handed over and heard; may be NULL (0) */
    int (*is_shutdown)(void *audio);    /* 1 when the backend has stopped (a JACK server that is gone); may be NULL (0) */
} KlickBackend;

/* Creates an engine on a backend. Returns NULL and writes to 'error' on failure; the backend is destroyed in that case too, so
 * the caller never destroys it after the call. The engine works at the sample rate of the backend. */
KlickEngine *klick_engine_create_with_backend(const KlickBackend *backend, char *error, size_t error_size);
/* The id of the backend, and its AudioInterface (for the functions of the library that provided the backend). */
const char *klick_engine_backend_id(const KlickEngine *);
void *klick_engine_backend_audio(const KlickEngine *);
/* 1 when the backend reports that it has stopped. */
int klick_engine_backend_is_shutdown(const KlickEngine *);

/* Creates an engine working at 'rate' Hz (0 for 48000). 'offline' = 0 plays on the default output device, CoreAudio
 * converting to the rate of the device (if it refuses, the engine works at the rate of the device: see
 * klick_engine_samplerate); 1 renders only when klick_engine_render is called (tests). Returns NULL on failure. */
KlickEngine *klick_engine_create(int offline, uint32_t rate, char *error, size_t error_size);
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

/* Count-in played before the next starts: 'bars' bars of 'beats_per_bar' beats (0 bars for none), at the tempo and the beat
 * unit of the start of the metronome or of the first section. The first beat of each bar is an accent. Its beats are
 * reported like the others (count_in = 1); 'volume' 0 makes it silent (visual only), about 0.66 audible. The main
 * metronome begins exactly when it ends. */
int klick_engine_set_countin(KlickEngine *, int32_t bars, int32_t beats_per_bar, float volume, char *error, size_t error_size);

int klick_engine_start(KlickEngine *, KlickMode mode, char *error, size_t error_size);
void klick_engine_stop(KlickEngine *);
/* 1 while something plays; a tempo map that has reached its end is no longer playing. */
int klick_engine_is_playing(const KlickEngine *);

/* Frames handed to the output so far (the same scale as KlickBeat.frame). A beat is heard when this, minus the latency of
 * the output, reaches its frame. */
uint64_t klick_engine_position(const KlickEngine *);
/* Frames between a block being handed to the output and being heard; asks the system (do not call it every frame of the
 * display). 0 for offline engines. */
uint32_t klick_engine_output_latency(const KlickEngine *);

/* The output device in use (an AudioDeviceID); 0 for offline engines. */
uint32_t klick_engine_output_device(const KlickEngine *);
/* Plays on 'device' (an AudioDeviceID), or, for 0, on the output device of the system, which is then followed (see below).
 * Can be called while it plays: the output is interrupted for a moment. Returns 0 and writes to 'error' if the device cannot be
 * used; the previous one then stays. Offline engines ignore it. */
int klick_engine_set_output_device(KlickEngine *, uint32_t device, char *error, size_t error_size);
/* When following the system: moves to its output device if it is not the one in use. Returns 1 if the output changed, 0 if not,
 * -1 on failure. Call it now and then from one thread (the control thread). */
int klick_engine_follow_system_output(KlickEngine *, char *error, size_t error_size);

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
