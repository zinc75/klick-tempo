# Klick: the Swift package

The Swift side of the Klick application: the engine of klick seen from Swift. The interface itself is not here yet.

## Build

You need Xcode (swift 6; `DEVELOPER_DIR` is set for the commands below, the global `xcode-select` setting is not changed) and [JACK](https://jackaudio.org/downloads/) installed (only its headers are used, nothing links against libjack). In this order:

```
libs/<name>/build_universal.sh          the libraries of klick (see klick/README.md)
klick/build_universal.sh                klick and libklick.a
klick/engine/build_engine.sh            klick/build/libklickengine.a, the engine as one static library
cd klick/swiftui
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
```

The tests use an engine that renders offline: no audio device, no sound. One more test plays on the default output device at volume 0, to check the audio thread, the changes made while playing and the delivery of the blocks; run it with `KLICK_TEST_DEVICE=1 swift test`.

## Structure

- `Sources/CKlickEngine`: the C interface of the engine (`klick_engine.h`) and the link settings of `libklickengine.a`.
- `Sources/KlickEngine`: the Swift view of it (`Engine`, `Section`, `Beat`): playback, tempo map, beat events.
- `Sources/KlickKit`: what the application knows, without any UI: tempo map files and documents, tap tempo, meters, settings, the equivalent command line.
- `Tests/KlickEngineTests`, `Tests/KlickKitTests`: unit tests.
