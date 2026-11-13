# klick

`klick`, the command-line metronome for JACK by Dominic Sacré, built for macOS (arm64 and x86_64).

It plays a metronome at a given tempo and meter, follows a tempo map read from a file (sections with their own meter, tempo or tempo ramp, accents and volume), can follow the JACK transport, takes OSC commands, and exports its click track to a WAV, FLAC or Ogg file.

## Build

The libraries come first, each with its own script in `libs/`: libsndfile and its codecs (FLAC, Ogg, Vorbis, Opus, LAME, mpg123), liblo, libsamplerate and Rubber Band. Then:

```
klick/build_universal.sh
```

It needs the Xcode command line tools and [JACK](https://jackaudio.org/downloads/) installed (`JACK_PREFIX`, default `/usr/local`). The result is in `klick/build/`: the universal `klick` binary (macOS 11.0 minimum), `libklick.a` (the engine without `main.cc`) and the eight sounds in `samples/`.

klick looks for its sounds in `/usr/local/share/klick/samples`, or in the directory named by `KLICK_DATA_DIR` if that variable is set.

## Upstream

| | |
|---|---|
| Project | klick |
| Author | Dominic Sacré |
| Source | https://github.com/dsacre/klick |
| Version | commit `c05071081165e2bab66fb839a128925cd361d939` (2015-03-29, branch `master`), `SConstruct` says 0.13.0-pre |
| Copy here | `upstream/` = a `git clone` of the commit above with its `.git` removed (2026-11-04), **unmodified** |

## Licence

GPL-2.0-or-later (`COPYING` is the GPL v2; the source headers say "version 2 … or (at your option) any later version").

Dependencies: JACK, libsndfile, libsamplerate, liblo (OSC), Rubber Band (pitch of the sounds), and a few Boost headers (`libs/boost`).

## State on macOS

`klick` runs on arm64 and x86_64. The binary links its libraries statically; its only dynamic dependencies are the system libraries, the Accelerate framework and `libjack` (full path, `/usr/local/lib`). Exports to a file are identical on both architectures.

Tested on macOS, on arm64 and on x86_64 (under Rosetta).

### Patches

Four patches in `patches/`, none of which changes what the `klick` program does (its exports are byte for byte the same with and without them). Nothing else needed to change for macOS.

- `0001`: `KLICK_DATA_DIR` overrides the sounds directory compiled in, so an application can ship the sounds in its bundle.
- `0002`: an optional callback that reports every beat (section, bar, beat, tempo, accent) from the audio thread, for a program that embeds the engine.
- `0003`: the tempo map metronome tests for the generic transport interface instead of the JACK class, so the engine links without libjack.
- `0004`: the simple metronome can start after a delay, so that a count-in played beside it ends exactly when it begins.

## Layout

- `upstream/`: the original sources, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
- `build_universal.sh`: builds the universal binary.
- `engine/`: the engine as a library: a CoreAudio backend (`AudioInterfaceCoreAudio`), a C interface (`klick_engine.h`), `build_engine.sh`, and test programs with `build_tests.sh`.
- `swiftui/`: the Swift package of the Klick application (the engine so far), see its README.
