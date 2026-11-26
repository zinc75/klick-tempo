# UpdateKit

Looks for a newer release of a tool on GitHub, downloads its package, checks it and opens it in the Installer. macOS 15, MIT licence.

## What it does

The releases of the collection live in one repository, with a tag for each tool: `jack_capture-v0.9.73-macOS-6` is version 0.9.73 of the tool, revision 6 of its macOS edition (`-macOS` alone is revision 1). The kit reads the list of releases of the repository, keeps those whose tag begins with the prefix of the tool, and takes the newest by number (the "latest release" of GitHub is the newest of any tool, so it is not used). A draft, a pre-release and a release without a `.pkg` are left out. It compares that version and revision with the ones of the running application (`CFBundleShortVersionString` and `JACRevision`, written by the build).

The check is made once a day at most, a few seconds after launch, and when the person chooses "Check for Updates…". The answer is kept for a day. A newer version opens a panel with "Skip This Version", "Later" and "Download and Install"; "no network" and "up to date" stay silent when the check was automatic. A checkbox in the panel turns the automatic check off.

Nothing is installed silently. The package is downloaded to the temporary folder of the user, and three things are checked before it is opened:

1. the SHA-256 that is published next to it (`<package>.sha256`), which tells a damaged download;
2. `pkgutil --check-signature`: signed with a Developer ID Installer certificate of the team of the author, and notarized;
3. `spctl --assess --type install`: Gatekeeper accepts it.

Then the package opens in the Installer, which asks for the password, and the panel offers to quit the application. An application that records or plays something says so (`isBusy`) and the installation waits until it stops.

The only request that is made is the list of releases on `api.github.com`, with no identifier.

## What a tool gives

```swift
let updates = UpdateController(
    configuration: UpdateConfiguration(
        appName: "Jack Capture",
        repository: "zinc75/jack-apps-collection-macos",
        tagPrefix: "jack_capture-v",
        isBusy: { sessions.anyRunning }),
    appearance: appearance)          // the AppearanceSettings of the application
updates.startAutomaticChecks()       // at launch
```

and, in the scene, `UpdateCommands(controller: updates)`, which adds "Check for Updates…" under "About". It goes in the `.commands` block of `CollectionMenus`, after it: `CollectionMenus` replaces the "About" group, which drops what an earlier `.commands` block has added to it.

The texts are looked up in the string catalog of the application, as those of the other kits are (the keys are the French texts). `Strings/Localizable.fragment.json` has them in French, English, German, Italian and Spanish; `python3 -I Strings/merge_strings.py <Localizable.xcstrings>` adds the ones a catalog does not have yet. The catalog must have "Fermer" and "révision" (the About panel needs them too).

## Development aids

Compiled in debug builds only:

- `UPDATEKIT_FEED=<file or address>`: the JSON that GitHub would give, instead of the real list (the answer kept is ignored);
- `UPDATEKIT_INSTALLED=0.9.73.5`: the version the application says it is, revision last;
- `UPDATEKIT_NO_OPEN=1`: do not open the Installer; `UPDATEKIT_ALLOW_UNSIGNED=1`: do not check the signature;
- `UPDATEKIT_MENU=1`: do at launch what the menu item does; `UPDATEKIT_AUTOINSTALL=1`: install the offer at launch.

## Tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

`PackageVerifierToolsTests` runs the real `pkgutil` and `spctl` on a package: give a signed and notarized one in `UPDATEKIT_SIGNED_PKG` and an unsigned one in `UPDATEKIT_UNSIGNED_PKG` (skipped without them).

## Licence

MIT, see `LICENSE`.
