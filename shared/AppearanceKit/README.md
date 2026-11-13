# AppearanceKit

The look settings shared by the Jack Apps Collection for macOS interfaces, as a Swift package (macOS 15, SwiftUI).

- `AppearanceSettings`: the choices kept between two launches. The look is dark (the default), the one of the system, or light. The accent is the colour of the application, the one of the system, or one of six colours (blue, purple, pink, red, orange, green). Each application gives its own colour.
- `AppearanceModePicker` and `AccentSwatches`: the two controls, to put in the settings page of the application (three small windows for the look, a row of swatches for the accent), with `AccentChoice.displayName`.
- `View.appAccent(_:)` gives a window the accent that was chosen, as the environment value `appAccentColor` (the accent of macOS when the user follows the system), which views read instead of `Color.accentColor`. `View.accentTint()` shows it on a control of the system (slider, switch, prominent button).

Licence: MIT (see `LICENSE`), so that applications of any licence can use it.
