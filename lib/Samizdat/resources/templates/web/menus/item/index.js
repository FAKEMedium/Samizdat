(async function () {
  const pathParts = window.location.pathname.split("/");
  const menuid = pathParts[pathParts.indexOf("menus") + 1];
  const menuitemid = pathParts[pathParts.indexOf("items") + 1];
  let languages = [];
  let titles = {};
  let allItems = [];

  async function loadItem() {
    const data = await window.authenticatedFetch(window.location.href);
    if (data) {
      languages = data.languages || [];
      allItems = data.allItems || [];
      const item = data.item || {};
      titles = {};
      (data.titles || []).forEach(t => { titles[t.languageid] = t.title; });

      document.querySelector("#itemPath").value = item.path || "";
      populateParents(item.parentid, item.menuitemid);
      renderTitleFields();
    }
  }

  function populateParents(currentParentId, currentItemId) {
    const select = document.querySelector("#parentSelect");
    // Filter out current item and its descendants
    const validParents = allItems.filter(item => {
      if (currentItemId && item.menuitemid == currentItemId) return false;
      // TODO: also filter descendants of current item
      return true;
    });

    select.innerHTML = `<option value=""><%= __('None (root level)') %></option>` +
      validParents.map(item =>
        `<option value="${item.menuitemid}" ${item.menuitemid == currentParentId ? "selected" : ""}>${item.title || "<%= __('Untitled') %> #" + item.menuitemid}</option>`
      ).join("");
  }

  function renderTitleFields() {
    const container = document.querySelector("#titleFields");
    container.innerHTML = languages.map(lang => `
      <div class="mb-3">
        <label class="form-label">${lang.title}</label>
        <input type="text" class="form-control title-input"
               data-languageid="${lang.languageid}"
               data-langcode="${lang.code}"
               value="${titles[lang.languageid] || ""}">
      </div>
    `).join("");
  }

  // Translate functionality using Anthropic API
  async function translateTitles() {
    const inputs = document.querySelectorAll(".title-input");
    let sourceInput = null;
    let sourceText = "";
    let sourceLangCode = "";

    // Find the first input with text as source
    for (const input of inputs) {
      if (input.value.trim()) {
        sourceInput = input;
        sourceText = input.value.trim();
        sourceLangCode = input.getAttribute("data-langcode");
        break;
      }
    }

    if (!sourceText) {
      window.showToast("<%= __('Enter a title first to translate from') %>", "warning");
      return;
    }

    const translateBtn = document.querySelector("#translateBtn");
    const originalBtnHtml = translateBtn.innerHTML;
    translateBtn.disabled = true;
    translateBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span><%= __("Translating...") %>';

    // Translate to each empty language field
    for (const input of inputs) {
      if (input === sourceInput) continue;
      if (input.value.trim()) continue; // Skip already filled fields

      const targetLangCode = input.getAttribute("data-langcode");
      if (!targetLangCode) continue;

      try {
        const result = await window.authenticatedFetch("<%= url_for('Web.translate') %>", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            markdown: sourceText,
            target_language: targetLangCode
          })
        });

        if (result && result.success && result.translated) {
          input.value = result.translated.trim();
        }
      } catch (err) {
        console.error(`Translation to ${targetLangCode} failed:`, err);
      }
    }

    translateBtn.disabled = false;
    translateBtn.innerHTML = originalBtnHtml;
    window.showToast("<%= __('Translation complete') %>");
  }

  document.querySelector("#translateBtn")?.addEventListener("click", translateTitles);

  // Form submission
  document.querySelector("#itemForm")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    
    const path = document.querySelector("#itemPath").value || null;
    const parentid = document.querySelector("#parentSelect").value || null;
    const itemTitles = {};
    document.querySelectorAll(".title-input").forEach(input => {
      const langid = input.getAttribute("data-languageid");
      if (input.value) {
        itemTitles[langid] = input.value;
      }
    });

    const url = menuitemid === "new"
      ? `<%= url_for('Web.menus.index') %>/${menuid}/items/`
      : `<%= url_for('Web.menus.index') %>/${menuid}/items/${menuitemid}`;

    try {
      const result = await window.authenticatedFetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ path, parentid, titles: itemTitles })
      });

      if (result && result.success) {
        window.showToast("<%= __('Item saved') %>");
        window.location.href = `<%= url_for('web_menus') %>/${menuid}`;
      } else {
        window.showToast(result?.error || "<%= __('Save failed') %>", "danger");
      }
    } catch (err) {
      console.error("Save error:", err);
      window.showToast("<%= __('Save failed') %>", "danger");
    }
  });

  // Delete button
  document.querySelector("#deleteItem")?.addEventListener("click", async () => {
    if (!confirm("<%= __('Are you sure you want to delete this item?') %>")) return;
    const apiUrl = `<%= url_for('Web.menus.index') %>/${menuid}/items/${menuitemid}`;
    const result = await window.authenticatedFetch(apiUrl, { method: "DELETE" });
    if (result && result.success) {
      window.location.href = `<%= url_for('web_menus') %>/${menuid}`;
    }
  });

  loadItem();
})();
