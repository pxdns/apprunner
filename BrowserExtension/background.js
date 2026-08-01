// Service worker: owns default settings, opens docked assistant windows,
// and relays "insert this page's text" requests to whichever assistant
// window/tab is currently open.

const DEFAULT_ACTIONS = [
  { id: "chatgpt", label: "ChatGPT", type: "assistant", url: "https://chatgpt.com/" },
  { id: "claude", label: "Claude", type: "assistant", url: "https://claude.ai/new" },
  { id: "gemini", label: "Gemini", type: "assistant", url: "https://gemini.google.com/app" },
  { id: "send-context", label: "Send page to assistant", type: "send-context" }
];

const ASSISTANT_HOSTS = ["chatgpt.com", "chat.openai.com", "claude.ai", "gemini.google.com"];

chrome.runtime.onInstalled.addListener(async () => {
  const stored = await chrome.storage.sync.get(["enabled", "actions", "position"]);
  const updates = {};
  if (stored.enabled === undefined) updates.enabled = true;
  if (!stored.actions) updates.actions = DEFAULT_ACTIONS;
  if (!stored.position) updates.position = { xFromRight: 24, yFromMiddle: 0 };
  if (Object.keys(updates).length) await chrome.storage.sync.set(updates);
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === "open-assistant") {
    openDockedAssistant(message.url);
    sendResponse({ ok: true });
    return true;
  }
  if (message.type === "send-context") {
    sendContextToAssistant(message.text);
    sendResponse({ ok: true });
    return true;
  }
});

async function openDockedAssistant(url) {
  const display = await chrome.system.display.getInfo().catch(() => null);
  const bounds = display?.[0]?.workArea ?? { left: 0, top: 0, width: 1440, height: 900 };
  const width = Math.round(bounds.width * 0.34);

  chrome.windows.create({
    url,
    type: "popup",
    left: bounds.left + bounds.width - width,
    top: bounds.top,
    width,
    height: bounds.height
  });
}

/// Finds a tab already on one of the assistant sites and asks its content
/// script (assistant-inject.js) to drop the given text into the prompt box.
async function sendContextToAssistant(text) {
  const tabs = await chrome.tabs.query({});
  const target = tabs.find(tab => {
    try {
      const host = new URL(tab.url ?? "").hostname;
      return ASSISTANT_HOSTS.includes(host);
    } catch {
      return false;
    }
  });

  if (!target) {
    chrome.notifications?.create({
      type: "basic",
      iconUrl: "icons/icon48.png",
      title: "No assistant window open",
      message: "Open ChatGPT, Claude, or Gemini from the quick-actions menu first."
    });
    return;
  }

  chrome.tabs.sendMessage(target.id, { type: "insert-text", text });
  chrome.tabs.update(target.id, { active: true });
  chrome.windows.update(target.windowId, { focused: true });
}
