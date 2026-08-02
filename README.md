# AppRunner

A macOS notch utility: a real, VT100/xterm-compatible terminal (via
[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)) that lives in a
customizable panel sized to match your Mac's actual physical notch — hover
to expand, move away to collapse. Nothing else.

## What it does

- **Real terminal** — SwiftTerm's `LocalProcessTerminalView`: proper
  ANSI/VT100 emulation, scrollback, mouse reporting, resizing — a real
  terminal (like Ghostty or VS Code's integrated terminal), not a raw text
  log. Runs your login shell (`$SHELL -il`).
- **Terminal themes** — Ghostty Dark, Dracula, Solarized Dark, Nord, picked
  from a dropdown right under the terminal.
- **Notch-accurate sizing** — on a notched Mac (like the 2022 M2 MacBook
  Air), the collapsed pill is sized to the *actual* physical notch using
  `NSScreen.safeAreaInsets` + `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`
  (public APIs, macOS 12+) — not a guessed constant. On a non-notched
  display it falls back to a fixed pill size.
- **Notch customization** — a Settings tab in the expanded panel: accent
  color, corner radius, and expanded panel width/height, all persisted.
- **Global hotkey** — ⌥ Space toggles the notch from anywhere.

AppRunner runs as an accessory app (`LSUIElement`) with no Dock icon,
reachable from its menu bar status item (⌥Space to toggle, or the menu).

## Project layout

```
Package.swift                     SwiftPM manifest — depends on SwiftTerm
Sources/AppRunner/
  AppRunnerApp.swift               App entry point + status item + hotkey wiring
  Hotkey/HotKeyManager.swift       Carbon global hotkey (⌥ Space)
  Notch/NotchPanel.swift           Borderless floating NSPanel
  Notch/NotchController.swift      Real notch geometry, panel positioning/resizing
  Notch/NotchContentView.swift     Collapsed/expanded SwiftUI content
  Notch/NotchSettingsStore.swift   Persisted customization (accent/corner/size/theme)
  Notch/NotchSettingsView.swift    Settings tab UI
  Terminal/TerminalHostView.swift  NSViewRepresentable wrapping SwiftTerm
  Terminal/TerminalPaneView.swift  Terminal tab UI (terminal + theme picker)
  Terminal/TerminalTheme.swift     Built-in color schemes
Resources/Info.plist, *.entitlements
Scripts/bundle.sh                 Builds the SPM binary into a signed .app
.github/workflows/build.yml       CI: build + bundle + upload artifact
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

- Not sandboxed (SwiftTerm's local process support requires it) and not
  notarized — this ad-hoc-signed build is meant for local use and CI
  verification, not distribution outside your own Mac.
- Requires macOS 14 (Sonoma) or later.
