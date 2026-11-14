# MatrixKit

The look and the building blocks of the source matrix of the Jack Apps Collection for macOS interfaces, as a Swift package (macOS 15, SwiftUI; Liquid Glass on macOS 26 with a close fallback on macOS 15).

- `Glass.swift`: `GlassSupport`, `blockBackground()` (a block of glass, tinted a little in both appearances), `softScrollEdges()`, `fieldOutline()` and the colours of the windows and of the alerts.
- `Badge.swift`: `BadgeStyle` (two letters and a gradient computed from a client name, with the rules of the JackMate patchbay, so that a client has the same colour in every tool; violet with a loudspeaker for the hardware playback, cyan with a microphone for the capture), `BadgeView` (the real icon of an application when its bundle identifier is known, the colour picto of JackMoebius for its shared input), `BadgeStack`.
- `AppIcons.swift` and `Resources/JackMoebiusPicto.png`: the icons of applications and the picto of JackMoebius.
- `Dot.swift`: `LED`, the point of the matrix (glass that gives under the click, lit and unlit looks, glow, hover).
- `Scroll.swift`: the parts of a matrix with frozen panes, as in a spreadsheet: `MatrixScroll` and `ScrollFollower` (the heads and the names follow the scroll of the dots), `WheelBridge` (the wheel over the panes scrolls the dots), `MatrixHover` and `HoverReader` (the point under the pointer lights its row and its column without rebuilding the view), `TextWidth`, `columnRule()`.

The package knows nothing about JACK ports or about any tool: the application gives it names and booleans.

Licence: MIT (see `LICENSE`), so that applications of any licence can use it. The picto of JackMoebius (`Resources/JackMoebiusPicto.png`) is the logo of JackMoebius, © Éric Bavu, and is not covered by that licence. The code was written for the `jack_capture` interface, whose own files are under the licence of `jack_capture`; this package contains none of that code. Contributions to this directory are accepted under the MIT licence.

The AppKit parts (`WheelBridge`, `TextWidth`, the colours built from `NSColor`) have to be guarded by `#if os(macOS)` before the package can be used on iOS.
