// Injected on every regular page: draggable floating button + its
// quick-actions menu. Position and action list are read from
// chrome.storage.sync so the popup's editor updates this live.
(() => {
  if (window.top !== window.self) return; // skip iframes

  let root, button, menu;
  let dragged = false;

  function build() {
    root = document.createElement("div");
    root.id = "apprunner-fab-root";

    button = document.createElement("div");
    button.id = "apprunner-fab-button";
    button.textContent = "⚡";
    button.title = "AppRunner quick actions (drag to move)";

    menu = document.createElement("div");
    menu.id = "apprunner-fab-menu";

    root.appendChild(menu);
    root.appendChild(button);
    document.documentElement.appendChild(root);

    attachDrag();
    button.addEventListener("click", (event) => {
      if (dragged) { dragged = false; return; }
      event.stopPropagation();
      menu.classList.toggle("open");
    });
    document.addEventListener("click", () => menu.classList.remove("open"));
  }

  function attachDrag() {
    let startY = 0;
    let startTop = 0;
    let pointerDown = false;

    button.addEventListener("mousedown", (event) => {
      pointerDown = true;
      dragged = false;
      startY = event.clientY;
      startTop = root.getBoundingClientRect().top;
      event.preventDefault();
    });

    window.addEventListener("mousemove", (event) => {
      if (!pointerDown) return;
      const delta = event.clientY - startY;
      if (Math.abs(delta) > 4) dragged = true;
      const newTop = Math.min(window.innerHeight - 60, Math.max(20, startTop + delta));
      root.style.top = `${newTop}px`;
      root.style.transform = "none";
    });

    window.addEventListener("mouseup", () => {
      if (!pointerDown) return;
      pointerDown = false;
      if (dragged) {
        const middleOffset = root.getBoundingClientRect().top + 22 - window.innerHeight / 2;
        chrome.storage.sync.set({ position: { xFromRight: 24, yFromMiddle: middleOffset } });
      }
    });
  }

  function applyPosition(position) {
    if (!root || !position) return;
    root.style.right = `${position.xFromRight ?? 24}px`;
    root.style.top = `calc(50% + ${position.yFromMiddle ?? 0}px)`;
    root.style.transform = "translateY(-50%)";
  }

  function renderActions(actions) {
    if (!menu) return;
    menu.innerHTML = "";
    for (const action of actions ?? []) {
      const item = document.createElement("button");
      item.className = "apprunner-fab-item";
      item.textContent = action.label;
      item.addEventListener("click", () => runAction(action));
      menu.appendChild(item);
    }
  }

  function runAction(action) {
    menu.classList.remove("open");
    if (action.type === "assistant") {
      chrome.runtime.sendMessage({ type: "open-assistant", url: action.url });
    } else if (action.type === "send-context") {
      chrome.runtime.sendMessage({ type: "send-context", text: extractPageText() });
    } else if (action.type === "open-url") {
      window.open(action.url, "_blank");
    }
  }

  /// Cheap, dependency-free "readable text" extraction: strips script/style/
  /// nav-ish noise and caps length so we're not shipping an entire page.
  function extractPageText() {
    const clone = document.body.cloneNode(true);
    clone.querySelectorAll("script, style, nav, footer, noscript, svg").forEach(el => el.remove());
    const text = clone.innerText.replace(/\n{3,}/g, "\n\n").trim();
    const header = `Page: ${document.title}\nURL: ${location.href}\n\n`;
    return (header + text).slice(0, 8000);
  }

  function init() {
    chrome.storage.sync.get(["enabled", "actions", "position"], (data) => {
      if (data.enabled === false) return;
      build();
      applyPosition(data.position);
      renderActions(data.actions);
    });
  }

  chrome.storage.onChanged.addListener((changes) => {
    if (changes.enabled) {
      if (changes.enabled.newValue === false) {
        root?.remove();
        root = undefined;
      } else if (!root) {
        init();
      }
    }
    if (changes.position) applyPosition(changes.position.newValue);
    if (changes.actions) renderActions(changes.actions.newValue);
  });

  init();
})();
