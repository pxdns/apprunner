# AppRunner

A macOS notch utility, boring-notch-style: a real, VT100/xterm-compatible
terminal (via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)) and
a Now Playing widget, in a panel that starts sized to your Mac's actual
physical notch, gets wider on hover, and opens into a full panel on click.

## What it does

- **Three notch states**, matching boring-notch's interaction model:
  - **Closed** — sized to the *real* physical notch via `NSScreen.safeAreaInsets`
    + `auxiliaryTopLeftArea`/`auxiliaryTopRightArea` (public APIs, macOS 12+),
    not a guessed constant. On a non-notched display it falls back to a
    fixed pill size.
  - **Hover** — mouse over, not clicked: a wider bar (padding on each side
    is a setting) showing now-playing artwork, a progress track, and an
    animated waveform icon.
  - **Open** — click it: the full Terminal / Media / Settings tabbed panel.
- **Real terminal** — SwiftTerm's `LocalProcessTerminalView`: proper
  ANSI/VT100 emulation, scrollback, mouse reporting, resizing — a real
  terminal (like Ghostty or VS Code's integrated terminal), not a raw text
  log. Runs your login shell (`$SHELL -il`). Four built-in themes (Ghostty
  Dark, Dracula, Solarized Dark, Nord).
- **Now Playing** — system-wide now-playing info (title/artist/artwork/
  progress) with play/pause/skip, plus a **preferred source** setting:
  pick Music/Spotify/Chrome/Safari/Podcasts/TV/a custom bundle ID, and the
  widget only shows when that app is the one currently playing (see the
  caveat below on why this can silently stop working).
- **Notch customization** — accent color, corner radius, hover-bar side
  padding, and open-panel width/height, all persisted.
- **Global hotkey** — ⌥ Space shows/hides the whole notch panel.

AppRunner runs as an accessory app (`LSUIElement`) with no Dock icon,
reachable from its menu bar status item.

## Project layout

```
Package.swift                         SwiftPM manifest — depends on SwiftTerm
Sources/AppRunner/
  AppRunnerApp.swift                   App entry point + status item + hotkey wiring
  Hotkey/HotKeyManager.swift           Carbon global hotkey (⌥ Space)
  Notch/NotchPanel.swift               Borderless floating NSPanel
  Notch/NotchController.swift          Real notch geometry; closed/hover/open sizing
  Notch/NotchContentView.swift         Drives the three states from hover/click
  Notch/NotchHoverBar.swift            Hover-state now-playing bar
  Notch/NotchSettingsStore.swift       Persisted customization + now-playing source
  Notch/NotchSettingsView.swift        Settings tab UI
  Terminal/TerminalHostView.swift      NSViewRepresentable wrapping SwiftTerm
  Terminal/TerminalPaneView.swift      Terminal tab UI (terminal + theme picker)
  Terminal/TerminalTheme.swift         Built-in color schemes
  MediaRemote/MediaRemoteBridge.swift  Private MediaRemote.framework bridge
  MediaRemote/NowPlayingModel.swift    SwiftUI wrapper + source filtering
  MediaRemote/NowPlayingFullView.swift Media tab UI (full controls)
Resources/Info.plist, *.entitlements
Scripts/bundle.sh                     Builds the SPM binary into a signed .app
.github/workflows/build.yml           CI: build + bundle + upload artifact
```

## Building locally (macOS 14+, Xcode 15+)

```sh
swift build -c release
./Scripts/bundle.sh release   # produces dist/AppRunner.app
open dist/AppRunner.app
```

## Continuous integration

Every push builds on a `macos-14` GitHub Actions runner, assembles
`AppRunner.app`, ad-hoc signs it, and uploads it as the `AppRunner-macOS`
workflow artifact (zipped `.app`).

## Notes / limitations

- **Now Playing may not work at all on newer macOS.** `MediaRemote.framework`
  is private and undocumented; starting around macOS 15.4, Apple tightened
  what non-entitled third-party processes get back from it. Real
  boring-notch had to add a separate helper-process workaround for this.
  AppRunner just calls the private API directly (dlopen/dlsym, same as it
  always did) and fails silently — empty widget, not a crash — if your
  macOS version blocks it.
- The now-playing progress track is read-only (no click-to-seek yet).
- Not sandboxed (SwiftTerm's local process support requires it) and not
  notarized — this ad-hoc-signed build is meant for local use and CI
  verification, not distribution outside your own Mac.
- Requires macOS 14 (Sonoma) or later.
