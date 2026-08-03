# AppRunner

A macOS notch utility, boring-notch-style: a Now Playing widget in a panel
sized to your Mac's actual physical notch, plus a real, standalone
terminal window (VT100/xterm-compatible, via
[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)) reachable from
the menu bar.

## What it does

- **Three notch states**, matching boring-notch's interaction model:
  - **Resting** — shown at all times otherwise: a small accent dot when
    nothing's playing, or a small artwork thumbnail + tiny waveform icon
    when something is. Wider than the *real* physical notch footprint
    (via `NSScreen.safeAreaInsets` + `auxiliaryTopLeftArea`/
    `auxiliaryTopRightArea`, public APIs, macOS 12+) rather than exactly
    matching it — content painted at the notch's own exact bounds doesn't
    actually render (that strip is reserved for the camera housing), so
    resting always extends into the definitely-visible menu bar area on
    either side. Same height as the notch/menu bar row, no extra padding
    there. **Drag it** (past a small threshold, so ordinary clicks still
    register) to park it anywhere on screen — position is persisted.
  - **Preview** — hovering while something's playing: a wider, taller card
    (side padding is a setting) with title/artist, a progress track with
    elapsed/remaining time, and prev/play-pause/next controls.
  - **Open** — single-click: the Media / Settings tabbed panel.
    Double-clicking is an explicit no-op.
- **Hides during fullscreen apps** — same as the real menu bar. Two
  independent checks, either triggers it: Accessibility's `AXFullScreen`
  attribute on the frontmost window (needs Accessibility permission,
  prompted for on launch), and a permission-free fallback via
  `CGWindowListCopyWindowInfo` that flags any normal-layer window whose
  bounds cover the entire screen. Works even if Accessibility access was
  never granted.
- **Real terminal, in its own window** — SwiftTerm's `LocalProcessTerminalView`:
  proper ANSI/VT100 emulation, scrollback, mouse reporting, resizing — a
  real terminal (like Ghostty or VS Code's integrated terminal), not a raw
  text log. Runs your login shell (`$SHELL -il`). Opens as a normal,
  resizable window (menu bar → "Open Terminal"), not tucked into the small
  notch panel. Ten built-in themes: Ghostty Dark, Dracula, Solarized Dark,
  Solarized Light, Nord, One Dark, Monokai, Gruvbox Dark, Tokyo Night,
  Catppuccin Mocha.
- **Now Playing** — system-wide now-playing info (title/artist/artwork/
  progress) with play/pause/skip, plus a **preferred source** setting:
  pick Music/Spotify/Chrome/Safari/Podcasts/TV/a custom bundle ID, and the
  widget only shows when that app is the one currently playing. Backed by
  [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) —
  the same workaround real boring-notch uses for the MediaRemote lockdown
  Apple added around macOS 15.4/Tahoe (see below) — with the older direct
  approach as a fallback.
- **Notch customization** — accent color, corner radius, hover-bar side
  padding, open-panel width/height, and position (drag or reset), all
  persisted.
- **Global hotkey** — ⌥ Space shows/hides the whole notch panel.

AppRunner runs as an accessory app (`LSUIElement`) with no Dock icon,
reachable from its menu bar status item — "Open Terminal" opens the
standalone terminal window, "Open Media"/"Open Settings" jump the notch
panel straight to that tab.

## Project layout

```
Package.swift                         SwiftPM manifest — depends on SwiftTerm
Sources/AppRunner/
  AppRunnerApp.swift                   App entry point + status item + hotkey wiring
  Hotkey/HotKeyManager.swift           Carbon global hotkey (⌥ Space)
  Notch/NotchPanel.swift               Borderless floating NSPanel
  Notch/NotchGeometry.swift            Shared resting/preview/open sizing
  Notch/NotchController.swift          Fixed-size backing window; fullscreen-aware visibility
  Notch/NotchNavigator.swift           Lets the status bar menu open a specific tab directly
  Notch/NotchContentView.swift         Drives the three states from playback/hover/click/drag
  Notch/NotchHoverBar.swift            Compact resting-state now-playing bar
  Notch/NotchPreviewCard.swift         Hover preview card (progress, time, transport controls)
  Notch/FullScreenMonitor.swift        Polls AXFullScreen to hide the notch in fullscreen apps
  Notch/AccessibilityPermission.swift  Accessibility permission check/prompt
  Notch/NotchSettingsStore.swift       Persisted customization + now-playing source
  Notch/NotchSettingsView.swift        Settings tab UI
  Terminal/TerminalHostView.swift      NSViewRepresentable wrapping SwiftTerm
  Terminal/TerminalPaneView.swift      Terminal + theme picker content
  Terminal/TerminalWindowController.swift  Standalone resizable terminal window
  Terminal/TerminalTheme.swift         Built-in color schemes
  MediaRemote/MediaRemoteBridge.swift  Now-playing source: adapter first, direct dlopen fallback
  MediaRemote/MediaRemoteAdapterProcess.swift  Spawns + streams the bundled mediaremote-adapter helper
  MediaRemote/NowPlayingModel.swift    SwiftUI wrapper + source filtering
  MediaRemote/NowPlayingFullView.swift Media tab UI (full controls)
Resources/Info.plist, *.entitlements
Scripts/bundle.sh                     Builds the SPM binary into a signed .app
Scripts/build-mediaremote-adapter.sh  Clones + builds mediaremote-adapter, stages it into the bundle
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

## Now Playing on macOS 15.4+ / Tahoe

Apple added entitlement verification to the MediaRemote daemon around macOS
15.4, so a plain third-party `dlopen` of `MediaRemote.framework` (the
original approach) stops getting real data back — `MRMediaRemoteGetNowPlayingInfo`'s
callback fires with an empty dictionary even while something is actively
playing. Real boring-notch hit the same wall and fixed it with
[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter): run
`/usr/bin/perl` — a system binary that *does* carry the required
entitlement — loading a small helper framework into it, which prints
now-playing updates as JSON to stdout. AppRunner does the same thing:

- `Scripts/build-mediaremote-adapter.sh` clones and builds it (CMake) as
  part of `Scripts/bundle.sh`, staging `MediaRemoteAdapter.framework` +
  `mediaremote-adapter.pl` into `AppRunner.app/Contents/Resources/MediaRemoteAdapter/`.
  This step is non-fatal — no network/cmake just means Now Playing falls
  back to the direct approach, the rest of the app builds fine either way.
- At runtime, `MediaRemoteAdapterProcess` spawns
  `perl mediaremote-adapter.pl MediaRemoteAdapter.framework stream` and
  parses its JSON-lines output (each line's `payload` keys are merged into
  the last-known state, since updates are diffs, not full snapshots).
- If the helper isn't bundled or fails to launch, `MediaRemoteBridge` falls
  back to the original direct-dlopen polling approach automatically.
- Playback commands (play/pause/skip) still go through the direct
  `MRMediaRemoteSendCommand` dlsym either way — the adapter project only
  covers reading now-playing info, not sending commands, so those may
  still be unreliable on locked-down macOS versions even with this fix.

## Notes / limitations

- The now-playing progress track is read-only (no click-to-seek yet).
- The notch's backing window is a fixed size (big enough for the open
  panel) positioned at top-center, so clicks in the small transparent
  margin around the pill/hover-bar shape don't pass through to whatever's
  underneath — same small dead zone the real system notch already creates
  in that spot, not a new one.
- Not sandboxed (SwiftTerm's local process support requires it) and not
  notarized — this ad-hoc-signed build is meant for local use and CI
  verification, not distribution outside your own Mac.
- Requires macOS 14 (Sonoma) or later.
