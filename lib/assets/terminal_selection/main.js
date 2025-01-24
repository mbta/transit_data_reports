export function init(ctx, { terminals, groups }) {
  ctx.importCSS("main.css");

  const root = ctx.root;
  const container = document.createElement("div");
  container.className = "multiselect-container";

  root.append(container);

  const checkboxContainers = terminals.map(([id, { label, checked }]) => {
    const inputContainer = document.createElement("div");

    const inputEl = document.createElement("input");
    inputEl.type = "checkbox";
    inputEl.name = id;
    inputEl.id = id;
    inputEl.checked = checked;
    inputEl.addEventListener("click", (_event) => {
      ctx.pushEvent("toggle_terminal", id);
    });

    const labelEl = document.createElement("label");
    labelEl.htmlFor = id;
    labelEl.innerText = label;

    inputContainer.append(inputEl, labelEl);
    return inputContainer;
  });

  const groupCheckboxContainers = groups.map(([id, { label, checked, indeterminate }]) => {
    const inputContainer = document.createElement("div");

    const inputEl = document.createElement("input");
    inputEl.type = "checkbox";
    inputEl.name = id;
    inputEl.id = id;
    inputEl.checked = checked;
    inputEl.indeterminate = indeterminate;
    inputEl.addEventListener("click", (_event) => {
      ctx.pushEvent("toggle_group", id);
    });

    const labelEl = document.createElement("label");
    labelEl.htmlFor = id;
    labelEl.innerText = label;

    inputContainer.append(inputEl, labelEl);
    return inputContainer;
  });

  const groupContainer = document.createElement("div");
  groupContainer.className = "multiselect-group-container";
  groupContainer.style.marginBottom = "8px";

  if (groupCheckboxContainers.length > 0) {
    const groupsHeader = document.createElement("h3");
    groupsHeader.className = "multiselect-group-header";
    groupsHeader.innerText = "Stop Groups";
    const hr = document.createElement("hr");
    groupContainer.append(groupsHeader, ...groupCheckboxContainers, hr);
  } else {
    groupContainer.hidden = true;
  }

  const stopsHeader = document.createElement("h3");
  stopsHeader.className = "multiselect-stops-header";
  stopsHeader.innerText = "Stops";

  container.append(groupContainer, stopsHeader, ...checkboxContainers);

  ctx.handleEvent("update", ({ terminals, groups }) => {
    groups.forEach(([id, { checked, indeterminate }]) => {
      const input = document.getElementById(id);
      if (input) {
        input.checked = checked;
        input.indeterminate = indeterminate;
      }
    });

    terminals.forEach(([id, { checked }]) => {
      const input = document.getElementById(id);
      if (input) { input.checked = checked; }
    });
  });
};