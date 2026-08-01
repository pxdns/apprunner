// Runs only on chatgpt.com / claude.ai / gemini.google.com. Listens for the
// background worker's "insert-text" message and drops the text into
// whichever prompt box that site currently shows. Selectors are best-effort
// since these are third-party sites that change their markup over time —
// this fails silently (falls back to clipboard) rather than breaking the
// page if a selector goes stale.
const PROMPT_SELECTORS = [
  "#prompt-textarea",                       // ChatGPT
  "div[contenteditable='true']",            // Claude / Gemini rich-text box
  "textarea[placeholder]"                    // generic fallback
];

function findPromptBox() {
  for (const selector of PROMPT_SELECTORS) {
    const el = document.querySelector(selector);
    if (el) return el;
  }
  return null;
}

function insert(text) {
  const box = findPromptBox();
  if (!box) {
    navigator.clipboard?.writeText(text);
    return;
  }

  box.focus();
  if (box.tagName === "TEXTAREA") {
    const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value").set;
    setter.call(box, text);
    box.dispatchEvent(new Event("input", { bubbles: true }));
  } else {
    box.innerText = text;
    box.dispatchEvent(new InputEvent("input", { bubbles: true }));
  }
}

chrome.runtime.onMessage.addListener((message) => {
  if (message.type === "insert-text") {
    insert(message.text);
  }
});
