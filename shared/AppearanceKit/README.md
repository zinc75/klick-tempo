# AppearanceKit

The look settings shared by the Jack Apps Collection for macOS interfaces, as a Swift package (macOS 15, SwiftUI).

- `AppearanceSettings`: the choices kept between two launches. The look is dark (the default), the one of the system, or light. The accent is the colour of the application, the one of macOS, or one of six system colours (blue, purple, pink, red, orange, green). Each application gives its own colour.
- `AppearanceSettingsView`: the content of a settings window, with the look as a segmented control and the accent as a row of swatches.
- `View.appAccent(_:)`: gives a window the accent that was chosen. It leaves the accent of macOS when the user follows the system.

Licence: MIT (see `LICENSE`), so that applications of any licence can use it.
