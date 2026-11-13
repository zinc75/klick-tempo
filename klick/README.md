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

One patch in `patches/`: `KLICK_DATA_DIR` overrides the sounds directory compiled in, so an application can ship the sounds in its bundle. Nothing else needed to change for macOS.

## Layout

- `upstream/`: the original sources, never edited (changes go to `patches/` or to new files).
- `patches/`: changes to the upstream sources, as unified diffs that apply with `git apply` from the `upstream/` directory.
- `build_universal.sh`: builds the universal binary.
