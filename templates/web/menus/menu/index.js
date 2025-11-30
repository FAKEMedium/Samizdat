(async function () {
  const menuid = window.location.pathname.split("/").pop();
  const universalModal = new bootstrap.Modal("#universalmodal");
  const modalDialog = document.querySelector("#universalmodal #modalDialog");
  let currentLanguageId = <%= web->languages->{language()} // 1 %>;
  let languages = [];
  let menuItems = [];

  async function loadMenu() {
    const data = await window.authenticatedFetch(`${window.location.href}?languageid=${currentLanguageId}`);
    if (data) {
      languages = data.languages || [];
      menuItems = data.items || [];
      populateLanguages();
      renderItems();
    }
  }

  function populateLanguages() {
    const select = document.querySelector("#languageSelect");
    select.innerHTML = languages.map(lang =>
      `<option value="${lang.languageid}" ${lang.languageid == currentLanguageId ? "selected" : ""}>${lang.title}</option>`
    ).join("");
    select.addEventListener("change", (e) => {
      currentLanguageId = e.target.value;
      loadMenu();
    });
  }

  function renderItems() {
    const container = document.querySelector("#menuItemsTree");
    const noItems = document.querySelector("#noItems");
    
    if (!menuItems.length) {
      container.innerHTML = "";
      noItems.classList.remove("d-none");
      return;
    }
    
    noItems.classList.add("d-none");
    container.innerHTML = "<ul>" + renderItemTree(menuItems) + "</ul>";
    attachItemHandlers();
  }

  function renderItemTree(items, parentId = null) {
    return items.map(item => {
      const children = item.items && item.items.length
        ? `<ul data-parentid="${item.menuitemid}">` + renderItemTree(item.items, item.menuitemid) + "</ul>"
        : "";
      return `
        <li data-itemid="${item.menuitemid}" draggable="true">
          <div class="item-row">
            <span class="drag-handle"><%== icon "grip-vertical", {} %></span>
            <span class="item-title">${item.title || "<em><%= __('No title') %></em>"}</span>
            <span class="item-path">${item.path || ""}</span>
            <span class="item-actions">
              <a href="<%= url_for('web_menus') %>/${menuid}/items/${item.menuitemid}" class="btn btn-sm btn-secondary">
                <%== icon "pencil-fill", {} %>
              </a>
              <button class="btn btn-sm btn-danger btn-delete" data-itemid="${item.menuitemid}">
                <%== icon "trash-fill", {} %>
              </button>
            </span>
          </div>
          ${children}
        </li>
      `;
    }).join("");
  }

  let draggedItem = null;
  let dropZone = null; // 'before', 'after', 'child'

  function attachItemHandlers() {
    // Delete handlers
    document.querySelectorAll(".btn-delete").forEach(btn => {
      btn.addEventListener("click", async () => {
        if (!confirm("<%= __('Are you sure you want to delete this item?') %>")) return;
        const itemid = btn.getAttribute("data-itemid");
        const result = await window.authenticatedFetch(
          `<%= url_for('web_menus') %>/${menuid}/items/${itemid}`,
          { method: "DELETE" }
        );
        if (result && result.success) {
          window.showToast("<%= __('Item deleted') %>");
          loadMenu();
        }
      });
    });

    // Drag and drop handlers
    document.querySelectorAll("#menuItemsTree li[draggable]").forEach(li => {
      li.addEventListener("dragstart", (e) => {
        e.stopPropagation();
        draggedItem = li;
        li.classList.add("dragging");
        e.dataTransfer.effectAllowed = "move";
      });

      li.addEventListener("dragend", (e) => {
        e.stopPropagation();
        li.classList.remove("dragging");
        clearDropIndicators();
        draggedItem = null;
      });

      li.addEventListener("dragover", (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (!draggedItem || draggedItem === li || draggedItem.contains(li)) return;

        const rect = li.querySelector(".item-row").getBoundingClientRect();
        const y = e.clientY - rect.top;
        const height = rect.height;

        clearDropIndicators();

        if (y < height * 0.25) {
          dropZone = "before";
          li.classList.add("drop-before");
        } else if (y > height * 0.75) {
          dropZone = "after";
          li.classList.add("drop-after");
        } else {
          dropZone = "child";
          li.classList.add("drop-child");
        }
      });

      li.addEventListener("dragleave", (e) => {
        e.stopPropagation();
        li.classList.remove("drop-before", "drop-after", "drop-child");
      });

      li.addEventListener("drop", async (e) => {
        e.preventDefault();
        e.stopPropagation();
        clearDropIndicators();

        if (!draggedItem || draggedItem === li || draggedItem.contains(li)) return;

        const draggedId = parseInt(draggedItem.getAttribute("data-itemid"));
        const targetId = parseInt(li.getAttribute("data-itemid"));
        let newParentId = null;
        let targetUl;

        if (dropZone === "child") {
          // Make dragged item a child of target
          newParentId = targetId;
          let childUl = li.querySelector(":scope > ul");
          if (!childUl) {
            childUl = document.createElement("ul");
            childUl.setAttribute("data-parentid", targetId);
            li.appendChild(childUl);
          }
          childUl.appendChild(draggedItem);
          targetUl = childUl;
        } else {
          // Move before or after target at same level
          const parentUl = li.parentElement;
          newParentId = parentUl.getAttribute("data-parentid") || null;
          if (dropZone === "before") {
            parentUl.insertBefore(draggedItem, li);
          } else {
            parentUl.insertBefore(draggedItem, li.nextSibling);
          }
          targetUl = parentUl;
        }

        // Collect new order for the target level
        const order = Array.from(targetUl.children)
          .filter(child => child.hasAttribute && child.hasAttribute("data-itemid"))
          .map((child, index) => ({
            menuitemid: parseInt(child.getAttribute("data-itemid")),
            position: index + 1,
            parentid: newParentId
          }));

        // Save to server
        const result = await window.authenticatedFetch(
          `<%= url_for('web_menus') %>/${menuid}/reorder`,
          { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ order }) }
        );

        if (result && result.success) {
          window.showToast("<%= __('Order saved') %>");
          loadMenu(); // Reload to update children counts
        } else {
          loadMenu();
        }
      });
    });
  }

  function clearDropIndicators() {
    document.querySelectorAll(".drop-before, .drop-after, .drop-child").forEach(el => {
      el.classList.remove("drop-before", "drop-after", "drop-child");
    });
  }

  // Add item button
  document.querySelector("#addItem")?.addEventListener("click", () => {
    window.location.href = `<%= url_for('web_menus') %>/${menuid}/items/new`;
  });

  // Menu settings form
  document.querySelector("#menuForm")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const name = document.querySelector("#menuName").value;
    const result = await window.authenticatedFetch(window.location.href, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name })
    });
    if (result && result.success) {
      window.showToast("<%= __('Menu saved') %>");
    }
  });

  loadMenu();
})();
