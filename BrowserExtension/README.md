# AppRunner Quick Actions (Chrome extension)

A movable, editable floating icon that sits on the right side of any page,
plus one-click docked windows for ChatGPT/Claude/Gemini and a "send this
page" action.

## What it does

- **Floating icon** — appears on every regular page (not on the assistant
  sites themselves). Drag it up/down; position is remembered per-browser via
  `chrome.storage.sync`.
- **Editable quick actions** — click the extension's toolbar icon to
  rename, remove, or add actions (each action is either "open a URL" or the
  built-in "open ChatGPT/Claude/Gemini" / "send page to assistant" types).
- **Toggle on/off** — the same popup has a checkbox that hides the floating
  icon entirely, live, without reloading pages.
- **Docked assistant windows** — clicking ChatGPT/Claude/Gemini in the
  floating menu opens that site in a real, separate popup window docked to
  the right edge of your screen, where you log in exactly as you normally
  would (this is a real top-level window, not an iframe — those sites block
  iframe embedding, so a true "inline sidebar" isn't possible).
- **Send page to assistant** — extracts the current page's visible text and
  drops it into the prompt box of whichever assistant window you already
  have open, via a small content script scoped only to those three sites.

## Why no auto-reading iframe

ChatGPT, Claude, and Gemini all send `frame-ancestors`/`X-Frame-Options`
headers that block being embedded in another page's iframe — that's a
deliberate security control on their end, not something a browser extension
can or should bypass. Docked popup windows + explicit "send this page" is
the closest legitimate equivalent.

## Installing (unpacked, for development)

1. `chrome://extensions` → enable **Developer mode**.
2. **Load unpacked** → select this `BrowserExtension/` folder.
3. Pin the toolbar icon to toggle/edit quick actions.

## Files

```
manifest.json          MV3 manifest, permissions, content script matches
background.js          Opens docked windows, relays "send context" messages
floating-button.js/css Draggable icon + quick-actions menu (all pages)
assistant-inject.js    Inserts sent text into ChatGPT/Claude/Gemini's prompt box
popup.html/popup.js    Toolbar popup: enable toggle + quick-actions editor
```
