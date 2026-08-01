const enabledToggle = document.getElementById("enabled-toggle");
const actionsList = document.getElementById("actions-list");
const addButton = document.getElementById("add-action");

let actions = [];

function load() {
  chrome.storage.sync.get(["enabled", "actions"], (data) => {
    enabledToggle.checked = data.enabled !== false;
    actions = data.actions ?? [];
    render();
  });
}

function render() {
  actionsList.innerHTML = "";
  actions.forEach((action, index) => {
    const row = document.createElement("div");
    row.className = "action-row";

    const label = document.createElement("input");
    label.type = "text";
    label.value = action.label;
    label.addEventListener("change", () => {
      actions[index].label = label.value;
      save();
    });

    const remove = document.createElement("button");
    remove.className = "icon";
    remove.textContent = "✕";
    remove.title = "Remove";
    remove.addEventListener("click", () => {
      actions.splice(index, 1);
      save();
      render();
    });

    row.appendChild(label);
    row.appendChild(remove);
    actionsList.appendChild(row);
  });
}

function save() {
  chrome.storage.sync.set({ actions });
}

enabledToggle.addEventListener("change", () => {
  chrome.storage.sync.set({ enabled: enabledToggle.checked });
});

addButton.addEventListener("click", () => {
  const url = prompt("URL to open for this quick action (e.g. https://example.com):");
  if (!url) return;
  actions.push({ id: `custom-${Date.now()}`, label: "New action", type: "open-url", url });
  save();
  render();
});

load();
