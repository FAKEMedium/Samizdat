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
               value="${titles[lang.languageid] || ""}">
      </div>
    `).join("");
  }

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
