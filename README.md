# AppRunner

A compact macOS menu-bar launcher. Instead of Dock icons, Spotlight, and a
separate Terminal window, most of it lives in one small notch-style panel
pinned to the top of the screen — similar in spirit to "boring notch" utilities
— plus a normal, visible window on launch so it's never ambiguous whether the
app is actually running.

## What it does

- **Main window** — opens automatically on launch (also reachable from the
  menu bar item → "Show AppRunner Window"): the same Apps/Terminal/Media/Menu
  tabs as the notch, in a normal resizable titled window, with a Settings
  sheet. This is the primary, obvious way to use AppRunner; the notch below
  is an optional hover shortcut on top of it.
- **Launcher** — scans `/Applications`, `/System/Applications`, and `~/Applications`,
  and shows a compact searchable icon grid. Launching an app through AppRunner
  registers it with AppRunner, which then shows a "running" chip strip so you
  can jump back to or quit an app without touching the Dock.
- **Pin / favorites** — right-click any app and pin it so it always sorts first
  in the grid.
- **Renamed shortcuts** — right-click any app → "Create Renamed Shortcut…" to
  generate a tiny wrapper `.app` with a custom name and icon. Since macOS shows
  the *running app's own* name next to the Apple menu, this shim (not a full
  copy of the real app) is what actually changes what appears there and in the
  Dock, without duplicating the target app's disk footprint.
- **Notch panel** — a slim black pill sits under the menu bar, with a live
  CPU/RAM strip. Hover to expand it into Apps/Terminal/Media tabs; move away
  and it collapses back down.
- **Global hotkey** — ⌥ Space toggles the notch from anywhere, no mouse trip
  to the top of the screen required.
- **Terminal** — a real pseudo-terminal (`openpty` + your login shell) embedded
  in the panel, so you can run quick commands without switching apps.
- **Now Playing** — system-wide media info (title/artist/artwork) with
  play/pause/skip controls, via the same private MediaRemote framework
  technique other notch utilities use.
- **Launch at login** — toggle in Preferences (⌘, from the menu bar item),
  backed by `SMAppService`.
- **Menu bar editor** — the "Menu" tab lets you hide or rename the frontmost
  app's own menu bar items, including its bold application-name menu (e.g.
  "Chrome" next to the Apple icon), not just File/Edit/View. It works by
  reading the target app's real menu via the Accessibility API, painting a
  blank or relabeled patch over specific items with a floating overlay
  window, and swallowing clicks on hidden items with a CGEventTap — all
  public, permission-gated APIs. It never edits the target app's bundle, so
  there's no code-signature breakage and nothing to "corrupt"; disabling a
  rule (or quitting AppRunner) restores the real menu bar instantly.

AppRunner runs as an accessory app (`LSUIElement`) with no Dock icon; it's
reachable from its menu bar status item.

## Project layout

```
Package.swift                        SwiftPM manifest (executable target, macOS 14+)
Sources/AppRunner/
  AppRunnerApp.swift                  App entry point, status item, hotkey wiring
  MainWindow/MainWindowController.swift  Normal visible window shown on launch
  MainWindow/MainWindowView.swift     Tabbed content (Apps/Terminal/Media/Menu) + Settings sheet
  Launcher/AppLibrary.swift           App discovery, pinning, running-app tracking
  Launcher/LauncherView.swift         Searchable icon grid + running strip + context menu
  Shortcuts/AppShortcutBuilder.swift  Builds renamed wrapper .app shortcuts
  Terminal/ShellSession.swift         openpty-backed shell process
  Terminal/TerminalView.swift         Terminal UI
  Notch/NotchPanel.swift              Borderless floating NSPanel
  Notch/NotchContentView.swift        Collapsed/expanded SwiftUI content, stat strip
  Notch/NotchController.swift         Positions & resizes the panel
  Hotkey/HotKeyManager.swift          Carbon global hotkey (⌥ Space)
  System/SystemMonitor.swift          Mach-based CPU/RAM polling
  MediaRemote/MediaRemoteBridge.swift Private MediaRemote.framework bridge
  MediaRemote/NowPlayingView.swift    Now-playing widget
  Preferences/                        Preferences window + SMAppService login item
  MenuBar/MenuBarInspector.swift      Reads another app's real menu bar via Accessibility
  MenuBar/MenuBarOverlayController.swift  Floating patch window over hidden/renamed items
  MenuBar/MenuBarClickGuard.swift     CGEventTap that swallows clicks on hidden items
  MenuBar/MenuBarEditorView.swift     Menu bar hide/rename editor UI
Resources/Info.plist, *.entitlements
Scripts/bundle.sh                    Builds the SPM binary into a signed .app
BrowserExtension/                    Companion Chrome extension (see its own README)
.github/workflows/build.yml          CI: build + bundle + upload both artifacts
```

## Companion browser extension

`BrowserExtension/` is a separate Manifest V3 Chrome extension — a movable,
editable floating quick-actions icon on every page, plus one-click docked
ChatGPT/Claude/Gemini windows and a "send this page's text to whichever
assistant window is open" action. It's unrelated to the Swift build (no
toolchain needed) and ships as its own CI artifact. See
`BrowserExtension/README.md` for details, including why it opens real
windows instead of an inline iframe (those sites block iframe embedding).

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

- The terminal is intentionally minimal: it streams raw pty output without
  ANSI/VT100 rendering, so it's best for quick commands rather than
  full-screen TUIs.
- The Now Playing widget uses `MediaRemote.framework`, a private Apple
  framework loaded via `dlopen`/`dlsym` (no header, no link-time dependency).
  Symbol lookups fail gracefully if Apple changes the ABI in a future OS —
  the widget just shows "Nothing playing" instead of crashing.
- Renamed shortcuts live in `~/Applications/AppRunner Shortcuts/` and are
  unsigned, tiny (script-based) `.app` bundles that call `open -b
  <bundle-id>` on the real target — they don't duplicate the target app.
- Not sandboxed and not notarized — this ad-hoc-signed build is meant for
  local use and CI verification, not distribution outside your own Mac.
- The menu bar editor needs Accessibility access (System Settings → Privacy
  & Security → Accessibility), prompted for on first launch. Hidden items
  are still reachable via full keyboard access (Control+F2) since only
  mouse clicks over their frame are swallowed — that's an intentional,
  narrow scope rather than a global input block.
- Requires macOS 14 (Sonoma) or later.
